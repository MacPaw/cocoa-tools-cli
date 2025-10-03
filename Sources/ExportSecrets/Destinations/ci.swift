@_exported import CI
import ENV

extension ExportSecrets.Destinations {
  /// Export destination that writes secrets to a CI environment.
  public struct CI {
    /// A `Bool` idicating if secrets must be exporteed to be usable in the dependent jobs.
    var isOutput: Bool = true

    /// Creates a new CI export destination.
    /// - Parameter isOutput: A `Bool` idicating if secrets must be exporteed to be usable in the dependent jobs.
    public init(isOutput: Bool) {}
  }
}

extension ExportSecrets.Destinations.CI: ExportSecretsDestinationProtocol {
  /// Exports secrets to a CI environment.
  /// - Parameter secrets: Dictionary mapping environment variable names to their values.
  /// - Throws: Export errors if the operation fails.
  public func export(secrets: [String: String]) throws {
    let ci = CI()
    try ci.export(secrets: secrets, isOutput: isOutput)
  }
}

extension CI {
  /// Exports secrets to a CI environment.
  /// - Parameters:
  ///   - secrets: Dictionary mapping environment variable names to their values.
  ///   - isOutput: A `Bool` idicating if secrets must be exporteed to be usable in the dependent jobs.
  /// - Throws: Export errors if the operation fails.
  func export(secrets: [String: String], isOutput: Bool) throws {
    for (name, value) in secrets { try self.env.setSecret(name: name, value: value, isOutput: isOutput) }
  }
}
