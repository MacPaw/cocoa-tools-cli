import Foundation
import Testing

@testable import LLVMCoverageParser

@Suite
struct LLVMCoverageDiffTests {
  private var beforeURL: URL {
    Bundle.module.resourceURL!.appendingPathComponent("llvm-diff-before.json")
  }

  private var afterURL: URL {
    Bundle.module.resourceURL!.appendingPathComponent("llvm-diff-after.json")
  }

  /// Derives path equivalence by finding the first /Sources/ file and splitting on that marker.
  private func pathEquivalence(before: LLVMCoverage, after: LLVMCoverage) -> (before: String, after: String)? {
    guard
      let beforeFilename = before.data.first?.files.first(where: { $0.filename.contains("/Sources/") })?.filename,
      let afterFilename = after.data.first?.files.first(where: { $0.filename.contains("/Sources/") })?.filename
    else { return nil }
    return (
      before: beforeFilename.components(separatedBy: "/Sources/").first ?? "",
      after: afterFilename.components(separatedBy: "/Sources/").first ?? "",
    )
  }

  @Test("diff addedFiles hasTarget3Sources")
  func test_diff_addedFiles_hasTarget3Sources() throws {
    // GIVEN — before has Target1+Target2, after has Target2+Target3
    let before = try LLVMCoverage.load(from: beforeURL)
    let after = try LLVMCoverage.load(from: afterURL)

    // WHEN — computing diff
    let sut = LLVMCoverageDiff.diff(
      before: before,
      after: after,
      pathEquivalence: pathEquivalence(before: before, after: after),
    )

    // THEN — added files include at least one from Target3
    #expect(sut.addedFiles.contains { $0.filename.contains("Target3") })
  }

  @Test("diff removedFiles hasTarget1Sources")
  func test_diff_removedFiles_hasTarget1Sources() throws {
    // GIVEN — before has Target1+Target2, after has Target2+Target3
    let before = try LLVMCoverage.load(from: beforeURL)
    let after = try LLVMCoverage.load(from: afterURL)

    // WHEN — computing diff
    let sut = LLVMCoverageDiff.diff(
      before: before,
      after: after,
      pathEquivalence: pathEquivalence(before: before, after: after),
    )

    // THEN — removed files include at least one from Target1
    #expect(sut.removedFiles.contains { $0.filename.contains("Target1") })
  }

  @Test("diff totalsDelta linesPercentDeltaIsNonZero")
  func test_diff_totalsDelta_linesPercentDeltaIsNonZero() throws {
    // GIVEN — two builds with different coverage across different source sets
    let before = try LLVMCoverage.load(from: beforeURL)
    let after = try LLVMCoverage.load(from: afterURL)

    // WHEN — computing diff
    let sut = LLVMCoverageDiff.diff(
      before: before,
      after: after,
      pathEquivalence: pathEquivalence(before: before, after: after),
    )

    // THEN — overall line coverage percentage changed between the two builds
    #expect(sut.totalsDelta.lines.percentDelta != 0)
  }

  @Test("diff fileDeltas hasStructDPositiveDelta")
  func test_diff_fileDeltas_hasStructDPositiveDelta() throws {
    // GIVEN — StructD gains coverage for lowercased() in the after build
    let before = try LLVMCoverage.load(from: beforeURL)
    let after = try LLVMCoverage.load(from: afterURL)

    // WHEN — locating StructD in fileDeltas
    let sut = LLVMCoverageDiff.diff(
      before: before,
      after: after,
      pathEquivalence: pathEquivalence(before: before, after: after),
    )
    let structDDelta = try #require(sut.fileDeltas.first { $0.filename.hasSuffix("StructD.swift") })

    // THEN — StructD line coverage improved
    #expect(structDDelta.summaryDelta.lines.percentDelta > 0)
  }

  @Test("diff fileDeltas hasStructENegativeDelta")
  func test_diff_fileDeltas_hasStructENegativeDelta() throws {
    // GIVEN — StructE loses coverage for isNegative() in the after build
    let before = try LLVMCoverage.load(from: beforeURL)
    let after = try LLVMCoverage.load(from: afterURL)

    // WHEN — locating StructE in fileDeltas
    let sut = LLVMCoverageDiff.diff(
      before: before,
      after: after,
      pathEquivalence: pathEquivalence(before: before, after: after),
    )
    let structEDelta = try #require(sut.fileDeltas.first { $0.filename.hasSuffix("StructE.swift") })

    // THEN — StructE line coverage regressed
    #expect(structEDelta.summaryDelta.lines.percentDelta < 0)
  }
}
