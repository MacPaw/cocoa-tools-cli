import CI
import Foundation
import Testing

@testable import TestsOTELReporter

@Suite
struct TestsOTELReporterTests {
  /// A run with two suites: one all-passing and fast, one mixed and slow.
  private static let testRun: TestRun = TestRun(
    suites: [
      TestRun.Suite(
        name: "GreeterTests",
        testCases: [
          TestRun.Suite.TestCase(name: "greets", status: .pass, duration: 0.002),
          TestRun.Suite.TestCase(name: "greetsLoudly", status: .pass, duration: 0.008),
        ],
      ),
      TestRun.Suite(
        name: "RecordingTests",
        testCases: [
          TestRun.Suite.TestCase(name: "records", status: .fail, duration: 0.3),
          TestRun.Suite.TestCase(name: "replays", status: .skip, duration: 0),
        ],
      ),
    ],
    duration: 1.5,
  )

  /// Builds a reporter over a CI reporting no metadata.
  ///
  /// - Parameters:
  ///   - isPerSuiteEnabled: Whether metrics carry a suite breakdown.
  ///   - ci: The CI to derive resource attributes from.
  /// - Returns: The configured reporter.
  /// - Throws: An error if the endpoint URL cannot be built.
  private func makeSUT(isPerSuiteEnabled: Bool = true, ci: any CIInterface = MockCI()) throws -> TestsOTELReporter {
    TestsOTELReporter(
      configuration: TestsOTELReporter.Configuration(
        endpoint: try #require(URL(string: "https://collector.example")),
        isPerSuiteEnabled: isPerSuiteEnabled,
        timestamp: Date(timeIntervalSince1970: 1_700_000_000),
      ),
      ci: ci,
    )
  }

  @Test("payload emitsThreeAgreedMetrics")
  func test_payload_emitsThreeAgreedMetrics() throws {
    // GIVEN — a reporter over a two-suite run
    let sut = try makeSUT()

    // WHEN — the payload is built
    let payload = try OTLPPayload(data: try sut.payload(for: Self.testRun))

    // THEN — exactly the three agreed metrics are present
    #expect(
      Set(payload.metricsByName.keys) == [
        "cicd.test.case.count", "cicd.test.case.duration", "cicd.test.run.duration",
      ]
    )
  }

  @Test("payload countsCasesByStatusPerSuite")
  func test_payload_countsCasesByStatusPerSuite() throws {
    // GIVEN — a reporter with the per-suite breakdown enabled
    let sut = try makeSUT(isPerSuiteEnabled: true)

    // WHEN — the case count data points are read
    let dataPoints = try payload(from: sut).gaugeDataPoints("cicd.test.case.count")

    // THEN — each suite reports a count for every status
    #expect(counts(in: dataPoints, suite: "GreeterTests") == ["pass": 2, "fail": 0, "skip": 0])
    #expect(counts(in: dataPoints, suite: "RecordingTests") == ["pass": 0, "fail": 1, "skip": 1])
  }

  @Test("payload aggregatesAcrossSuitesWhenPerSuiteDisabled")
  func test_payload_aggregatesAcrossSuitesWhenPerSuiteDisabled() throws {
    // GIVEN — a reporter with the per-suite breakdown disabled
    let sut = try makeSUT(isPerSuiteEnabled: false)

    // WHEN — the case count data points are read
    let dataPoints = try payload(from: sut).gaugeDataPoints("cicd.test.case.count")

    // THEN — one data point per status, none carrying a suite name
    #expect(dataPoints.count == 3)
    #expect(dataPoints.allSatisfy { OTLPPayload.attributes(of: $0)["test.suite.name"] == nil })
    #expect(counts(in: dataPoints, suite: .none) == ["pass": 2, "fail": 1, "skip": 1])
  }

  @Test("payload reportsRunDurationInMilliseconds")
  func test_payload_reportsRunDurationInMilliseconds() throws {
    // GIVEN — a run lasting 1.5 seconds
    let sut = try makeSUT()

    // WHEN — the run duration data point is read
    let dataPoints = try payload(from: sut).gaugeDataPoints("cicd.test.run.duration")
    let dataPoint = try #require(dataPoints.first)

    // THEN — a single unattributed point carrying milliseconds
    #expect(dataPoints.count == 1)
    #expect(OTLPPayload.attributes(of: dataPoint).isEmpty)
    #expect(dataPoint["asDouble"] as? Double == 1500)
  }

  @Test("payload bucketsCaseDurationsInMilliseconds")
  func test_payload_bucketsCaseDurationsInMilliseconds() throws {
    // GIVEN — a suite with cases of 2ms and 8ms against boundaries of 0, 5, 10, …
    let sut = try makeSUT()

    // WHEN — the histogram point for that suite is read
    let dataPoints = try payload(from: sut).histogramDataPoints("cicd.test.case.duration")
    let dataPoint = try #require(
      dataPoints.first { OTLPPayload.attributes(of: $0)["test.suite.name"] == "GreeterTests" }
    )

    // THEN — the values land in the 0–5 and 5–10 buckets, and the sum is in milliseconds
    #expect(dataPoint["count"] as? String == "2")
    #expect(dataPoint["sum"] as? Double == 10)
    #expect(dataPoint["min"] as? Double == 2)
    #expect(dataPoint["max"] as? Double == 8)
    #expect((dataPoint["bucketCounts"] as? [String])?.prefix(4) == ["0", "1", "1", "0"])
  }

  @Test("payload omitsResourceAttributesTheCICannotReport")
  func test_payload_omitsResourceAttributesTheCICannotReport() throws {
    // GIVEN — a CI reporting an owner and repository but no pipeline metadata
    let ci = MockCI(
      repository: CI.Repository(organizationName: "MacPaw", repositoryName: "mpct", provider: "github")
    )
    let sut = try makeSUT(ci: ci)

    // WHEN — the resource attributes are read
    let attributes = try payload(from: sut).resourceAttributes

    // THEN — reported attributes are present and unreported ones are absent, not blank
    #expect(attributes["vcs.owner.name"] == "MacPaw")
    #expect(attributes["vcs.repository.name"] == "mpct")
    #expect(attributes["vcs.provider.name"] == "github")
    #expect(attributes["cicd.provider.name"] == "Mock CI")
    #expect(attributes["cicd.pipeline.name"] == nil)
    #expect(attributes["cicd.pipeline.run.id"] == nil)
  }

  @Test("payload mapsPipelineRunMetadataToResourceAttributes")
  func test_payload_mapsPipelineRunMetadataToResourceAttributes() throws {
    // GIVEN — a CI reporting full pipeline run metadata
    let ci = MockCI(
      cicd: CI.CICD(
        pipelineName: "CI",
        run: CI.CICD.Run(
          id: "42",
          number: "20260914.1",
          taskName: "Test",
          stageName: "Build",
          url: URL(string: "https://dev.azure.com/macpaw/mpct/_build/results?buildId=42"),
        ),
      )
    )
    let sut = try makeSUT(ci: ci)

    // WHEN — the resource attributes are read
    let attributes = try payload(from: sut).resourceAttributes

    // THEN — every run field is carried under its semantic convention name
    #expect(attributes["cicd.pipeline.name"] == "CI")
    #expect(attributes["cicd.pipeline.task.name"] == "Test")
    #expect(attributes["cicd.pipeline.stage.name"] == "Build")
    #expect(attributes["cicd.pipeline.run.id"] == "42")
    #expect(attributes["cicd.pipeline.run.number"] == "20260914.1")
    #expect(attributes["cicd.pipeline.run.url.full"] == "https://dev.azure.com/macpaw/mpct/_build/results?buildId=42")
  }

  @Test("payload timestampsEveryDataPointWithTheConfiguredInstant")
  func test_payload_timestampsEveryDataPointWithTheConfiguredInstant() throws {
    // GIVEN — a reporter configured with a fixed timestamp
    let sut = try makeSUT()

    // WHEN — every data point's timestamp is collected
    let decoded = try payload(from: sut)
    let timestamps =
      try decoded.gaugeDataPoints("cicd.test.case.count").compactMap { $0["timeUnixNano"] as? String }
      + decoded.histogramDataPoints("cicd.test.case.duration").compactMap { $0["timeUnixNano"] as? String }

    // THEN — all share the configured instant, in nanoseconds
    #expect(Set(timestamps) == ["1700000000000000000"])
  }

  // MARK: - Helpers

  /// Builds and decodes the payload for the shared test run.
  ///
  /// - Parameter sut: The reporter under test.
  /// - Returns: The decoded payload.
  /// - Throws: An error if the payload cannot be built or decoded.
  private func payload(from sut: TestsOTELReporter) throws -> OTLPPayload {
    try OTLPPayload(data: try sut.payload(for: Self.testRun))
  }

  /// Collects case counts by status for one suite.
  ///
  /// - Parameters:
  ///   - dataPoints: The case count data points.
  ///   - suite: Suite name to filter by, or `nil` for data points carrying no suite.
  /// - Returns: Counts keyed by result status.
  private func counts(in dataPoints: [[String: Any]], suite: String?) -> [String: Int] {
    dataPoints.reduce(into: [String: Int]()) { counts, dataPoint in
      let attributes = OTLPPayload.attributes(of: dataPoint)
      guard attributes["test.suite.name"] == suite else { return }
      guard let status = attributes["test.case.result.status"], let value = dataPoint["asInt"] as? String else {
        return
      }
      counts[status] = Int(value)
    }
  }
}
