import Shell

/// Protocol for exporting secrets to mise configuration files.
/// Mise is a development environment manager that can load environment variables from configuration files.
public protocol SecretsDestinationMiseProtocol: Sendable {
  /// Exports secrets to a mise configuration file.
  /// - Parameters:
  ///   - secrets: Dictionary mapping environment variable names to their values.
  ///   - file: Optional path to the mise configuration file. If nil, uses the default.
  /// - Throws: Export errors if the operation fails.
  func export(secrets: [String: String], file: String?) throws
}

private typealias Mise = ExportSecrets.Destinations.Mise

extension ExportSecrets.Destinations {
  /// Export destination that writes secrets to mise configuration files.
  /// This allows secrets to be loaded as environment variables by the mise tool.
  public struct Mise {
    /// The path to the mise configuration file to write to.
    let file: String?
    /// The mise CLI implementation to use for writing the configuration.
    let miseCLI: SecretsDestinationMiseProtocol

    /// Creates a new mise export destination.
    /// - Parameters:
    ///   - file: Optional path to the mise configuration file. Defaults to "mise.local.toml".
    ///   - miseCLI: The mise CLI implementation to use.
    public init(file: String? = "mise.local.toml", miseCLI: SecretsDestinationMiseProtocol) {
      self.file = file
      self.miseCLI = miseCLI
    }
  }
}

extension Mise: ExportSecretsDestinationProtocol {
  public init(file: String? = .none) throws {
    let miseCLI: SecretsDestinationMiseProtocol = try Shell.Mise()
    self.init(file: file, miseCLI: miseCLI)
  }

  public func export(secrets: [String: String]) throws { try miseCLI.export(secrets: secrets, file: file) }
}

extension Mise: Sendable {}

extension Shell.Mise: SecretsDestinationMiseProtocol {
  public func export(secrets: [String: String], file: String?) throws {
    let arguments: [[String]] = [["set"], file.map { ["--file", $0] }, secrets.toEnv(wrappingValues: false)]
      .compactMap(\.self)
    try run(arguments: arguments.flatMap(\.self))
  }
}
