import CI
import Foundation

/// Builds the OTLP traces payloads for a completed test run: one trace with a span for the run,
/// one per suite and one per test case.
///
/// Test case names live in spans rather than metric labels, since a series per test case grows
/// without bound while a span costs nothing to index.
///
/// Reports carry durations but no start times, so the layout is synthesized: the run ends at
/// ``timestamp``, suites follow one another from the run's start, and the cases of a suite follow
/// one another within it. Durations are accurate; the ordering and start times are approximate.
struct OTLPTracesBuilder {
  /// Most spans sent in one request.
  ///
  /// A large run would otherwise produce a body that a reverse proxy in front of the collector
  /// rejects — nginx defaults to 1 MB. Spans of one trace may arrive in separate requests.
  static let maxSpansPerRequest: Int = 500

  /// Most characters of a failure message kept on a span.
  static let maxFailureMessageLength: Int = 2_000

  /// Rough size budget of one request, in bytes, kept under a proxy's 1 MB body limit.
  static let maxBytesPerRequest: Int = 512 * 1024

  /// Bytes a span takes beyond its text: IDs, attribute keys, timestamps, and JSON punctuation.
  private static let spanOverheadBytes: Int = 512

  /// Value of the `service.name` resource attribute.
  let serviceName: String
  /// End of the run; every span is laid out backwards from it.
  let timestamp: Date

  /// Builds the export requests for a test run.
  ///
  /// - Parameters:
  ///   - testRun: The completed test run.
  ///   - repository: Repository metadata for the run.
  ///   - cicd: Pipeline metadata for the run.
  ///   - ciProviderName: Name of the CI the run executed on.
  /// - Returns: The OTLP export requests, each within ``maxSpansPerRequest``, or none when the
  ///   run has no test cases.
  func build(
    testRun: TestRun,
    repository: CI.Repository,
    cicd: CI.CICD,
    ciProviderName: String?,
  ) -> [OTLPTracesRequest] {
    guard !testRun.testCases.isEmpty else { return [] }

    let resource = OTLPMetricsRequest.Resource(
      attributes: OTLPResourceAttributes.make(
        serviceName: serviceName,
        repository: repository,
        cicd: cicd,
        ciProviderName: ciProviderName,
      )
    )
    let spans = spans(for: testRun, traceID: OTLPTraceIdentity.traceID(repository: repository, cicd: cicd))

    var batches: [[OTLPTracesRequest.Span]] = []
    var batch: [OTLPTracesRequest.Span] = []
    var batchBytes = 0
    for span in spans {
      let bytes = Self.estimatedBytes(of: span)
      if !batch.isEmpty, batch.count >= Self.maxSpansPerRequest || batchBytes + bytes > Self.maxBytesPerRequest {
        batches.append(batch)
        batch = []
        batchBytes = 0
      }
      batch.append(span)
      batchBytes += bytes
    }
    if !batch.isEmpty { batches.append(batch) }

    return batches.map { spans in
      OTLPTracesRequest(
        resourceSpans: [
          OTLPTracesRequest.ResourceSpans(
            resource: resource,
            scopeSpans: [
              OTLPTracesRequest.ScopeSpans(
                scope: OTLPMetricsRequest.Scope(name: SemanticConventions.scopeName),
                spans: spans,
              )
            ],
          )
        ]
      )
    }
  }

  /// Lays out the spans of a run: the run, then each suite followed by its cases.
  ///
  /// - Parameters:
  ///   - testRun: The completed test run.
  ///   - traceID: The trace every span belongs to.
  /// - Returns: The spans, parents before children.
  private func spans(for testRun: TestRun, traceID: String) -> [OTLPTracesRequest.Span] {
    let suiteDurations = testRun.suites.map { $0.testCases.reduce(0) { $0 + $1.duration } }
    // Cases of a parallel run can sum to more than the wall-clock time; the root must still
    // contain every child.
    let runDuration = max(testRun.duration, suiteDurations.reduce(0, +))
    let runEnd = Self.nanoseconds(timestamp.timeIntervalSince1970)
    let runStart = runEnd - min(runEnd, Self.nanoseconds(runDuration))
    let rootID = OTLPTraceIdentity.spanID(traceID: traceID, path: "run")

    var spans: [OTLPTracesRequest.Span] = [
      span(
        traceID: traceID,
        spanID: rootID,
        parentID: .none,
        name: "test run",
        start: runStart,
        duration: Self.nanoseconds(runDuration),
        attributes: [
          OTLPMetricsRequest.KeyValue(
            key: SemanticConventions.Attribute.testSuiteRunStatus,
            stringValue: Self.runStatus(of: testRun.testCases),
          )
        ],
        isFailure: testRun.testCases.contains { $0.status == .fail },
        failureMessage: .none,
      )
    ]

    var suiteStart = runStart
    for (suiteIndex, suite) in testRun.suites.enumerated() {
      let suiteID = OTLPTraceIdentity.spanID(traceID: traceID, path: "suite-\(suiteIndex)")
      spans.append(
        span(
          traceID: traceID,
          spanID: suiteID,
          parentID: rootID,
          name: suite.name,
          start: suiteStart,
          duration: Self.nanoseconds(suiteDurations[suiteIndex]),
          attributes: [
            OTLPMetricsRequest.KeyValue(key: SemanticConventions.Attribute.testSuiteName, stringValue: suite.name),
            OTLPMetricsRequest.KeyValue(
              key: SemanticConventions.Attribute.testSuiteRunStatus,
              stringValue: Self.runStatus(of: suite.testCases),
            ),
          ],
          isFailure: suite.testCases.contains { $0.status == .fail },
          failureMessage: .none,
        )
      )

      var caseStart = suiteStart
      for (caseIndex, testCase) in suite.testCases.enumerated() {
        let failureMessage = Self.failureMessage(of: testCase)
        var attributes = [
          OTLPMetricsRequest.KeyValue(key: SemanticConventions.Attribute.testCaseName, stringValue: testCase.name),
          OTLPMetricsRequest.KeyValue(key: SemanticConventions.Attribute.testSuiteName, stringValue: suite.name),
          OTLPMetricsRequest.KeyValue(
            key: SemanticConventions.Attribute.testCaseResultStatus,
            stringValue: testCase.status.rawValue,
          ),
          OTLPMetricsRequest.KeyValue(
            key: SemanticConventions.Attribute.testCaseDuration,
            doubleValue: testCase.duration * 1000,
          ),
        ]
        if let failureMessage {
          attributes.append(
            OTLPMetricsRequest.KeyValue(
              key: SemanticConventions.Attribute.testCaseFailureMessage,
              stringValue: failureMessage,
            )
          )
        }

        spans.append(
          span(
            traceID: traceID,
            spanID: OTLPTraceIdentity.spanID(traceID: traceID, path: "suite-\(suiteIndex)/case-\(caseIndex)"),
            parentID: suiteID,
            name: testCase.name,
            start: caseStart,
            duration: Self.nanoseconds(testCase.duration),
            attributes: attributes,
            isFailure: testCase.status == .fail,
            failureMessage: failureMessage,
          )
        )
        caseStart += Self.nanoseconds(testCase.duration)
      }
      suiteStart += Self.nanoseconds(suiteDurations[suiteIndex])
    }

    return spans
  }

  /// Builds a single span.
  ///
  /// - Parameters:
  ///   - traceID: The trace the span belongs to.
  ///   - spanID: The span's own ID.
  ///   - parentID: ID of the parent span, or `nil` for the root.
  ///   - name: Name of the span.
  ///   - start: Start of the span, in nanoseconds since the Unix epoch.
  ///   - duration: Duration of the span, in nanoseconds.
  ///   - attributes: Attributes qualifying the span.
  ///   - isFailure: Whether the span gets an error status.
  ///   - failureMessage: Detail attached to the error status.
  /// - Returns: The span.
  private func span(
    traceID: String,
    spanID: String,
    parentID: String?,
    name: String,
    start: UInt64,
    duration: UInt64,
    attributes: [OTLPMetricsRequest.KeyValue],
    isFailure: Bool,
    failureMessage: String?,
  ) -> OTLPTracesRequest.Span {
    OTLPTracesRequest.Span(
      traceId: traceID,
      spanId: spanID,
      parentSpanId: parentID,
      name: name,
      kind: OTLPTracesRequest.internalSpanKind,
      startTimeUnixNano: String(start),
      endTimeUnixNano: String(start + duration),
      attributes: attributes,
      status: OTLPTracesRequest.Status(
        code: isFailure ? OTLPTracesRequest.StatusCode.error : OTLPTracesRequest.StatusCode.unset,
        message: isFailure ? failureMessage : .none,
      ),
    )
  }

  /// Converts seconds to whole nanoseconds.
  ///
  /// Span offsets are summed as integers: epoch seconds as a `Double` cannot resolve
  /// sub-microsecond durations, so adding them there would shift every following span.
  ///
  /// - Parameter seconds: A duration or epoch time, in seconds.
  /// - Returns: The nanoseconds, clamped to zero for negative input.
  private static func nanoseconds(_ seconds: TimeInterval) -> UInt64 {
    UInt64(max(0, (seconds * 1_000_000_000).rounded()))
  }

  /// Derives the `test.suite.run.status` of a group of test cases.
  ///
  /// - Parameter testCases: The test cases of a suite or of the whole run.
  /// - Returns: `failure` when any failed, `skipped` when all were skipped, otherwise `success`.
  private static func runStatus(of testCases: [TestRun.Suite.TestCase]) -> String {
    if testCases.contains(where: { $0.status == .fail }) { return SemanticConventions.SuiteRunStatus.failure }
    if !testCases.isEmpty, testCases.allSatisfy({ $0.status == .skip }) {
      return SemanticConventions.SuiteRunStatus.skipped
    }
    return SemanticConventions.SuiteRunStatus.success
  }

  /// Extracts the capped failure message of a failed test case.
  ///
  /// - Parameter testCase: The test case.
  /// - Returns: The message, or `nil` when the test case did not fail or has no message.
  private static func failureMessage(of testCase: TestRun.Suite.TestCase) -> String? {
    guard testCase.status == .fail, let message = testCase.failureMessage, !message.isEmpty else { return .none }
    return String(message.prefix(maxFailureMessageLength))
  }

  /// Estimates the serialized size of a span.
  ///
  /// - Parameter span: The span.
  /// - Returns: The size of its text plus a fixed overhead, in bytes.
  private static func estimatedBytes(of span: OTLPTracesRequest.Span) -> Int {
    let text =
      span.name.utf8.count
      + (span.status.message?.utf8.count ?? 0)
      + span.attributes.reduce(0) { $0 + ($1.value.stringValue?.utf8.count ?? 0) }
    return text + spanOverheadBytes
  }
}
