import CI
import Foundation
import Testing

@testable import TestsOTELReporter

@Suite
struct TestsOTELReporterLineCoverageTests {
  /// Line coverage of two targets: one fully covered and one partly covered.
  private static let lineCoverage: LineCoverage = LineCoverage(
    targets: [
      LineCoverage.Target(name: "Core", coveredLines: 100, executableLines: 100),
      LineCoverage.Target(name: "Shell", coveredLines: 30, executableLines: 40),
    ]
  )

  /// Builds a reporter over a CI reporting no metadata.
  ///
  /// - Returns: The configured reporter.
  /// - Throws: An error if the endpoint URL cannot be built.
  private func makeSUT() throws -> TestsOTELReporter {
    TestsOTELReporter(
      configuration: TestsOTELReporter.Configuration(
        endpoint: try #require(URL(string: "https://collector.example")),
        timestamp: Date(timeIntervalSince1970: 1_700_000_000),
      ),
      ci: MockCI(),
    )
  }

  /// Reads the coverage gauge into `target/status → lines`.
  ///
  /// - Parameter payload: The decoded payload.
  /// - Returns: The line count of every data point, keyed by `target/status`.
  /// - Throws: An error if the gauge is absent.
  private func lineCounts(in payload: OTLPPayload) throws -> [String: String] {
    try payload.gaugeDataPoints("cicd.test.coverage.line.count")
      .reduce(into: [:]) { result, dataPoint in
        let attributes = OTLPPayload.attributes(of: dataPoint)
        let key = "\(attributes["test.coverage.target.name"] ?? "")/\(attributes["test.coverage.line.status"] ?? "")"
        result[key] = dataPoint["asInt"] as? String
      }
  }

  @Test("payload emitsLineCoverageCountPerTargetAndStatus")
  func test_payload_emitsLineCoverageCountPerTargetAndStatus() throws {
    // GIVEN — a reporter and line coverage of two targets
    let sut = try makeSUT()

    // WHEN
    let payload = try OTLPPayload(data: try sut.payload(testRun: .none, lineCoverage: Self.lineCoverage))

    // THEN — covered and uncovered lines are disjoint, so they add up to the executable lines
    #expect(
      try lineCounts(in: payload) == [
        "Core/covered": "100", "Core/uncovered": "0", "Shell/covered": "30", "Shell/uncovered": "10",
      ]
    )
  }

  @Test("payload emitsLineCoverageInLines")
  func test_payload_emitsLineCoverageInLines() throws {
    // GIVEN
    let sut = try makeSUT()

    // WHEN
    let payload = try OTLPPayload(data: try sut.payload(testRun: .none, lineCoverage: Self.lineCoverage))

    // THEN
    let metric = try #require(payload.metricsByName["cicd.test.coverage.line.count"])
    #expect(metric["unit"] as? String == "{line}")
  }

  @Test("payload emitsOnlyLineCoverageWhenThereIsNoTestRun")
  func test_payload_emitsOnlyLineCoverageWhenThereIsNoTestRun() throws {
    // GIVEN
    let sut = try makeSUT()

    // WHEN
    let payload = try OTLPPayload(data: try sut.payload(testRun: .none, lineCoverage: Self.lineCoverage))

    // THEN
    #expect(Set(payload.metricsByName.keys) == ["cicd.test.coverage.line.count"])
  }

  @Test("payload emitsNoLineCoverageMetricWhenThereIsNoLineCoverage")
  func test_payload_emitsNoLineCoverageMetricWhenThereIsNoLineCoverage() throws {
    // GIVEN
    let sut = try makeSUT()
    let testRun = TestRun(
      suites: [
        TestRun.Suite(name: "Suite", testCases: [TestRun.Suite.TestCase(name: "case", status: .pass, duration: 0.1)])
      ],
      duration: 1,
    )

    // WHEN
    let payload = try OTLPPayload(data: try sut.payload(for: testRun))

    // THEN
    #expect(payload.metricsByName["cicd.test.coverage.line.count"] == nil)
  }

  @Test("payload emitsNoRunLevelLineCoverageTotal")
  func test_payload_emitsNoRunLevelLineCoverageTotal() throws {
    // GIVEN
    let sut = try makeSUT()

    // WHEN
    let payload = try OTLPPayload(data: try sut.payload(testRun: .none, lineCoverage: Self.lineCoverage))

    // THEN — a total data point would double-count in a sum over the target attribute
    let dataPoints = try payload.gaugeDataPoints("cicd.test.coverage.line.count")
    #expect(dataPoints.count == 4)
    #expect(dataPoints.allSatisfy { OTLPPayload.attributes(of: $0)["test.coverage.target.name"] != nil })
  }

  @Test("uncoveredLines neverGoesNegative")
  func test_uncoveredLines_neverGoesNegative() {
    // GIVEN — a report claiming more covered lines than executable ones
    let sut = LineCoverage.Target(name: "Odd", coveredLines: 5, executableLines: 3)

    // WHEN
    let uncovered = sut.uncoveredLines

    // THEN
    #expect(uncovered == 0)
  }
}
