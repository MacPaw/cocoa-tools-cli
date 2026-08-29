public import Foundation

/// Root of an LLVM coverage JSON export (`llvm.coverage.json.export`).
public struct LLVMCoverage: Sendable, Decodable {
  /// Coverage format version string (e.g. `"3.0.1"`).
  public let version: String
  /// One coverage data entry per instrumented binary. In practice always a single element.
  public let data: [Coverage]

  /// Loads and parses an LLVM coverage JSON export at the given URL.
  ///
  /// - Parameter url: The file URL of the LLVM coverage JSON export.
  /// - Returns: The parsed ``LLVMCoverage`` value.
  /// - Throws: An error if the file cannot be read or the JSON is malformed.
  public static func load(from url: URL) throws -> LLVMCoverage {
    let fileData = try Data(contentsOf: url)
    return try JSONDecoder().decode(LLVMCoverage.self, from: fileData)
  }
}
