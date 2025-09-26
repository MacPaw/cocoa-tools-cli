import HashiCorpVaultReader
import SecretsInterface

extension ImportSecrets.Providers.HashiCorpVault.Source {
  /// HashiCorp Vault source configuration.
  public typealias Configuration = HashiCorpVaultReader.Configuration
}

private typealias Configuration = ImportSecrets.Providers.HashiCorpVault.Source.Configuration

extension Configuration: SecretConfigurationProtocol {
  /// Configuration key used to identify this provider in YAML.
  public static let configurationKey: String = "vault"
}
