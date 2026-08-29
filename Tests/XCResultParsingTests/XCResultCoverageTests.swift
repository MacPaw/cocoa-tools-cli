import Foundation
import Testing

@testable import XCResultParsing

#if os(macOS)
  @Suite
  struct XCResultCoverageTests {
    private var xcresultURL: URL {
      Bundle.module.resourceURL!.appendingPathComponent("test-package.xcresult")
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

    @Test("load Greeter hasExecutedFunction")
    func test_load_Greeter_hasExecutedFunction() throws {
      // GIVEN — path to fixture xcresult
      // WHEN — loading coverage and locating Greeter.swift
      let sut = try XCResultCoverage.load(from: xcresultURL)
      let allFiles = sut.targets.flatMap(\.files)
      let greeterFile = try #require(allFiles.first { $0.name == "Greeter.swift" })

      // THEN — greet(_:) at line 2 has been executed at least once
      let greetFn = try #require(greeterFile.functions.first { $0.lineNumber == 2 })
      #expect(greetFn.executionCount >= 1)
    }
  }
#endif
