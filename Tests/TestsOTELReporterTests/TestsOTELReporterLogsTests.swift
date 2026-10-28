import CI
import Foundation
import Testing

@testable import TestsOTELReporter

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

@Suite(.serialized)
struct TestsOTELReporterLogsTests {
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

  /// Builds a reporter over a CI reporting no metadata.
  ///
  /// - Parameters:
  ///   - lokiEndpoint: Base URL of a separate Loki endpoint, if any.
  ///   - lokiHeaders: Headers for the logs request, if they differ from the metrics headers.
  ///   - urlSession: URL session used for the export requests.
  /// - Returns: The configured reporter.
  /// - Throws: An error if the endpoint URL cannot be built.
  private func makeSUT(
    lokiEndpoint: String? = .none,
    lokiHeaders: [String: String]? = .none,
    urlSession: URLSession = .shared,
  ) throws -> TestsOTELReporter {
    TestsOTELReporter(
      configuration: TestsOTELReporter.Configuration(
        endpoint: try #require(URL(string: "https://collector.example")),
        headers: ["authorization": "metrics"],
        lokiEndpoint: lokiEndpoint.flatMap { URL(string: $0) },
        lokiHeaders: lokiHeaders,
        timestamp: Date(timeIntervalSince1970: 1_700_000_000),
      ),
      ci: MockCI(cicd: CI.CICD(run: CI.CICD.Run(number: "7"))),
      urlSession: urlSession,
    )
  }

  // MARK: - Payload

  @Test("logPayloads emitsOneRecordPerTestCase")
  func test_logPayloads_emitsOneRecordPerTestCase() throws {
    // GIVEN — a reporter over a run with three cases
    let sut = try makeSUT()

    // WHEN
    let payloads = try sut.logPayloads(for: Self.testRun)

    // THEN — a single request carrying a record for every case
    #expect(payloads.count == 1)
    let records = try OTLPLogsPayload(data: try #require(payloads.first)).logRecords
    #expect(
      records.compactMap { OTLPPayload.attributes(of: $0)["test.case.name"] } == ["greets", "records", "replays"]
    )
  }

  @Test("logPayloads attachesCaseAttributes")
  func test_logPayloads_attachesCaseAttributes() throws {
    // GIVEN
    let sut = try makeSUT()

    // WHEN — the record of the failing case is read
    let payload = try OTLPLogsPayload(data: try #require(try sut.logPayloads(for: Self.testRun).first))
    let record = try #require(
      payload.logRecords.first { OTLPPayload.attributes(of: $0)["test.case.name"] == "records" }
    )

    // THEN — it carries the suite, the status and the duration in milliseconds
    let attributes = OTLPPayload.attributes(of: record)
    #expect(attributes["test.suite.name"] == "GreeterTests")
    #expect(attributes["test.case.result.status"] == "fail")
    #expect(OTLPLogsPayload.doubleAttribute("test.case.duration", of: record) == 300)
  }

  @Test("logPayloads mapsStatusToSeverity")
  func test_logPayloads_mapsStatusToSeverity() throws {
    // GIVEN
    let sut = try makeSUT()

    // WHEN
    let payload = try OTLPLogsPayload(data: try #require(try sut.logPayloads(for: Self.testRun).first))
    let severities = payload.logRecords.compactMap { $0["severityText"] as? String }

    // THEN — pass is INFO, fail is ERROR, skip is WARN
    #expect(severities == ["INFO", "ERROR", "WARN"])
  }

  @Test("logPayloads putsFailureMessageInTheBodyOfFailedCases")
  func test_logPayloads_putsFailureMessageInTheBodyOfFailedCases() throws {
    // GIVEN
    let sut = try makeSUT()

    // WHEN
    let payload = try OTLPLogsPayload(data: try #require(try sut.logPayloads(for: Self.testRun).first))
    let bodies = payload.logRecords.compactMap(OTLPLogsPayload.body(of:))

    // THEN — a failed case explains itself, the others are just named
    #expect(bodies == ["greets", "records: expected 1, got 2", "replays"])
  }

  @Test("logPayloads sharesTheMetricsResource")
  func test_logPayloads_sharesTheMetricsResource() throws {
    // GIVEN
    let sut = try makeSUT()

    // WHEN
    let logs = try OTLPLogsPayload(data: try #require(try sut.logPayloads(for: Self.testRun).first))
    let metrics = try OTLPPayload(data: try sut.payload(for: Self.testRun))

    // THEN — Loki and Mimir can be joined on identical resource attributes
    #expect(logs.resourceAttributes == metrics.resourceAttributes)
    #expect(logs.resourceAttributes["service.instance.id"] == "macpaw-test-7")
  }

  @Test("logPayloads emitsNothingForARunWithoutTestCases")
  func test_logPayloads_emitsNothingForARunWithoutTestCases() throws {
    // GIVEN — a run with no suites
    let sut = try makeSUT()

    // WHEN
    let payloads = try sut.logPayloads(for: TestRun(suites: [], duration: 0))

    // THEN
    #expect(payloads.isEmpty)
  }

  @Test("logPayloads splitsLargeRunsIntoBatches")
  func test_logPayloads_splitsLargeRunsIntoBatches() throws {
    // GIVEN — 1,001 test cases against a limit of 500 records per request
    let testCases = (0..<1001).map { TestRun.Suite.TestCase(name: "case\($0)", status: .pass, duration: 0) }
    let testRun = TestRun(suites: [TestRun.Suite(name: "Big", testCases: testCases)], duration: 1)
    let sut = try makeSUT()

    // WHEN
    let payloads = try sut.logPayloads(for: testRun)

    // THEN — three requests that together carry every case exactly once
    let sizes = try payloads.map { try OTLPLogsPayload(data: $0).logRecords.count }
    #expect(sizes == [500, 500, 1])
  }

  // MARK: - Sending

  @Test("report sendsMetricsBeforeLogs")
  func test_report_sendsMetricsBeforeLogs() async throws {
    // GIVEN — a reporter over a stubbed network
    let stub = StubURLProtocol.install(statusCodes: [])
    defer { stub.uninstall() }
    let sut = try makeSUT(urlSession: stub.session)

    // WHEN
    try await sut.report(testRun: Self.testRun, lineCoverage: .none)

    // THEN — metrics go to v1/metrics, then the logs to the same collector's v1/logs
    #expect(
      stub.requests.map(\.url?.absoluteString) == [
        "https://collector.example/v1/metrics", "https://collector.example/v1/logs",
      ]
    )
  }

  @Test("report sendsLogsToLokiWithItsOwnHeaders")
  func test_report_sendsLogsToLokiWithItsOwnHeaders() async throws {
    // GIVEN — a Loki endpoint with its own credentials
    let stub = StubURLProtocol.install(statusCodes: [])
    defer { stub.uninstall() }
    let sut = try makeSUT(
      lokiEndpoint: "https://loki.example:3100/otlp",
      lokiHeaders: ["authorization": "loki"],
      urlSession: stub.session,
    )

    // WHEN
    try await sut.report(testRun: Self.testRun, lineCoverage: .none)

    // THEN — the logs take Loki's URL and credentials, the metrics keep theirs
    #expect(stub.requests.last?.url?.absoluteString == "https://loki.example:3100/otlp/v1/logs")
    #expect(stub.requests.last?.value(forHTTPHeaderField: "authorization") == "loki")
    #expect(stub.requests.first?.value(forHTTPHeaderField: "authorization") == "metrics")
  }

  @Test("report throwsWhenLogsAreRejectedAfterMetricsWereSent")
  func test_report_throwsWhenLogsAreRejectedAfterMetricsWereSent() async throws {
    // GIVEN — a collector that accepts the metrics but has no logs pipeline
    let stub = StubURLProtocol.install(statusCodes: [200, 404])
    defer { stub.uninstall() }
    let sut = try makeSUT(urlSession: stub.session)

    // WHEN / THEN — the command is told, and the metrics were already delivered
    await #expect(throws: TestsOTELReporter.Error.self) {
      try await sut.report(testRun: Self.testRun, lineCoverage: .none)
    }
    #expect(stub.requests.count == 2)
  }

  @Test("report skipsLogsWithoutATestRun")
  func test_report_skipsLogsWithoutATestRun() async throws {
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
