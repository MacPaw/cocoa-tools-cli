extension XCResultCoverageDiff.TargetDelta.FileDelta {
  /// Coverage changes for a single function matched between the before and after bundles.
  public struct FunctionDelta: Codable, Sendable {
    /// The function name as reported by xccov (for example `"MyType.someMethod()"`).
    public var name: String
    /// Line-coverage delta for this function.
    public var lineCoverageDelta: XCResultCoverageDiff.LineCoverageDelta
  }
}
