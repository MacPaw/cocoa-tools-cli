extension LLVMCoverage {
  /// Coverage data for a single source file.
  public struct File: Sendable, Codable {
    /// Path to the source file.
    public let filename: String
    /// Coverage summary for this file.
    public let summary: Summary

    /// Initializes a file coverage entry.
    ///
    /// - Parameters:
    ///   - filename: Path to the source file.
    ///   - summary: Coverage summary for this file.
    public init(filename: String, summary: Summary) {
      self.filename = filename
      self.summary = summary
    }
  }
}
