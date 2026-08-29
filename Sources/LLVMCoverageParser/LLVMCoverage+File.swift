extension LLVMCoverage {
  /// Coverage data for a single source file.
  public struct File: Sendable, Decodable {
    /// Absolute path to the source file.
    public let filename: String
    /// Coverage summary for this file.
    public let summary: Summary
  }
}
