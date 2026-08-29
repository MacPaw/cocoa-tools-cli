extension XCResultCoverage {
  /// Coverage data for a single build target (framework, app, etc.).
  public struct Target: Codable, Sendable {
    /// The target's display name.
    public var name: String
    /// File-system path to the built product.
    public var buildProductPath: String
    /// Total covered lines in this target.
    public var coveredLines: Int
    /// Total executable lines in this target.
    public var executableLines: Int
    /// Ratio of covered to executable lines (0.0–1.0).
    public var lineCoverage: Double
    /// Per-source-file coverage data.
    public var files: [File]
  }
}
