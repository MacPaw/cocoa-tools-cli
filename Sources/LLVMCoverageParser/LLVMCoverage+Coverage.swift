extension LLVMCoverage {
  /// Coverage data for a single instrumented binary.
  public struct Coverage: Sendable, Decodable {
    /// Per-file coverage entries, one per instrumented source file.
    public let files: [File]
    /// Aggregate coverage totals across all files.
    public let totals: Summary
  }
}
