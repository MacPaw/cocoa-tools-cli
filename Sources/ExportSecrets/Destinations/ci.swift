@_exported import CI
import ENV

extension ExportSecrets.Destinations {
  /// Export destination that writes secrets to a CI environment.
  public struct CI {
    /// Creates a new CI export destination.
    public init() {}
  }
}

extension ExportSecrets.Destinations.CI: ExportSecretsDestinationProtocol {
  /// Exports secrets to a CI environment.
  /// - Parameter secrets: Dictionary mapping environment variable names to their values.
  /// - Throws: Export errors if the operation fails.
  public func export(secrets: [String: String]) throws {
    let ci = CI()
    try ci.export(secrets: secrets)
  }
}

extension CI {
  /// Exports secrets to a CI environment.
  /// - Parameter secrets: Dictionary mapping environment variable names to their values.
  /// - Throws: Export errors if the operation fails.
  func export(secrets: [String: String]) throws {
    for (name, value) in secrets { try self.env.setSecret(name: name, value: value, isOutput: true) }
  }
}
