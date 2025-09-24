import HashiCorpVaultReader
import SecretsInterface
import Shell

extension ImportSecrets.Providers.HashiCorpVault {
  /// Fetcher implementation for retrieving secrets from HashiCorp Vault.
  ///
  /// This handles the actual communication with the HashiCorp Vault API and manages
  /// batching of requests for efficiency.
  public struct Fetcher {
    /// The reader to use for fetching secrets from HashiCorp Vault.
    var reader: any HashiCorpVaultReaderProtocol

    /// Initialize a new HashiCorp Vault fetcher.
    /// - Parameter reader: The reader to use for fetching secrets from HashiCorp Vault. Defaults to a new reader.
    public init(reader: any HashiCorpVaultReaderProtocol = HashiCorpVaultReader()) { self.reader = reader }
  }
}

private typealias Fetcher = ImportSecrets.Providers.HashiCorpVault.Fetcher

extension Fetcher: Sendable {}

extension Fetcher: SecretFetcherProtocol {
  /// Source type for HashiCorp Vault fetcher.
  public typealias Source = ImportSecrets.Providers.HashiCorpVault.Source

  /// Initializes fetcher before fetching secrets with a given `configuration`.
  ///
  /// - Parameter configuration: A Secret Configuration to init this fetcher with.
  ///
  /// - Throws: An error if initialization failed.
  public mutating func initialize(configuration: HashiCorpVaultReader.Configuration) async throws {
    try await reader.initialize(configuration: configuration)
  }

  /// Fetches a single source item.
  /// - Parameters:
  ///   - item: A unique source item.
  ///   - keys: A set of keys to fetch. If set is empty it will fetch all keys from a given `item`.
  ///   - configuration: A source configuration to use when fetching secrets.
  ///
  /// - Note: There is no need to filter fetched secrets by passed keys in the implementation.
  ///
  /// - Returns: A map where secret name is a key, and secret value is a value.
  /// - Throws: If error occurred during item fetch.
  public func fetchItem(
    _ item: HashiCorpVaultReader.Element.Item,
    keys: Set<String>,
    configuration: HashiCorpVaultReader.Configuration
  ) async throws -> [String: String] { try await reader.fetchItem(item, keys: keys, configuration: configuration) }

  enum FetchError: Error {
    case failedToFetch(secret: String, labelMissing: String)
    case configurationNotSet
  }
}
