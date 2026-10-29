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
  ///   - serviceName: Value of the `service.name` resource attribute.
  ///   - ci: The CI to derive resource attributes from.
  /// - Returns: The configured reporter.
  /// - Throws: An error if the endpoint URL cannot be built.
  private func makeSUT(
    isPerSuiteEnabled: Bool = true,
    serviceName: String = TestsOTELReporter.Configuration.defaultServiceName,
    ci: any CIInterface = MockCI(),
  ) throws -> TestsOTELReporter {
    TestsOTELReporter(
      configuration: TestsOTELReporter.Configuration(
        endpoint: try #require(URL(string: "https://collector.example")),
        isPerSuiteEnabled: isPerSuiteEnabled,
        serviceName: serviceName,
        timestamp: Date(timeIntervalSince1970: 1_700_000_000),
      ),
      ci: ci,
    )
  }

  @Test("payload emitsTheAgreedMetrics")
  func test_payload_emitsTheAgreedMetrics() throws {
    // GIVEN — a reporter over a two-suite run
    let sut = try makeSUT()

    // WHEN — the payload is built
    let payload = try OTLPPayload(data: try sut.payload(for: Self.testRun))

    // THEN — exactly the agreed metrics are present
    #expect(
      Set(payload.metricsByName.keys) == [
        "cicd.test.case.count", "cicd.test.case.duration", "cicd.test.suite.duration", "cicd.test.run.duration",
      ]
    )
  }

  @Test("payload omitsSuiteDurationWhenPerSuiteDisabled")
  func test_payload_omitsSuiteDurationWhenPerSuiteDisabled() throws {
    // GIVEN — a reporter with the per-suite breakdown disabled
    let sut = try makeSUT(isPerSuiteEnabled: false)

    // WHEN — the payload is built
    let payload = try payload(from: sut)

    // THEN — there is no suite to attribute a duration to
    #expect(payload.metricsByName["cicd.test.suite.duration"] == nil)
  }

  @Test("payload sumsCaseDurationsPerSuiteInMilliseconds")
  func test_payload_sumsCaseDurationsPerSuiteInMilliseconds() throws {
    // GIVEN — a reporter over suites whose cases last 2ms + 8ms and 300ms + 0ms
    let sut = try makeSUT()

    // WHEN — the suite duration data points are read
    let dataPoints = try payload(from: sut).gaugeDataPoints("cicd.test.suite.duration")

    // THEN — each suite reports the sum of its cases, in milliseconds
    #expect(dataPoints.count == 2)
    #expect(try duration(in: dataPoints, suite: "GreeterTests") == 10)
    #expect(try duration(in: dataPoints, suite: "RecordingTests") == 300)
  }

  @Test("payload derivesSuiteRunStatusFromItsCases")
  func test_payload_derivesSuiteRunStatusFromItsCases() throws {
    // GIVEN — a passing suite, a failing one and a suite where everything was skipped
    let testRun = TestRun(
      suites: [
        TestRun.Suite(name: "Passing", testCases: [.init(name: "a", status: .pass, duration: 0)]),
        TestRun.Suite(
          name: "Failing",
          testCases: [.init(name: "b", status: .pass, duration: 0), .init(name: "c", status: .fail, duration: 0)],
        ),
        TestRun.Suite(name: "Skipped", testCases: [.init(name: "d", status: .skip, duration: 0)]),
      ],
      duration: 1,
    )
    let sut = try makeSUT()

    // WHEN — the suite duration data points are read
    let payload = try OTLPPayload(data: try sut.payload(for: testRun))
    let dataPoints = try payload.gaugeDataPoints("cicd.test.suite.duration")
    let statuses = Dictionary(
      uniqueKeysWithValues: dataPoints.map {
        let attributes = OTLPPayload.attributes(of: $0)
        return (attributes["test.suite.name"] ?? "", attributes["test.suite.run.status"] ?? "")
      }
    )

    // THEN — a failure wins, and only an all-skipped suite is skipped
    #expect(statuses == ["Passing": "success", "Failing": "failure", "Skipped": "skipped"])
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

    // THEN — a single point carrying milliseconds, and nothing but the run status
    #expect(dataPoints.count == 1)
    #expect(Set(OTLPPayload.attributes(of: dataPoint).keys) == ["test.suite.run.status"])
    #expect(dataPoint["asDouble"] as? Double == 1500)
  }

  @Test("payload reportsRunStatusOnRunDuration")
  func test_payload_reportsRunStatusOnRunDuration() throws {
    // GIVEN — a run in which one test case failed
    let sut = try makeSUT()

    // WHEN — the run duration data point is read
    let dataPoint = try #require(try payload(from: sut).gaugeDataPoints("cicd.test.run.duration").first)

    // THEN — the run is a failure
    #expect(OTLPPayload.attributes(of: dataPoint)["test.suite.run.status"] == "failure")
  }

  @Test("payload bucketsCaseDurationsInMilliseconds")
  func test_payload_bucketsCaseDurationsInMilliseconds() throws {
    // GIVEN — a suite with cases of 2ms and 8ms against boundaries of 0, 0.1, 0.25, 0.5, 1, 2.5, 5, 10, …
    let sut = try makeSUT()

    // WHEN — the histogram point for that suite is read
    let dataPoints = try payload(from: sut).histogramDataPoints("cicd.test.case.duration")
    let dataPoint = try #require(
      dataPoints.first { OTLPPayload.attributes(of: $0)["test.suite.name"] == "GreeterTests" }
    )

    // THEN — the values land in the 1–2.5 and 5–10 buckets, and the sum is in milliseconds
    #expect(dataPoint["count"] as? String == "2")
    #expect(dataPoint["sum"] as? Double == 10)
    #expect(dataPoint["min"] as? Double == 2)
    #expect(dataPoint["max"] as? Double == 8)
    #expect((dataPoint["bucketCounts"] as? [String])?.prefix(8) == ["0", "0", "0", "0", "0", "1", "0", "1"])
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

  @Test("payload repeatsFilterableCIAttributesOnEveryDataPoint")
  func test_payload_repeatsFilterableCIAttributesOnEveryDataPoint() throws {
    // GIVEN — a CI reporting repository, pipeline, stage, job and run metadata
    let ci = MockCI(
      repository: CI.Repository(organizationName: "MacPaw", repositoryName: "mpct", provider: "github"),
      cicd: CI.CICD(pipelineName: "CI", run: CI.CICD.Run(id: "42", taskName: "Test", stageName: "Build")),
    )
    let sut = try makeSUT(ci: ci)

    // WHEN — the payload is built
    let payload = try payload(from: sut)

    // THEN — every data point of every metric carries the filterable attributes, but not the run id
    let dataPoints =
      try payload.gaugeDataPoints("cicd.test.case.count")
      + payload.gaugeDataPoints("cicd.test.suite.duration")
      + payload.gaugeDataPoints("cicd.test.run.duration")
      + payload.histogramDataPoints("cicd.test.case.duration")
    #expect(!dataPoints.isEmpty)
    for dataPoint in dataPoints {
      let attributes = OTLPPayload.attributes(of: dataPoint)
      #expect(attributes["vcs.repository.name"] == "mpct")
      #expect(attributes["cicd.pipeline.name"] == "CI")
      #expect(attributes["cicd.pipeline.stage.name"] == "Build")
      #expect(attributes["cicd.pipeline.task.name"] == "Test")
      #expect(attributes["cicd.pipeline.run.id"] == nil)
    }
  }

  @Test("payload keepsTestCaseNamesOffMetrics")
  func test_payload_keepsTestCaseNamesOffMetrics() throws {
    // GIVEN — a reporter over a run with named test cases
    let sut = try makeSUT()

    // WHEN — every data point of every metric is collected
    let payload = try payload(from: sut)
    let dataPoints =
      try payload.gaugeDataPoints("cicd.test.case.count")
      + payload.gaugeDataPoints("cicd.test.suite.duration")
      + payload.gaugeDataPoints("cicd.test.run.duration")
      + payload.histogramDataPoints("cicd.test.case.duration")

    // THEN — none is labelled with a test case name, which would be a series per test
    #expect(!dataPoints.isEmpty)
    #expect(dataPoints.allSatisfy { OTLPPayload.attributes(of: $0)["test.case.name"] == nil })
  }

  @Test("payload carriesServiceNameWithoutInstanceID")
  func test_payload_carriesServiceNameWithoutInstanceID() throws {
    // GIVEN — a configured service name and a CI reporting run number 7
    let ci = MockCI(cicd: CI.CICD(run: CI.CICD.Run(id: "42", number: "7")))
    let sut = try makeSUT(serviceName: "my-service", ci: ci)

    // WHEN — the resource attributes are read
    let attributes = try payload(from: sut).resourceAttributes

    // THEN — no per-run instance id, which Mimir would turn into a per-run `instance` label
    #expect(attributes["service.name"] == "my-service")
    #expect(attributes["service.instance.id"] == nil)
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

  /// Reads the duration reported for one suite.
  ///
  /// - Parameters:
  ///   - dataPoints: The suite duration data points.
  ///   - suite: Suite name to look up.
  /// - Returns: The duration, in milliseconds.
  /// - Throws: An error if the suite has no data point.
  private func duration(in dataPoints: [[String: Any]], suite: String) throws -> Double? {
    let dataPoint = try #require(dataPoints.first { OTLPPayload.attributes(of: $0)["test.suite.name"] == suite })
    return dataPoint["asDouble"] as? Double
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
