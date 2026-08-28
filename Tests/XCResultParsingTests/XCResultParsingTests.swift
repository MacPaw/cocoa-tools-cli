import Foundation
import Testing

@testable import XCResultParsing

@Suite
struct XCResultParsingTests {
  private var xcresultURL: URL {
    Bundle.module.resourceURL!.appendingPathComponent("cocoa-tools-debug.xcresult")
  }

  @Test("load returnsNonEmptyTargets")
  func test_load_returnsNonEmptyTargets() throws {
    // GIVEN — path to fixture xcresult
    // WHEN — loading coverage via xccov view --report --json
    let result = try CoverageReport.load(from: xcresultURL)

    // THEN — at least one target with executable lines
    #expect(result.executableLines > 0)
    #expect(!result.targets.isEmpty)
  }

  @Test("load hasCoverageFilesWithFunctions")
  func test_load_hasCoverageFilesWithFunctions() throws {
    // GIVEN — path to fixture xcresult
    // WHEN — loading coverage
    let result = try CoverageReport.load(from: xcresultURL)

    // THEN — every target has files, every file has at least one function
    let allFiles = result.targets.flatMap(\.files)
    #expect(!allFiles.isEmpty)
    #expect(allFiles.allSatisfy { !$0.functions.isEmpty })
  }

  @Test("load CIType hasExecutedFunction")
  func test_load_CIType_hasExecutedFunction() throws {
    // GIVEN — path to fixture xcresult
    // WHEN — loading coverage and locating CIType.swift
    let result = try CoverageReport.load(from: xcresultURL)
    let allFiles = result.targets.flatMap(\.files)
    let ciFile = try #require(allFiles.first { $0.name == "CIType.swift" })

    // THEN — CIType.init(name:) at line 8 has been executed at least once
    let initFn = try #require(ciFile.functions.first { $0.lineNumber == 8 })
    #expect(initFn.executionCount >= 1)
  }

  @Test("getTestResultsTests returnsDecodableTestResults")
  func test_getTestResultsTests_returnsDecodableTestResults() throws {
    // GIVEN — CLI wrapper targeting the fixture xcresult
    let sut = XCResultToolCLI()

    // WHEN — fetching JSON test results
    let data = try sut.getTestResultsTests(xcresultPath: xcresultURL)
    let result = try JSONDecoder().decode(TestResults.self, from: data)

    // THEN — at least one device and one test group present
    #expect(!result.devices.isEmpty)
    #expect(!result.testNodes.isEmpty)
  }
}
