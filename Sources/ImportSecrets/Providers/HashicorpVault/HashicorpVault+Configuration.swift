import HashicorpVaultReader

extension ImportSecrets.Providers.HashicorpVault.Source {
  public typealias Configuration = HashicorpVaultReader.Configuration
}

private typealias Configuration = ImportSecrets.Providers.HashicorpVault.Source.Configuration

extension Configuration: SecretConfigurationProtocol {
  /// Configuration key used to identify this provider in YAML.
  public static let configurationKey: String = "vault"
}
