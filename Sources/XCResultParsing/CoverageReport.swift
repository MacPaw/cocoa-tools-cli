public import Foundation
import Shell

/// Decoded result of `xcrun xccov view --report --json`, representing the full project coverage report.
public struct CoverageReport: Codable, Sendable {
  /// Total covered lines across all targets.
  public var coveredLines: Int
  /// Total executable lines across all targets.
  public var executableLines: Int
  /// Ratio of covered to executable lines (0.0–1.0).
  public var lineCoverage: Double
  /// Per-target coverage breakdown.
  public var targets: [CoverageTarget]

  /// Loads coverage from an xcresult bundle using `xcrun xccov view --report --json`.
  ///
  /// - Parameter xcresultPath: Path to the `.xcresult` bundle.
  /// - Returns: The decoded `CoverageReport`.
  /// - Throws: `Shell.Error` or a JSON decoding error.
  public static func load(from xcresultPath: URL) throws -> CoverageReport {
    let data = try XCCovCLI().viewCoverageReport(xcresultPath: xcresultPath)
    return try JSONDecoder().decode(CoverageReport.self, from: data)
  }
}

extension CoverageReport {
  /// Coverage data for a single build target (framework, app, etc.).
  public struct CoverageTarget: Codable, Sendable {
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
    public var files: [CoverageFile]
  }

  /// Coverage data for a single source file within a target.
  public struct CoverageFile: Codable, Sendable {
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
    public var functions: [CoverageFunction]
  }

  /// Coverage data for a single function or method.
  public struct CoverageFunction: Codable, Sendable {
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
