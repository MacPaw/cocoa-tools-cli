import Foundation
import Testing

@testable import XUnitParser

@Suite
struct XUnitParserTests {
  private var passingFixtureURL: URL {
    Bundle.module.resourceURL!.appendingPathComponent("cocoa-tools-debug-xUnit-swift-testing.xml")
  }

  private var failuresFixtureURL: URL {
    Bundle.module.resourceURL!.appendingPathComponent("xunit-with-failures.xml")
  }

  @Test("load returnsNonEmptySuites")
  func test_load_returnsNonEmptySuites() throws {
    // GIVEN — path to all-passing fixture
    // WHEN
    let sut = try TestSuites.load(from: passingFixtureURL)
    // THEN
    #expect(!sut.suites.isEmpty)
  }

  @Test("load suiteHasCorrectTestCount")
  func test_load_suiteHasCorrectTestCount() throws {
    // GIVEN — path to all-passing fixture
    // WHEN
    let sut = try TestSuites.load(from: passingFixtureURL)
    let suite = try #require(sut.suites.first)
    // THEN
    #expect(suite.name == "TestResults")
    #expect(suite.tests == 83)
    #expect(suite.failures == 0)
    #expect(suite.testCases.count == 83)
  }

  @Test("load testCaseHasDecomposedClassname")
  func test_load_testCaseHasDecomposedClassname() throws {
    // GIVEN — first test case classname is "XCResultParsingTests.XCResultParsingTests"
    // WHEN
    let sut = try TestSuites.load(from: passingFixtureURL)
    let testCase = try #require(sut.suites.first?.testCases.first)
    // THEN
    #expect(testCase.moduleName == "XCResultParsingTests")
    #expect(testCase.suiteName == "XCResultParsingTests")
  }

  @Test("load allPassingTestCasesHaveNoFailure")
  func test_load_allPassingTestCasesHaveNoFailure() throws {
    // GIVEN — all-passing fixture
    // WHEN
    let sut = try TestSuites.load(from: passingFixtureURL)
    let allTestCases = sut.suites.flatMap(\.testCases)
    // THEN
    #expect(allTestCases.allSatisfy { $0.failure == nil })
    #expect(allTestCases.allSatisfy { !$0.isSkipped })
  }

  @Test("load failuresFixture hasFailures")
  func test_load_failuresFixture_hasFailures() throws {
    // GIVEN — fixture with intentional failures
    // WHEN
    let sut = try TestSuites.load(from: failuresFixtureURL)
    let allTestCases = sut.suites.flatMap(\.testCases)
    // THEN
    #expect(allTestCases.contains { $0.failure != nil })
  }

  @Test("load failuresFixture hasSkippedTest")
  func test_load_failuresFixture_hasSkippedTest() throws {
    // GIVEN — fixture with intentional skip
    // WHEN
    let sut = try TestSuites.load(from: failuresFixtureURL)
    let allTestCases = sut.suites.flatMap(\.testCases)
    // THEN
    #expect(allTestCases.contains(where: { $0.isSkipped }))
  }

  @Test("load failuresFixture failureHasMessage")
  func test_load_failuresFixture_failureHasMessage() throws {
    // GIVEN — fixture with a failure containing a message
    // WHEN
    let sut = try TestSuites.load(from: failuresFixtureURL)
    let allTestCases = sut.suites.flatMap(\.testCases)
    let failedCase = try #require(allTestCases.first { $0.failure != nil })
    // THEN
    #expect(!failedCase.failure!.message.isEmpty)
  }
}
