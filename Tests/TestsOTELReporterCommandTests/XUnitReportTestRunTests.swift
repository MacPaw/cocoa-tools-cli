import Foundation
import Testing
import TestsOTELReporter

@testable import TestsOTELReporterCommand
@testable import XUnitReport

@Suite
struct XUnitReportTestRunTests {
  /// Builds an xUnit test case.
  ///
  /// - Parameters:
  ///   - className: Fully-qualified `Module.Suite` name.
  ///   - name: Test method name.
  ///   - time: Execution time in seconds.
  ///   - failure: Failure details, when the case failed.
  ///   - isSkipped: Whether the case was skipped.
  /// - Returns: The test case.
  private func testCase(
    className: String,
    name: String,
    time: Double = 0,
    failure: XUnitReport.TestSuite.TestCase.Failure? = .none,
    isSkipped: Bool = false,
  ) -> XUnitReport.TestSuite.TestCase {
    XUnitReport.TestSuite.TestCase(
      className: className,
      name: name,
      time: time,
      failure: failure,
      isSkipped: isSkipped,
    )
  }

  /// Builds a single-suite xUnit report.
  ///
  /// - Parameters:
  ///   - testCases: The cases in the report.
  ///   - time: Total suite time in seconds.
  /// - Returns: The report.
  private func report(testCases: [XUnitReport.TestSuite.TestCase], time: Double = 0) -> XUnitReport {
    XUnitReport(testSuites: [
      XUnitReport.TestSuite(
        name: "TestResults",
        tests: testCases.count,
        failures: testCases.count { $0.failure != nil },
        errors: 0,
        skipped: testCases.count(where: \.isSkipped),
        time: time,
        testCases: testCases,
      )
    ])
  }

  @Test("init groupsCasesByClassNameRatherThanEnclosingSuite")
  func test_init_groupsCasesByClassNameRatherThanEnclosingSuite() {
    // GIVEN — swift test emits every case under one synthetic suite, with real suites in className
    let report = report(testCases: [
      testCase(className: "TargetATests.GreeterTests", name: "greets"),
      testCase(className: "TargetBTests.ParserTests", name: "parses"),
      testCase(className: "TargetATests.GreeterTests", name: "greetsLoudly"),
    ])

    // WHEN
    let sut = TestRun(report: report)

    // THEN — one suite per class name, in first-seen order, with cases kept together
    #expect(sut.suites.map(\.name) == ["TargetATests.GreeterTests", "TargetBTests.ParserTests"])
    #expect(sut.suites.first?.testCases.map(\.name) == ["greets", "greetsLoudly"])
  }

  @Test("init mapsFailureAndSkipToStatus")
  func test_init_mapsFailureAndSkipToStatus() {
    // GIVEN — one passing, one failing, and one skipped case
    let report = report(testCases: [
      testCase(className: "Tests.Suite", name: "passes"),
      testCase(
        className: "Tests.Suite",
        name: "fails",
        failure: XUnitReport.TestSuite.TestCase.Failure(message: "boom", type: "Issue", body: .none),
      ),
      testCase(className: "Tests.Suite", name: "skips", isSkipped: true),
    ])

    // WHEN
    let sut = TestRun(report: report)

    // THEN
    #expect(sut.testCases.map(\.status) == [.pass, .fail, .skip])
  }

  @Test("init prefersSkipOverFailureWhenBothAreReported")
  func test_init_prefersSkipOverFailureWhenBothAreReported() {
    // GIVEN — a case marked skipped that also carries failure details
    let report = report(testCases: [
      testCase(
        className: "Tests.Suite",
        name: "skipped",
        failure: XUnitReport.TestSuite.TestCase.Failure(message: "boom", type: "Issue", body: .none),
        isSkipped: true,
      )
    ])

    // WHEN
    let sut = TestRun(report: report)

    // THEN — a test that never ran cannot have failed
    #expect(sut.testCases.map(\.status) == [.skip])
  }

  @Test("init sumsSuiteTimesForRunDuration")
  func test_init_sumsSuiteTimesForRunDuration() {
    // GIVEN — a report whose suite reports a wall time longer than its cases sum to
    let report = report(
      testCases: [testCase(className: "Tests.Suite", name: "passes", time: 0.25)],
      time: 4.5,
    )

    // WHEN
    let sut = TestRun(report: report)

    // THEN — the run duration comes from the suite, not from summing cases
    #expect(sut.duration == 4.5)
    #expect(sut.testCases.map(\.duration) == [0.25])
  }

  @Test("init returnsEmptyRunForReportWithoutCases")
  func test_init_returnsEmptyRunForReportWithoutCases() {
    // GIVEN — a report that parsed but contained no test cases
    let report = report(testCases: [])

    // WHEN
    let sut = TestRun(report: report)

    // THEN
    #expect(sut.suites.isEmpty)
    #expect(sut.testCases.isEmpty)
  }
}
