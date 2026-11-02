import CI
import Foundation
import Testing

@testable import TestsOTELReporter

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

@Suite(.serialized)
struct TestsOTELReporterTracesTests {
  /// A run with a passing, a failing and a skipped case.
  private static let testRun: TestRun = TestRun(
    suites: [
      TestRun.Suite(
        name: "GreeterTests",
        testCases: [
          TestRun.Suite.TestCase(name: "greets", status: .pass, duration: 0.002),
          TestRun.Suite.TestCase(name: "records", status: .fail, duration: 0.3, failureMessage: "expected 1, got 2"),
          TestRun.Suite.TestCase(name: "replays", status: .skip, duration: 0),
        ],
      )
    ],
    duration: 1,
  )

  /// The timestamp every run ends at.
  private static let timestamp: Date = Date(timeIntervalSince1970: 1_700_000_000)

  /// Builds a reporter over a CI reporting a run number only.
  ///
  /// - Parameters:
  ///   - tempoEndpoint: Base URL of a separate Tempo endpoint, if any.
  ///   - tempoHeaders: Headers for the traces request, if they differ from the metrics headers.
  ///   - runID: Run id the CI reports, if any.
  ///   - urlSession: URL session used for the export requests.
  /// - Returns: The configured reporter.
  /// - Throws: An error if the endpoint URL cannot be built.
  private func makeSUT(
    tempoEndpoint: String? = .none,
    tempoHeaders: [String: String]? = .none,
    runID: String? = .none,
    urlSession: URLSession = .shared,
  ) throws -> TestsOTELReporter {
    TestsOTELReporter(
      configuration: TestsOTELReporter.Configuration(
        endpoint: try #require(URL(string: "https://collector.example")),
        headers: ["authorization": "metrics"],
        tempoEndpoint: tempoEndpoint.flatMap { URL(string: $0) },
        tempoHeaders: tempoHeaders,
        timestamp: Self.timestamp,
      ),
      ci: MockCI(cicd: CI.CICD(run: CI.CICD.Run(id: runID, number: "7"))),
      urlSession: urlSession,
    )
  }

  // MARK: - Payload

  @Test("tracePayloads emitsARunSpanASuiteSpanAndOneSpanPerTestCase")
  func test_tracePayloads_emitsARunSpanASuiteSpanAndOneSpanPerTestCase() throws {
    // GIVEN — a reporter over a run with one suite of three cases
    let sut = try makeSUT()

    // WHEN
    let payloads = try sut.tracePayloads(for: Self.testRun)

    // THEN — a single request: run, suite, then the cases in order
    #expect(payloads.count == 1)
    let spans = try OTLPTracesPayload(data: try #require(payloads.first)).spans
    #expect(spans.compactMap { $0["name"] as? String } == ["test run", "GreeterTests", "greets", "records", "replays"])
  }

  @Test("tracePayloads linksSpansIntoOneTrace")
  func test_tracePayloads_linksSpansIntoOneTrace() throws {
    // GIVEN
    let sut = try makeSUT(runID: "42")

    // WHEN
    let spans = try OTLPTracesPayload(data: try #require(try sut.tracePayloads(for: Self.testRun).first)).spans

    // THEN — one trace ID, the root has no parent, suite hangs off the root, cases off the suite
    #expect(Set(spans.compactMap { $0["traceId"] as? String }).count == 1)
    #expect(spans[0]["parentSpanId"] == nil)
    #expect(spans[1]["parentSpanId"] as? String == spans[0]["spanId"] as? String)
    #expect(spans[2...].allSatisfy { $0["parentSpanId"] as? String == spans[1]["spanId"] as? String })
    #expect(Set(spans.compactMap { $0["spanId"] as? String }).count == spans.count)
  }

  @Test("tracePayloads attachesCaseAttributes")
  func test_tracePayloads_attachesCaseAttributes() throws {
    // GIVEN
    let sut = try makeSUT()

    // WHEN — the span of the failing case is read
    let payload = try OTLPTracesPayload(data: try #require(try sut.tracePayloads(for: Self.testRun).first))
    let span = try #require(payload.spans.first { $0["name"] as? String == "records" })

    // THEN — it carries the suite, the status, the duration in milliseconds and the message
    let attributes = OTLPPayload.attributes(of: span)
    #expect(attributes["test.case.name"] == "records")
    #expect(attributes["test.suite.name"] == "GreeterTests")
    #expect(attributes["test.case.result.status"] == "fail")
    #expect(attributes["test.case.failure.message"] == "expected 1, got 2")
    #expect(OTLPTracesPayload.doubleAttribute("test.case.duration", of: span) == 300)
  }

  @Test("tracePayloads mapsFailuresToErrorStatus")
  func test_tracePayloads_mapsFailuresToErrorStatus() throws {
    // GIVEN
    let sut = try makeSUT()

    // WHEN
    let spans = try OTLPTracesPayload(data: try #require(try sut.tracePayloads(for: Self.testRun).first)).spans

    // THEN — the failed case, its suite and the run are errors; passed and skipped cases are unset
    #expect(spans.map(OTLPTracesPayload.statusCode(of:)) == [2, 2, 0, 2, 0])
    #expect(OTLPTracesPayload.statusMessage(of: spans[3]) == "expected 1, got 2")
    #expect(OTLPTracesPayload.statusMessage(of: spans[2]) == nil)
  }

  @Test("tracePayloads capsFailureMessages")
  func test_tracePayloads_capsFailureMessages() throws {
    // GIVEN — a failure message beyond the cap
    let message = String(repeating: "x", count: 5_000)
    let testRun = TestRun(
      suites: [
        TestRun.Suite(
          name: "S",
          testCases: [TestRun.Suite.TestCase(name: "c", status: .fail, duration: 0, failureMessage: message)],
        )
      ],
      duration: 0,
    )
    let sut = try makeSUT()

    // WHEN
    let spans = try OTLPTracesPayload(data: try #require(try sut.tracePayloads(for: testRun).first)).spans

    // THEN
    let span = try #require(spans.last)
    #expect(OTLPPayload.attributes(of: span)["test.case.failure.message"]?.count == 2_000)
    #expect(OTLPTracesPayload.statusMessage(of: span)?.count == 2_000)
  }

  @Test("tracePayloads laysSpansOutBackFromTheTimestamp")
  func test_tracePayloads_laysSpansOutBackFromTheTimestamp() throws {
    // GIVEN — a one second run ending at the configured timestamp
    let sut = try makeSUT()

    // WHEN
    let spans = try OTLPTracesPayload(data: try #require(try sut.tracePayloads(for: Self.testRun).first)).spans
    let end = 1_700_000_000 * 1_000_000_000
    let second = 1_000_000_000

    // THEN — the run covers the second; cases follow one another by their durations
    #expect(OTLPTracesPayload.interval(of: spans[0]) == (end - second, end))
    let greets = OTLPTracesPayload.interval(of: spans[2])
    let records = OTLPTracesPayload.interval(of: spans[3])
    #expect(greets.start == end - second)
    #expect(greets.end - greets.start == 2_000_000)
    #expect(records.start == greets.end)
    #expect(records.end - records.start == 300_000_000)
  }

  @Test("tracePayloads sharesTheMetricsResource")
  func test_tracePayloads_sharesTheMetricsResource() throws {
    // GIVEN
    let sut = try makeSUT()

    // WHEN
    let traces = try OTLPTracesPayload(data: try #require(try sut.tracePayloads(for: Self.testRun).first))
    let metrics = try OTLPPayload(data: try sut.payload(for: Self.testRun))

    // THEN — Tempo and Mimir can be joined on identical resource attributes
    #expect(traces.resourceAttributes == metrics.resourceAttributes)
    #expect(traces.resourceAttributes["cicd.pipeline.run.number"] == "7")
  }

  @Test("tracePayloads reusesIDsWhenTheSameJobIsExportedAgain")
  func test_tracePayloads_reusesIDsWhenTheSameJobIsExportedAgain() throws {
    // GIVEN — two reporters over the same CI run
    let first = try makeSUT(runID: "42")
    let second = try makeSUT(runID: "42")

    // WHEN
    let firstSpans = try OTLPTracesPayload(data: try #require(try first.tracePayloads(for: Self.testRun).first)).spans
    let secondSpans = try OTLPTracesPayload(data: try #require(try second.tracePayloads(for: Self.testRun).first))
      .spans

    // THEN — every trace and span ID matches, so a re-export overwrites rather than duplicates
    #expect(firstSpans.map { $0["traceId"] as? String } == secondSpans.map { $0["traceId"] as? String })
    #expect(firstSpans.map { $0["spanId"] as? String } == secondSpans.map { $0["spanId"] as? String })
  }

  @Test("tracePayloads usesADifferentTraceForADifferentRun")
  func test_tracePayloads_usesADifferentTraceForADifferentRun() throws {
    // GIVEN — two CI runs
    let first = try makeSUT(runID: "42")
    let second = try makeSUT(runID: "43")

    // WHEN
    let firstSpans = try OTLPTracesPayload(data: try #require(try first.tracePayloads(for: Self.testRun).first)).spans
    let secondSpans = try OTLPTracesPayload(data: try #require(try second.tracePayloads(for: Self.testRun).first))
      .spans

    // THEN
    #expect(firstSpans.first?["traceId"] as? String != secondSpans.first?["traceId"] as? String)
  }

  @Test("tracePayloads usesARandom128BitTraceIDWithoutARunID")
  func test_tracePayloads_usesARandom128BitTraceIDWithoutARunID() throws {
    // GIVEN — a CI reporting no run id, exported twice
    let sut = try makeSUT()

    // WHEN
    let firstSpans = try OTLPTracesPayload(data: try #require(try sut.tracePayloads(for: Self.testRun).first)).spans
    let secondSpans = try OTLPTracesPayload(data: try #require(try sut.tracePayloads(for: Self.testRun).first)).spans

    // THEN — well-formed hex IDs that differ between exports
    let firstTrace = try #require(firstSpans.first?["traceId"] as? String)
    #expect(firstTrace.count == 32)
    #expect(try #require(firstSpans.first?["spanId"] as? String).count == 16)
    #expect(firstTrace != secondSpans.first?["traceId"] as? String)
  }

  @Test("tracePayloads emitsNothingForARunWithoutTestCases")
  func test_tracePayloads_emitsNothingForARunWithoutTestCases() throws {
    // GIVEN — a run with no suites
    let sut = try makeSUT()

    // WHEN
    let payloads = try sut.tracePayloads(for: TestRun(suites: [], duration: 0))

    // THEN
    #expect(payloads.isEmpty)
  }

  @Test("tracePayloads splitsLargeRunsIntoBatches")
  func test_tracePayloads_splitsLargeRunsIntoBatches() throws {
    // GIVEN — 1,001 test cases, plus a run and a suite span, against a limit of 500 spans per request
    let testCases = (0..<1001).map { TestRun.Suite.TestCase(name: "case\($0)", status: .pass, duration: 0) }
    let testRun = TestRun(suites: [TestRun.Suite(name: "Big", testCases: testCases)], duration: 1)
    let sut = try makeSUT(runID: "42")

    // WHEN
    let payloads = try sut.tracePayloads(for: testRun)

    // THEN — three requests that together carry every span once, under one trace
    let spans = try payloads.map { try OTLPTracesPayload(data: $0).spans }
    #expect(spans.map(\.count) == [500, 500, 3])
    #expect(Set(spans.flatMap { $0.compactMap { $0["traceId"] as? String } }).count == 1)
  }

  // MARK: - Sending

  @Test("report sendsMetricsBeforeTraces")
  func test_report_sendsMetricsBeforeTraces() async throws {
    // GIVEN — a reporter over a stubbed network
    let stub = StubURLProtocol.install(statusCodes: [])
    defer { stub.uninstall() }
    let sut = try makeSUT(urlSession: stub.session)

    // WHEN
    try await sut.report(testRun: Self.testRun, lineCoverage: .none)

    // THEN — metrics go to v1/metrics, then the traces to the same collector's v1/traces
    #expect(
      stub.requests.map(\.url?.absoluteString) == [
        "https://collector.example/v1/metrics", "https://collector.example/v1/traces",
      ]
    )
  }

  @Test("report sendsTracesToTempoWithItsOwnHeaders")
  func test_report_sendsTracesToTempoWithItsOwnHeaders() async throws {
    // GIVEN — a Tempo endpoint with its own credentials
    let stub = StubURLProtocol.install(statusCodes: [])
    defer { stub.uninstall() }
    let sut = try makeSUT(
      tempoEndpoint: "https://tempo.example:4318/otlp",
      tempoHeaders: ["authorization": "tempo"],
      urlSession: stub.session,
    )

    // WHEN
    try await sut.report(testRun: Self.testRun, lineCoverage: .none)

    // THEN — the traces take Tempo's URL and credentials, the metrics keep theirs
    #expect(stub.requests.last?.url?.absoluteString == "https://tempo.example:4318/otlp/v1/traces")
    #expect(stub.requests.last?.value(forHTTPHeaderField: "authorization") == "tempo")
    #expect(stub.requests.first?.value(forHTTPHeaderField: "authorization") == "metrics")
  }

  @Test("report throwsWhenTracesAreRejectedAfterMetricsWereSent")
  func test_report_throwsWhenTracesAreRejectedAfterMetricsWereSent() async throws {
    // GIVEN — a collector that accepts the metrics but has no traces pipeline
    let stub = StubURLProtocol.install(statusCodes: [200, 404])
    defer { stub.uninstall() }
    let sut = try makeSUT(urlSession: stub.session)

    // WHEN / THEN — the command is told, and the metrics were already delivered
    await #expect(throws: TestsOTELReporter.Error.self) {
      try await sut.report(testRun: Self.testRun, lineCoverage: .none)
    }
    #expect(stub.requests.count == 2)
  }

  @Test("report skipsTracesWithoutATestRun")
  func test_report_skipsTracesWithoutATestRun() async throws {
    // GIVEN — a report of line coverage only
    let stub = StubURLProtocol.install(statusCodes: [])
    defer { stub.uninstall() }
    let sut = try makeSUT(urlSession: stub.session)

    // WHEN
    try await sut.report(testRun: .none, lineCoverage: .none)

    // THEN — only the metrics request is made
    #expect(stub.requests.map(\.url?.lastPathComponent) == ["metrics"])
  }
}

/// A URL protocol that records requests and answers them from a script, so the reporter's network
/// behavior is tested without a collector.
private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
  /// State shared with the protocol instances URLSession creates.
  private struct State {
    var requests: [URLRequest] = []
    var statusCodes: [Int] = []
  }

  private static let state = LockedState(State())

  /// A scripted URL session and the requests it saw.
  struct Handle {
    /// The URL session routing every request through the stub.
    let session: URLSession

    /// Requests received so far, in order.
    var requests: [URLRequest] { StubURLProtocol.state.withLock { $0.requests } }

    /// Stops recording.
    func uninstall() { StubURLProtocol.state.withLock { $0 = State() } }
  }

  /// Starts a fresh script.
  ///
  /// - Parameter statusCodes: Status codes answered to the first requests, in order; later
  ///   requests get 200.
  /// - Returns: A handle to the session and the recorded requests.
  static func install(statusCodes: [Int]) -> Handle {
    state.withLock { $0 = State(requests: [], statusCodes: statusCodes) }
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    return Handle(session: URLSession(configuration: configuration))
  }

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func stopLoading() {}

  override func startLoading() {
    let statusCode: Int = Self.state.withLock { state in
      state.requests.append(request)
      return state.statusCodes.isEmpty ? 200 : state.statusCodes.removeFirst()
    }
    let response = HTTPURLResponse(
      url: request.url ?? URL(fileURLWithPath: "/"),
      statusCode: statusCode,
      httpVersion: nil,
      headerFields: nil,
    )
    if let response { client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed) }
    client?.urlProtocol(self, didLoad: Data())
    client?.urlProtocolDidFinishLoading(self)
  }
}

/// A value guarded by a lock.
private final class LockedState<Value>: @unchecked Sendable {
  private let lock = NSLock()
  private var value: Value

  init(_ value: Value) { self.value = value }

  func withLock<Result>(_ body: (inout Value) -> Result) -> Result {
    lock.lock()
    defer { lock.unlock() }
    return body(&value)
  }
}
