extension LLVMCoverage {
  /// Coverage statistics for lines, functions, and branches for a file or binary.
  public struct Summary: Sendable, Decodable {
    /// Line coverage.
    public let lines: Stat
    /// Function coverage.
    public let functions: Stat
    /// Branch coverage.
    public let branches: Stat
  }
}
