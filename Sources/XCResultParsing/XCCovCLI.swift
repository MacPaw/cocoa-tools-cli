public import Foundation
import Shell

/// A wrapper around `xcrun xccov` for querying coverage data from xcresult bundles.
public struct XCCovCLI: Sendable {
  private let xcrunURL: URL

  /// Creates a new instance using the system `xcrun` at `/usr/bin/xcrun`.
  public init() {
    xcrunURL = URL(fileURLWithPath: "/usr/bin/xcrun")
  }

  /// Returns the raw JSON produced by `xcrun xccov view --report --json`.
  ///
  /// Decode the result with `JSONDecoder().decode(CoverageReport.self, from:)`.
  ///
  /// - Parameter xcresultPath: Path to the `.xcresult` bundle.
  /// - Returns: Raw JSON data from stdout.
  /// - Throws: `Shell.Error` if the process exits with a non-zero status.
  public func viewCoverageReport(xcresultPath: URL) throws -> Data {
    try Shell.run(
      executableURL: xcrunURL,
      arguments: [
        "xccov", "view", "--report", "--json",
        xcresultPath.path(percentEncoded: false),
      ],
    )
  }
}
