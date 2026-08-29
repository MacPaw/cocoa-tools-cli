extension LLVMCoverage {
  /// Coverage count and percentage for a single metric.
  public struct Stat: Sendable, Codable {
    /// Total number of items.
    public let count: Int
    /// Number of covered items.
    public let covered: Int
    /// Number of uncovered items.
    ///
    /// Present for regions, branches, and mcdc; `nil` for lines, functions, and instantiations.
    public let notCovered: Int?
    /// Percentage of items covered (0–100).
    public let percent: Double

    private enum CodingKeys: String, CodingKey {
      case count, covered, percent
      case notCovered = "notcovered"
    }
  }
}
