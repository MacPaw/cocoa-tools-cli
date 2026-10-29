public import Foundation

/// Decoded result of `xcrun xccov view --report --json`, representing the full project coverage report.
public struct XCResultCoverage: Codable, Sendable {
  /// Total covered lines across all targets.
  public var coveredLines: Int
  /// Total executable lines across all targets.
  public var executableLines: Int
  /// Ratio of covered to executable lines (0.0–1.0).
  public var lineCoverage: Double
  /// Per-target coverage breakdown.
  public var targets: [Target]

  /// Loads coverage from an xcresult bundle using `xcrun xccov view --report --json`.
  ///
  /// - Parameter xcresultPath: Path to the `.xcresult` bundle.
  /// - Returns: The decoded ``XCResultCoverage``.
  /// - Throws: `Shell.Error` or a JSON decoding error.
  public static func load(from xcresultPath: URL) throws -> XCResultCoverage {
    let data = try XCCovCLI().viewCoverageReport(xcresultPath: xcresultPath)
    return try JSONDecoder().decode(XCResultCoverage.self, from: data)
  }
}
