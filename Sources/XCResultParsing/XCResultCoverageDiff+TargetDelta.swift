extension XCResultCoverageDiff {
  /// Coverage changes for a single target that appears in both the before and after bundles.
  public struct TargetDelta: Codable, Sendable {
    /// The target name.
    public var name: String
    /// Aggregate line-coverage delta for this target.
    public var lineCoverageDelta: LineCoverageDelta
    /// Files present in `after` but not in `before` (full file data).
    public var addedFiles: [XCResultCoverage.Target.File]
    /// File paths present in `before` but not in `after`. Only `documentLocation` is provided.
    public var removedFiles: [RemovedFile]
    /// Per-file deltas for files matched between before and after.
    public var fileDeltas: [FileDelta]
  }
}

extension XCResultCoverageDiff.TargetDelta {
  /// A source file path from the before bundle that has no match in the after bundle.
  public struct RemovedFile: Codable, Sendable {
    /// Absolute path to the source file as recorded in the before xcresult.
    public var documentLocation: String
  }
}
