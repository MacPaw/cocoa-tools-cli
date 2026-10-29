import CI
import Foundation

/// Builds the OTLP logs payloads for a completed test run: one log record per test case.
///
/// Test case names live in logs rather than metric labels, since a series per test case grows
/// without bound while a log line costs nothing to index.
struct OTLPLogsBuilder {
  /// Most log records sent in one request.
  ///
  /// A large run would otherwise produce a body that a reverse proxy in front of the collector
  /// rejects — nginx defaults to 1 MB.
  static let maxRecordsPerRequest: Int = 500

  /// Most characters of a failure message kept in a log record.
  static let maxFailureMessageLength: Int = 2_000

  /// Rough size budget of one request, in bytes, kept under a proxy's 1 MB body limit.
  static let maxBytesPerRequest: Int = 512 * 1024

  /// Bytes a record takes beyond its text: attribute keys, timestamps, and JSON punctuation.
  private static let recordOverheadBytes: Int = 512

  /// Value of the `service.name` resource attribute.
  let serviceName: String
  /// Timestamp recorded on the first log record; each later one is a nanosecond after the last,
  /// so records with the same body and resource are not collapsed as duplicates.
  let timestamp: Date

  /// Builds the export requests for a test run.
  ///
  /// - Parameters:
  ///   - testRun: The completed test run.
  ///   - repository: Repository metadata for the run.
  ///   - cicd: Pipeline metadata for the run.
  ///   - ciProviderName: Name of the CI the run executed on.
  /// - Returns: The OTLP export requests, each within ``maxRecordsPerRequest``, or none when the
  ///   run has no test cases.
  func build(
    testRun: TestRun,
    repository: CI.Repository,
    cicd: CI.CICD,
    ciProviderName: String?,
  ) -> [OTLPLogsRequest] {
    let resource = OTLPMetricsRequest.Resource(
      attributes: OTLPResourceAttributes.make(
        serviceName: serviceName,
        repository: repository,
        cicd: cicd,
        ciProviderName: ciProviderName,
      )
    )
    let records: [OTLPLogsRequest.LogRecord] = testRun.suites
      .flatMap { suite in suite.testCases.map { (suite: suite.name, testCase: $0) } }
      .enumerated()
      .map { index, entry in logRecord(for: entry.testCase, suiteName: entry.suite, offset: index) }

    var batches: [[OTLPLogsRequest.LogRecord]] = []
    var batch: [OTLPLogsRequest.LogRecord] = []
    var batchBytes = 0
    for record in records {
      let bytes = Self.estimatedBytes(of: record)
      if !batch.isEmpty, batch.count >= Self.maxRecordsPerRequest || batchBytes + bytes > Self.maxBytesPerRequest {
        batches.append(batch)
        batch = []
        batchBytes = 0
      }
      batch.append(record)
      batchBytes += bytes
    }
    if !batch.isEmpty { batches.append(batch) }

    return batches.map { logRecords in
      OTLPLogsRequest(
        resourceLogs: [
          OTLPLogsRequest.ResourceLogs(
            resource: resource,
            scopeLogs: [
              OTLPLogsRequest.ScopeLogs(
                scope: OTLPMetricsRequest.Scope(name: SemanticConventions.scopeName),
                logRecords: logRecords,
              )
            ],
          )
        ]
      )
    }
  }

  /// Estimates the serialized size of a log record.
  ///
  /// - Parameter record: The log record.
  /// - Returns: The size of its text plus a fixed overhead, in bytes.
  private static func estimatedBytes(of record: OTLPLogsRequest.LogRecord) -> Int {
    let text =
      (record.body.stringValue?.utf8.count ?? 0)
      + record.attributes.reduce(0) { $0 + ($1.value.stringValue?.utf8.count ?? 0) }
    return text + recordOverheadBytes
  }

  /// Builds the log record of a single test case.
  ///
  /// - Parameters:
  ///   - testCase: The test case.
  ///   - suiteName: Name of the suite it belongs to.
  ///   - offset: Position of the record in the run, added to the timestamp in nanoseconds.
  /// - Returns: The log record.
  private func logRecord(
    for testCase: TestRun.Suite.TestCase,
    suiteName: String,
    offset: Int,
  ) -> OTLPLogsRequest.LogRecord {
    let severity =
      switch testCase.status {
      case .pass: OTLPLogsRequest.Severity.info
      case .fail: OTLPLogsRequest.Severity.error
      case .skip: OTLPLogsRequest.Severity.warn
      }

    return OTLPLogsRequest.LogRecord(
      timeUnixNano: OTLPMetricsBuilder.unixNano(timestamp, offsetNanoseconds: offset),
      severityNumber: severity.number,
      severityText: severity.text,
      body: OTLPMetricsRequest.AnyValue(stringValue: Self.body(for: testCase), doubleValue: .none),
      attributes: [
        OTLPMetricsRequest.KeyValue(key: SemanticConventions.Attribute.testCaseName, stringValue: testCase.name),
        OTLPMetricsRequest.KeyValue(key: SemanticConventions.Attribute.testSuiteName, stringValue: suiteName),
        OTLPMetricsRequest.KeyValue(
          key: SemanticConventions.Attribute.testCaseResultStatus,
          stringValue: testCase.status.rawValue,
        ),
        OTLPMetricsRequest.KeyValue(
          key: SemanticConventions.Attribute.testCaseDuration,
          doubleValue: testCase.duration * 1000,
        ),
      ],
    )
  }

  /// Builds the message of a test case's log record.
  ///
  /// - Parameter testCase: The test case.
  /// - Returns: The test case name, followed by the failure message of a failed test case.
  private static func body(for testCase: TestRun.Suite.TestCase) -> String {
    guard testCase.status == .fail, let message = testCase.failureMessage, !message.isEmpty else {
      return testCase.name
    }
    return "\(testCase.name): \(message.prefix(maxFailureMessageLength))"
  }
}
