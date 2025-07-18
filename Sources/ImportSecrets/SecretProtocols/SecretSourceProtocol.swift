/// Protocol that describes a secret source type (e.g., `1Password`, `Vault`).
/// A secret source represents a specific location or reference to a secret within a provider,
/// such as a specific item in 1Password or a path in HashiCorp Vault.
public protocol SecretSourceProtocol: Sendable {
  /// The configuration type associated with this secret source.
  /// This defines the parameters needed to configure the source provider.
  associatedtype Configuration: SecretConfigurationProtocol

  /// Validates the secret source configuration.
  /// - Throws: An error if the source configuration is invalid or incomplete.
  mutating func validate(with configuration: Configuration?) throws
}

extension SecretSourceProtocol {
  mutating func validate(with sourceConfigurations: ImportSecrets.SourceConfigurations) throws {
    let configuration: Configuration? = try sourceConfigurations.getConfiguration(for: Self.configurationKey)

    try validate(with: configuration)
  }

  public mutating func validate(with configuration: Configuration?) throws {}
}

extension SecretSourceProtocol {
  /// The configuration key used in YAML to identify this secret source.
  static var configurationKey: String { Configuration.configurationKey }
}
