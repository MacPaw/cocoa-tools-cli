extension LLVMCoverageDiff {
  /// Coverage delta for a single source file matched between `before` and `after` exports.
  public struct FileDelta: Codable, Sendable {
    /// Normalized filename (path-equivalence prefix stripped).
    public var filename: String
    /// Per-metric coverage delta for this file.
    public var summaryDelta: SummaryDelta
  }
}
