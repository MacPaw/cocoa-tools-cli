extension XCResultCoverageDiff.TargetDelta {
  /// Coverage changes for a single source file matched between the before and after bundles.
  public struct FileDelta: Codable, Sendable {
    /// Absolute path to the source file as recorded in the after xcresult.
    public var documentLocation: String
    /// Aggregate line-coverage delta for this file.
    public var lineCoverageDelta: XCResultCoverageDiff.LineCoverageDelta
    /// Functions present in `after` but not in `before` (full function data).
    public var addedFunctions: [XCResultCoverage.Target.File.Function]
    /// Function names present in `before` but not in `after`.
    ///
    /// Only `name` is provided.
    public var removedFunctions: [RemovedFunction]
    /// Per-function deltas for functions matched between before and after.
    public var functionDeltas: [FunctionDelta]
  }
}

extension XCResultCoverageDiff.TargetDelta.FileDelta {
  /// A function name from the before bundle that has no match in the after bundle.
  public struct RemovedFunction: Codable, Sendable {
    /// The function name as reported by xccov (e.g. `"MyType.someMethod()"`).
    public var name: String
  }
}
