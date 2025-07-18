import Foundation

private typealias DotEnv = ExportSecrets.Destinations.DotEnv

extension ExportSecrets.Destinations {
  /// Export destination that writes secrets to .env files.
  ///
  /// This format is commonly used by many applications and development tools
  /// to load environment variables from files.
  public struct DotEnv {
    /// The path to the .env file to write to.
    let file: String?
    /// The file manager implementation to use for writing the file.
    let fileManager: any FileManagerProtocol

    /// Creates a new .env export destination.
    /// - Parameters:
    ///   - file: Optional path to the .env file. Defaults to ".env.local".
    ///   - fileManager: The file manager implementation to use. Defaults to the system FileManager.
    public init(file: String? = ".env.local", fileManager: any FileManagerProtocol = FileManager.default) {
      self.file = file
      self.fileManager = fileManager
    }
  }
}

extension DotEnv: ExportSecretsDestinationProtocol {
  /// Exports secrets to a .env file.
  ///
  /// - Parameter secrets: Dictionary mapping environment variable names to their values.
  /// - Throws: ExportSecrets.Error.fileCreationFailed if the file cannot be written.
  public func export(secrets: [String: String]) throws {
    let path: String = file ?? ".env"
    let fileContents: String = secrets.toEnv().joined(separator: "\n")
    guard fileManager.createFile(atPath: path, contents: fileContents.data(using: .utf8), attributes: nil) else {
      throw ExportSecrets.Error.fileCreationFailed(path)
    }
  }
}

extension DotEnv: @unchecked Sendable {}
