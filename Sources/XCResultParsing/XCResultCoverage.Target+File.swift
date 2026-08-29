extension XCResultCoverage.Target {
  /// Coverage data for a single source file within a target.
  public struct File: Codable, Sendable {
    /// The file name (basename).
    public var name: String
    /// Absolute path to the source file.
    public var path: String
    /// Total covered lines in this file.
    public var coveredLines: Int
    /// Total executable lines in this file.
    public var executableLines: Int
    /// Ratio of covered to executable lines (0.0–1.0).
    public var lineCoverage: Double
    /// Per-function coverage records.
    public var functions: [Function]
  }
}
