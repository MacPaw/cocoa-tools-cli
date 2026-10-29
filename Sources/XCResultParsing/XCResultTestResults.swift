public import Foundation

/// Decoded result of `xcresulttool get test-results tests`.
public struct XCResultTestResults: Codable, Sendable {
  /// The physical devices or simulators on which the tests ran.
  public var devices: [Device]
  /// The root-level test grouping nodes (suites, test cases, etc.).
  public var testNodes: [TestNode]

  /// Loads test results from an xcresult bundle using `xcresulttool get test-results tests`.
  ///
  /// - Parameter xcresultPath: Path to the `.xcresult` bundle.
  /// - Returns: The decoded ``XCResultTestResults``.
  /// - Throws: `Shell.Error` or a JSON decoding error.
  public static func load(from xcresultPath: URL) throws -> XCResultTestResults {
    let data = try XCResultToolCLI().getTestResultsTests(xcresultPath: xcresultPath)
    return try JSONDecoder().decode(XCResultTestResults.self, from: data)
  }
}
