import HashiCorpVaultReader
import SecretsInterface

extension ImportSecrets.Providers {
  /// HashiCorp Vault secret provider implementation.
  ///
  /// This provider integrates with the HashiCorp API to fetch secrets from KeyValue and AWS engines.
  public struct HashiCorpVault {
    /// The fetcher implementation used to retrieve secrets from HashiCorp Vault.
    public let fetcher: Fetcher

    /// Creates a new HashiCorp Vault provider.
    /// - Parameter fetcher: The fetcher implementation to use. Defaults to a new Fetcher instance.
    public init(fetcher: Fetcher = .init(reader: HashiCorpVaultReader())) { self.fetcher = fetcher }
  }
}

extension ImportSecrets.Providers.HashiCorpVault: SecretProviderProtocol {}
