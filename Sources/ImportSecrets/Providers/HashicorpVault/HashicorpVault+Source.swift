import HashiCorpVaultReader

extension ImportSecrets.Providers.HashiCorpVault { public typealias Source = HashiCorpVaultReader.Element }

private typealias Source = ImportSecrets.Providers.HashiCorpVault.Source

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
