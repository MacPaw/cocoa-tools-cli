import Foundation
import LLVMCoverageParser
import Testing
import TestsOTELReporter

@testable import TestsOTELReporterCommand

@Suite
struct LLVMCoverageLineCoverageTests {
  /// Decodes an LLVM coverage export holding the given files.
  ///
  /// - Parameter files: Source file paths with their covered and executable line counts.
  /// - Returns: The decoded export.
  /// - Throws: An error if the JSON cannot be decoded.
  func makeLLVMCoverage(_ files: [(path: String, covered: Int, executable: Int)]) throws -> LLVMCoverage {
    let stat = { (covered: Int, executable: Int) in
      "{\"count\":\(executable),\"covered\":\(covered),\"percent\":0}"
    }
    let fileJSON = files.map { file in
      """
      {"filename":"\(file.path)","summary":{"lines":\(stat(file.covered, file.executable)),\
      "functions":\(stat(0, 0)),"branches":\(stat(0, 0))}}
      """
    }
    let totals = "{\"lines\":\(stat(0, 0)),\"functions\":\(stat(0, 0)),\"branches\":\(stat(0, 0))}"
    let json =
      "{\"version\":\"3.0.1\",\"data\":[{\"files\":[\(fileJSON.joined(separator: ","))],\"totals\":\(totals)}]}"

    return try JSONDecoder().decode(LLVMCoverage.self, from: Data(json.utf8))
  }

  @Test("init sumsFilesIntoTheirTarget")
  func test_init_sumsFilesIntoTheirTarget() throws {
    // GIVEN — two files in one target and one in another
    let llvmCoverage = try makeLLVMCoverage([
      ("/repo/Sources/Core/A.swift", 10, 20), ("/repo/Sources/Core/Nested/B.swift", 5, 5),
      ("/repo/Sources/Shell/C.swift", 1, 4),
    ])

    // WHEN
    let sut = LineCoverage(llvmCoverage: llvmCoverage, includeTestTargets: false)

    // THEN
    #expect(
      sut.targets == [
        LineCoverage.Target(name: "Core", coveredLines: 15, executableLines: 25),
        LineCoverage.Target(name: "Shell", coveredLines: 1, executableLines: 4),
      ]
    )
  }

  @Test("init dropsTestsAndDependencyCheckouts")
  func test_init_dropsTestsAndDependencyCheckouts() throws {
    // GIVEN — a source file next to a test file and a dependency checkout
    let llvmCoverage = try makeLLVMCoverage([
      ("/repo/Sources/Core/A.swift", 1, 2), ("/repo/Tests/CoreTests/ATests.swift", 9, 9),
      ("/repo/.build/checkouts/dep/Sources/Dep/D.swift", 7, 7),
    ])

    // WHEN
    let sut = LineCoverage(llvmCoverage: llvmCoverage, includeTestTargets: false)

    // THEN
    #expect(sut.targets.map(\.name) == ["Core"])
  }

  @Test("init namesTestTargetsWhenIncluded")
  func test_init_namesTestTargetsWhenIncluded() throws {
    // GIVEN
    let llvmCoverage = try makeLLVMCoverage([
      ("/repo/Sources/Core/A.swift", 1, 2), ("/repo/Tests/CoreTests/ATests.swift", 9, 9),
    ])

    // WHEN
    let sut = LineCoverage(llvmCoverage: llvmCoverage, includeTestTargets: true)

    // THEN
    #expect(sut.targets.map(\.name) == ["Core", "CoreTests"])
  }

  @Test("init groupsUnmatchedFilesUnderFallbackTarget")
  func test_init_groupsUnmatchedFilesUnderFallbackTarget() throws {
    // GIVEN — files outside any `Sources/<Target>` directory
    let llvmCoverage = try makeLLVMCoverage([("/repo/Plugins/P.swift", 1, 3), ("/repo/Sources/Loose.swift", 2, 2)])

    // WHEN
    let sut = LineCoverage(llvmCoverage: llvmCoverage, includeTestTargets: false)

    // THEN — nothing is dropped, so no executable line goes unreported
    #expect(sut.targets == [LineCoverage.Target(name: "other", coveredLines: 3, executableLines: 5)])
  }
}

extension LLVMCoverageLineCoverageTests {
  @Test("init dropsFilesDirectlyInTests")
  func test_init_dropsFilesDirectlyInTests() throws {
    // GIVEN — a test helper with no test target directory above it
    let llvmCoverage = try makeLLVMCoverage([
      ("/repo/Sources/Core/A.swift", 1, 2), ("/repo/Tests/LinuxMain.swift", 3, 3),
    ])

    // WHEN
    let sut = LineCoverage(llvmCoverage: llvmCoverage, includeTestTargets: false)

    // THEN — it is test code, not `other`
    #expect(sut.targets == [LineCoverage.Target(name: "Core", coveredLines: 1, executableLines: 2)])
  }

  @Test("init usesPackageLayoutNearestTheFile")
  func test_init_usesPackageLayoutNearestTheFile() throws {
    // GIVEN — a package that itself lives under a `Tests` directory, like the repo's fixtures
    let llvmCoverage = try makeLLVMCoverage([
      ("/repo/Tests/fixtures/Pkg/Sources/Core/A.swift", 1, 2),
      ("/repo/Tests/fixtures/Pkg/Tests/CoreTests/T.swift", 3, 3),
    ])

    // WHEN
    let sut = LineCoverage(llvmCoverage: llvmCoverage, includeTestTargets: false)

    // THEN
    #expect(sut.targets == [LineCoverage.Target(name: "Core", coveredLines: 1, executableLines: 2)])
  }
}
