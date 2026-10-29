import Foundation
import Shell

/// A wrapper around `xcrun xcresulttool` for extracting test-results data from xcresult bundles.
struct XCResultToolCLI: Sendable {
  private let xcrunURL: URL

  /// Creates a new instance using the system `xcrun` at `/usr/bin/xcrun`.
  init() {
    xcrunURL = URL(fileURLWithPath: "/usr/bin/xcrun")
  }

  /// Returns the raw JSON produced by `xcresulttool get test-results tests`.
  ///
  /// - Parameter xcresultPath: Path to the `.xcresult` bundle.
  /// - Returns: Raw JSON data from stdout.
  /// - Throws: `Shell.Error` if the process exits with a non-zero status.
  func getTestResultsTests(xcresultPath: URL) throws -> Data {
    try Shell.run(
      executableURL: xcrunURL,
      arguments: [
        "xcresulttool", "get", "test-results", "tests",
        "--path", xcresultPath.path(percentEncoded: false),
      ],
    )
  }
}
