import HashicorpVaultReader

extension ImportSecrets.Providers.HashicorpVault { public typealias Source = HashicorpVaultReader.Element }

private typealias Source = ImportSecrets.Providers.HashicorpVault.Source

extension Source: SecretSourceProtocol {
  /// Configuration key used to identify this provider in YAML.
  public static let configurationKey: String = "vault"

  /// Validates and applies default configuration values.
  ///
  /// - Parameter configuration: Optional configuration containing default values for account and vault.
  /// - Throws: Validation errors if the source configuration is invalid.
  public mutating func validate(with configuration: Configuration?) throws {
    /// TODO
  }
}
