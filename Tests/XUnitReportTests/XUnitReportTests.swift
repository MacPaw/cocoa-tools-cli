import Foundation
import Testing

@testable import XUnitReport

@Suite
struct XUnitReportTests {
  private func fixtureURL() throws -> URL {
    try #require(Bundle.module.resourceURL).appendingPathComponent("test-package-xUnit-swift-testing.xml")
  }

  @Test("load returnsNonEmptySuites")
  func test_load_returnsNonEmptySuites() throws {
    // GIVEN — xUnit fixture with passing + failing + skipped tests
    // WHEN
    let sut = try XUnitReport.load(from: fixtureURL())
    // THEN
    #expect(!sut.testSuites.isEmpty)
  }

  @Test("load suiteHasNonZeroTests")
  func test_load_suiteHasNonZeroTests() throws {
    // GIVEN
    // WHEN
    let sut = try XUnitReport.load(from: fixtureURL())
    let suite = try #require(sut.testSuites.first)
    // THEN
    #expect(suite.name == "TestResults")
    #expect(suite.tests > 0)
  }

  @Test("load testCaseHasDecomposedClassName")
  func test_load_testCaseHasDecomposedClassName() throws {
    // GIVEN — XCResultCoverageTests cases appear in the fixture with a two-component className
    // WHEN
    let sut = try XUnitReport.load(from: fixtureURL())
    let allCases = sut.testSuites.flatMap(\.testCases)
    let testCase = try #require(allCases.first { $0.className == "TargetATests.GreeterTests" })
    // THEN
    #expect(testCase.moduleName == "TargetATests")
    #expect(testCase.suiteName == "GreeterTests")
  }

  @Test("load recordingSuiteHasExpectedFailures")
  func test_load_recordingSuiteHasExpectedFailures() throws {
    // GIVEN — recording suite always produces exactly 2 unexpected failures and 1 skip
    // WHEN
    let sut = try XUnitReport.load(from: fixtureURL())
    let recordingCases = sut.testSuites.flatMap(\.testCases)
      .filter { $0.className == "RecordingTests.RecordingTestsTesting" }
    // THEN
    #expect(recordingCases.filter { $0.failure != nil }.count == 2)
    #expect(recordingCases.contains(where: { $0.isSkipped }))
  }

  @Test("load recordingFailureMessagesMatch")
  func test_load_recordingFailureMessagesMatch() throws {
    // GIVEN — recording suite produces one #expect failure and one thrown-error failure
    // WHEN
    let sut = try XUnitReport.load(from: fixtureURL())
    let messages = sut.testSuites.flatMap(\.testCases)
      .filter { $0.className == "RecordingTests.RecordingTestsTesting" }
      .compactMap(\.failure?.message)
    // THEN
    #expect(messages.contains { $0.hasPrefix("Expectation failed:") })
    #expect(messages.contains { $0.hasPrefix("Caught error:") })
  }
}
