import Foundation

/// Protocol that abstracts file system operations for testability.
/// This allows the ImportSecrets module to work with different file system implementations.
public protocol FileManagerProtocol {
  /// Creates a file at the specified path.
  /// - Parameters:
  ///   - path: The file path where the file should be created.
  ///   - data: The data to write to the file, or nil for an empty file.
  ///   - attr: File attributes to set on the created file.
  /// - Returns: true if the file was created successfully, false otherwise.
  func createFile(atPath path: String, contents data: Data?, attributes attr: [FileAttributeKey: Any]?) -> Bool
}

extension FileManager: FileManagerProtocol {}
