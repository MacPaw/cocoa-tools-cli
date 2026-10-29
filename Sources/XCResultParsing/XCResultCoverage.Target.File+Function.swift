extension XCResultCoverage.Target.File {
  /// Coverage data for a single function or method.
  public struct Function: Codable, Sendable {
    /// The Swift function signature.
    public var name: String
    /// 1-based source line number where the function is declared.
    public var lineNumber: Int
    /// Number of times the function was executed during the test run.
    public var executionCount: Int
    /// Covered lines within this function.
    public var coveredLines: Int
    /// Executable lines within this function.
    public var executableLines: Int
    /// Ratio of covered to executable lines (0.0–1.0).
    public var lineCoverage: Double
  }
}
