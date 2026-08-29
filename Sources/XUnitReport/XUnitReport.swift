public import Foundation

/// Root of an xUnit XML report, containing one or more test suites.
public struct XUnitReport: Sendable {
  /// The test suites contained in this report.
  public let testSuites: [TestSuite]

  /// Loads and parses an xUnit XML report at the given URL.
  ///
  /// - Parameter url: The file URL of the xUnit XML report.
  /// - Returns: The parsed ``XUnitReport`` value.
  /// - Throws: An error if the file cannot be read or the XML is malformed.
  public static func load(from url: URL) throws -> XUnitReport {
    let data = try Data(contentsOf: url)
    return try XUnitSAXParser().parse(data: data)
  }
}
