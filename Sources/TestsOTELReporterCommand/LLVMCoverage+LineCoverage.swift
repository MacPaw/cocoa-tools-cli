import LLVMCoverageParser
import TestsOTELReporter

extension LineCoverage {
  /// Target name used for files that do not live under a `Sources/<Target>` directory.
  static let fallbackTargetName: String = "other"

  /// Creates per-target line coverage from an LLVM coverage export.
  ///
  /// An LLVM export is per file and knows nothing about targets, so the target is the SwiftPM
  /// directory right after the `Sources/` nearest to the file. Files in dependency checkouts
  /// (`.build`, `checkouts`, `SourcePackages`) are dropped, as are files under `Tests/` unless test targets are included, in
  /// which case the directory right after `Tests/` names the target. Files that match neither
  /// layout are grouped under ``fallbackTargetName`` rather than dropped, so that no executable
  /// line goes unreported.
  ///
  /// - Parameters:
  ///   - llvmCoverage: The parsed LLVM coverage export.
  ///   - includeTestTargets: Whether files under `Tests/` count towards coverage.
  init(llvmCoverage: LLVMCoverage, includeTestTargets: Bool) {
    var targetNames: [String] = []
    var linesByTarget: [String: (covered: Int, executable: Int)] = [:]

    for file in llvmCoverage.data.flatMap(\.files) {
      guard let targetName = Self.targetName(forPath: file.filename, includeTestTargets: includeTestTargets) else {
        continue
      }

      if linesByTarget[targetName] == nil { targetNames.append(targetName) }
      let lines = file.summary.lines
      let current = linesByTarget[targetName] ?? (covered: 0, executable: 0)
      linesByTarget[targetName] = (current.covered + lines.covered, current.executable + lines.count)
    }

    self.init(
      targets: targetNames.map { name in
        let lines = linesByTarget[name] ?? (covered: 0, executable: 0)
        return Target(name: name, coveredLines: lines.covered, executableLines: lines.executable)
      }
    )
  }

  /// Derives the target a source file belongs to.
  ///
  /// - Parameters:
  ///   - path: Path of the source file.
  ///   - includeTestTargets: Whether files under `Tests/` are attributed to a target.
  /// - Returns: The target name, or `nil` when the file is excluded from coverage.
  static func targetName(forPath path: String, includeTestTargets: Bool) -> String? {
    let components: [Substring] = path.split(separator: "/")
    // The last component is the file itself, so only the directories before it can name a target.
    let directories: ArraySlice<Substring> = components.dropLast()

    // `.build` and `checkouts` hold SwiftPM dependencies, `SourcePackages` Xcode's.
    guard !directories.contains(where: { [".build", "checkouts", "SourcePackages"].contains($0) }) else {
      return .none
    }

    // The root nearest to the file wins, so a repository that itself sits under a `Tests` or
    // `Sources` directory does not shadow the package layout inside it.
    guard let rootIndex = directories.lastIndex(where: { ["Sources", "Tests"].contains($0) }) else {
      return fallbackTargetName
    }
    // Checked before the target directory, so a file directly in `Tests/` (`LinuxMain.swift`) is
    // dropped like the rest of the test code.
    guard includeTestTargets || directories[rootIndex] != "Tests" else { return .none }

    let targetIndex = directories.index(after: rootIndex)
    guard targetIndex < directories.endIndex else { return fallbackTargetName }

    return String(directories[targetIndex])
  }
}
