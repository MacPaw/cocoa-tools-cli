import Foundation
import Testing

@testable import XCResultParsing

#if os(macOS)
  @Suite
  struct XCResultCoverageTests {
    private var xcresultURL: URL {
      Bundle.module.resourceURL!.appendingPathComponent("cocoa-tools-debug.xcresult")
    }

    @Test("load returnsNonEmptyTargets")
    func test_load_returnsNonEmptyTargets() throws {
      // GIVEN — path to fixture xcresult
      // WHEN — loading coverage via xccov view --report --json
      let sut = try XCResultCoverage.load(from: xcresultURL)

      // THEN — at least one target with executable lines
      #expect(sut.executableLines > 0)
      #expect(!sut.targets.isEmpty)
    }

    @Test("load hasCoverageFilesWithFunctions")
    func test_load_hasCoverageFilesWithFunctions() throws {
      // GIVEN — path to fixture xcresult
      // WHEN — loading coverage
      let sut = try XCResultCoverage.load(from: xcresultURL)

      // THEN — every target has files, every file has at least one function
      let allFiles = sut.targets.flatMap(\.files)
      #expect(!allFiles.isEmpty)
      #expect(allFiles.allSatisfy { !$0.functions.isEmpty })
    }

    @Test("load CIType hasExecutedFunction")
    func test_load_CIType_hasExecutedFunction() throws {
      // GIVEN — path to fixture xcresult
      // WHEN — loading coverage and locating CIType.swift
      let sut = try XCResultCoverage.load(from: xcresultURL)
      let allFiles = sut.targets.flatMap(\.files)
      let ciFile = try #require(allFiles.first { $0.name == "CIType.swift" })

      // THEN — CIType.init(name:) at line 8 has been executed at least once
      let initFn = try #require(ciFile.functions.first { $0.lineNumber == 8 })
      #expect(initFn.executionCount >= 1)
    }
  }
#endif
