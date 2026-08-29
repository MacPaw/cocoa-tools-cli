public import Foundation

/// The result of a `xccov diff` comparison between two xcresult bundles.
public struct XCResultCoverageDiff: Codable, Sendable {
  /// Targets present in `after` but not in `before`.
  public var addedTargets: [XCResultCoverage.Target]
  /// Target names present in `before` but not in `after`. Only `name` is provided by xccov.
  public var removedTargets: [RemovedTarget]
  /// Aggregate line-coverage delta across all matched targets.
  public var lineCoverageDelta: LineCoverageDelta
  /// Per-target deltas for targets that exist in both bundles.
  public var targetDeltas: [TargetDelta]

  /// Runs `xcrun xccov diff --json` and decodes the result.
  ///
  /// - Parameters:
  ///   - before: Path to the before `.xcresult` bundle.
  ///   - after: Path to the after `.xcresult` bundle.
  ///   - pathEquivalence: Optional source path remapping. Passed to xccov as
  ///     `--path-equivalence <from,to>` to correlate files that moved between runs.
  /// - Returns: Decoded `XCResultCoverageDiff`.
  /// - Throws: `Shell.Error` on xccov failure, or a decoding error on unexpected output.
  public static func diff(
    before: URL,
    after: URL,
    pathEquivalence: (from: String, to: String)? = nil,
  ) throws -> XCResultCoverageDiff {
    let data = try XCCovCLI().diffCoverage(before: before, after: after, pathEquivalence: pathEquivalence)
    return try JSONDecoder().decode(XCResultCoverageDiff.self, from: data)
  }
}

extension XCResultCoverageDiff {
  /// A target name from the before bundle that has no match in the after bundle.
  public struct RemovedTarget: Codable, Sendable {
    /// The target name.
    public var name: String
  }

  /// Line-coverage counts and percentage delta between two coverage snapshots.
  public struct LineCoverageDelta: Codable, Sendable {
    /// Change in the number of covered lines (`after − before`).
    public var coveredLinesDelta: Int
    /// Change in the number of executable lines (`after − before`).
    public var executableLinesDelta: Int
    /// Change in line-coverage percentage (`after − before`), in the range `[−1, 1]`.
    public var lineCoverageDelta: Double
  }
}
