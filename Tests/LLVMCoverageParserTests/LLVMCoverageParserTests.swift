import Foundation
import Testing

@testable import LLVMCoverageParser

@Suite
struct LLVMCoverageParserTests {
  private var fixtureURL: URL {
    Bundle.module.resourceURL!.appendingPathComponent("lcov.json")
  }

  @Test("load dataIsNonEmpty")
  func test_load_dataIsNonEmpty() throws {
    // GIVEN — lcov fixture
    // WHEN
    let sut = try LLVMCoverage.load(from: fixtureURL)
    // THEN
    #expect(!sut.data.isEmpty)
  }

  @Test("load totalsHasNonZeroLineCount")
  func test_load_totalsHasNonZeroLineCount() throws {
    // GIVEN
    // WHEN
    let sut = try LLVMCoverage.load(from: fixtureURL)
    let coverage = try #require(sut.data.first)
    // THEN
    #expect(coverage.totals.lines.count > 0)
  }

  @Test("load fileHasNonEmptyFilename")
  func test_load_fileHasNonEmptyFilename() throws {
    // GIVEN
    // WHEN
    let sut = try LLVMCoverage.load(from: fixtureURL)
    let coverage = try #require(sut.data.first)
    let file = try #require(coverage.files.first)
    // THEN
    #expect(!file.filename.isEmpty)
  }

  @Test("load fileLineCoveragePercentIsValid")
  func test_load_fileLineCoveragePercentIsValid() throws {
    // GIVEN
    // WHEN
    let sut = try LLVMCoverage.load(from: fixtureURL)
    let coverage = try #require(sut.data.first)
    let file = try #require(coverage.files.first)
    // THEN
    #expect(file.summary.lines.percent >= 0)
    #expect(file.summary.lines.percent <= 100)
  }

  @Test("load branchStatHasNotCovered")
  func test_load_branchStatHasNotCovered() throws {
    // GIVEN — branches always carry the notcovered field
    // WHEN
    let sut = try LLVMCoverage.load(from: fixtureURL)
    let coverage = try #require(sut.data.first)
    let file = try #require(coverage.files.first)
    // THEN
    #expect(file.summary.branches.notCovered != nil)
  }

  @Test("load lineStatHasNoNotCovered")
  func test_load_lineStatHasNoNotCovered() throws {
    // GIVEN — lines do not carry the notcovered field
    // WHEN
    let sut = try LLVMCoverage.load(from: fixtureURL)
    let coverage = try #require(sut.data.first)
    let file = try #require(coverage.files.first)
    // THEN
    #expect(file.summary.lines.notCovered == nil)
  }
}
