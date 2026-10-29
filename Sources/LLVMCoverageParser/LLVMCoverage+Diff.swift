/// A diff between two LLVM coverage exports, computed in Swift without any external tool.
public struct LLVMCoverageDiff: Codable, Sendable {
  /// Source files present in `after` but not in `before`.
  ///
  /// Filenames are normalized when path equivalence is provided.
  public var addedFiles: [LLVMCoverage.File]
  /// Source files present in `before` but not in `after`.
  ///
  /// Only the normalized filename is retained.
  public var removedFiles: [RemovedFile]
  /// Aggregate coverage delta derived from the `totals` of each export.
  public var totalsDelta: SummaryDelta
  /// Per-file coverage deltas for source files matched between `before` and `after`.
  public var fileDeltas: [FileDelta]

  /// Computes the diff between two ``LLVMCoverage`` exports.
  ///
  /// - Parameters:
  ///   - before: The coverage snapshot taken before the change.
  ///   - after: The coverage snapshot taken after the change.
  ///   - pathEquivalence: Optional path-prefix pair stripped before matching filenames.
  ///     `before` is stripped from filenames in the `before` export; `after` from the `after` export.
  ///     Derive these values from the fixture's first filename by splitting on `"/Sources/"`.
  /// - Returns: An ``LLVMCoverageDiff`` with added, removed, and changed file entries.
  public static func diff(
    before: LLVMCoverage,
    after: LLVMCoverage,
    pathEquivalence: (before: String, after: String)? = nil,
  ) -> LLVMCoverageDiff {
    // An export holds one entry per binary; all of them count, as in the line coverage report.
    let beforeFiles = before.data.flatMap(\.files)
    let afterFiles = after.data.flatMap(\.files)

    let beforePrefix = pathEquivalence?.before ?? ""
    let afterPrefix = pathEquivalence?.after ?? ""

    let beforeMap = Dictionary(
      beforeFiles.map { (normalize($0.filename, prefix: beforePrefix), $0) },
      uniquingKeysWith: { first, _ in first },
    )
    let afterMap = Dictionary(
      afterFiles.map { (normalize($0.filename, prefix: afterPrefix), $0) },
      uniquingKeysWith: { first, _ in first },
    )

    let addedFiles =
      afterFiles
      .filter { beforeMap[normalize($0.filename, prefix: afterPrefix)] == nil }
      .map { LLVMCoverage.File(filename: normalize($0.filename, prefix: afterPrefix), summary: $0.summary) }

    let removedFiles = beforeFiles.compactMap { file -> RemovedFile? in
      let key = normalize(file.filename, prefix: beforePrefix)
      return afterMap[key] == nil ? RemovedFile(filename: key) : nil
    }

    let fileDeltas = afterFiles.compactMap { afterFile -> FileDelta? in
      let key = normalize(afterFile.filename, prefix: afterPrefix)
      guard let beforeFile = beforeMap[key] else { return nil }
      return FileDelta(
        filename: key,
        summaryDelta: SummaryDelta(before: beforeFile.summary, after: afterFile.summary),
      )
    }

    let beforeTotals = LLVMCoverage.Summary.total(of: before)
    let afterTotals = LLVMCoverage.Summary.total(of: after)

    return LLVMCoverageDiff(
      addedFiles: addedFiles,
      removedFiles: removedFiles,
      totalsDelta: SummaryDelta(before: beforeTotals, after: afterTotals),
      fileDeltas: fileDeltas,
    )
  }
}

extension LLVMCoverageDiff {
  /// A source file path from the `before` export that has no match in the `after` export.
  public struct RemovedFile: Codable, Sendable {
    /// Normalized filename (path-equivalence prefix stripped).
    public var filename: String
  }

  /// Coverage delta for a single metric across lines, functions, and branches.
  public struct SummaryDelta: Codable, Sendable {
    /// Line coverage delta.
    public var lines: StatDelta
    /// Function coverage delta.
    public var functions: StatDelta
    /// Branch coverage delta.
    public var branches: StatDelta
  }

  /// Change in count, covered items, and coverage percentage for a single metric.
  public struct StatDelta: Codable, Sendable {
    /// Change in total item count (`after − before`).
    public var countDelta: Int
    /// Change in covered item count (`after − before`).
    public var coveredDelta: Int
    /// Change in coverage percentage (`after − before`).
    public var percentDelta: Double
  }
}

// MARK: - Private helpers

private func normalize(_ filename: String, prefix: String) -> String {
  guard !prefix.isEmpty, filename.hasPrefix(prefix) else { return filename }
  return String(filename.dropFirst(prefix.count))
}

extension LLVMCoverage.Summary {
  fileprivate static var zero: LLVMCoverage.Summary {
    LLVMCoverage.Summary(
      lines: LLVMCoverage.Stat(count: 0, covered: 0, notCovered: nil, percent: 0),
      functions: LLVMCoverage.Stat(count: 0, covered: 0, notCovered: nil, percent: 0),
      branches: LLVMCoverage.Stat(count: 0, covered: 0, notCovered: 0, percent: 0),
    )
  }

  /// Sums the totals of every entry in an export.
  ///
  /// A single entry's totals are returned as reported, keeping LLVM's own percentages.
  ///
  /// - Parameter coverage: The coverage export.
  /// - Returns: The combined totals, or ``zero`` for an export with no entries.
  fileprivate static func total(of coverage: LLVMCoverage) -> LLVMCoverage.Summary {
    guard coverage.data.count > 1 else { return coverage.data.first?.totals ?? .zero }

    return coverage.data.map(\.totals)
      .reduce(.zero) { sum, totals in
        LLVMCoverage.Summary(
          lines: sum.lines.adding(totals.lines),
          functions: sum.functions.adding(totals.functions),
          branches: sum.branches.adding(totals.branches),
        )
      }
  }
}

extension LLVMCoverage.Stat {
  /// Adds another stat's counts to this one and recomputes the percentage.
  ///
  /// - Parameter other: The stat to add.
  /// - Returns: The combined stat.
  fileprivate func adding(_ other: LLVMCoverage.Stat) -> LLVMCoverage.Stat {
    let count = count + other.count
    let covered = covered + other.covered
    return LLVMCoverage.Stat(
      count: count,
      covered: covered,
      notCovered: notCovered.flatMap { lhs in other.notCovered.map { lhs + $0 } },
      percent: count == 0 ? 0 : Double(covered) / Double(count) * 100,
    )
  }
}

extension LLVMCoverageDiff.SummaryDelta {
  fileprivate init(before: LLVMCoverage.Summary, after: LLVMCoverage.Summary) {
    self.init(
      lines: LLVMCoverageDiff.StatDelta(before: before.lines, after: after.lines),
      functions: LLVMCoverageDiff.StatDelta(before: before.functions, after: after.functions),
      branches: LLVMCoverageDiff.StatDelta(before: before.branches, after: after.branches),
    )
  }
}

extension LLVMCoverageDiff.StatDelta {
  fileprivate init(before: LLVMCoverage.Stat, after: LLVMCoverage.Stat) {
    self.init(
      countDelta: after.count - before.count,
      coveredDelta: after.covered - before.covered,
      percentDelta: after.percent - before.percent,
    )
  }
}
