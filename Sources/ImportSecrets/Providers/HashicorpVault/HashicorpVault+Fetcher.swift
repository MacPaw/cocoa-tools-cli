import HashiCorpVaultReader
import Shell

extension ImportSecrets.Providers.HashiCorpVault {
  /// Fetcher implementation for retrieving secrets from HashiCorp Vault.
  ///
  /// This handles the actual communication with the HashiCorp Vault API and manages
  /// batching of requests for efficiency.
  public struct Fetcher {
    var reader: any HashiCorpVaultReaderProtocol
    public init(reader: any HashiCorpVaultReaderProtocol = HashiCorpVaultReader()) { self.reader = reader }
  }
}

private typealias Fetcher = ImportSecrets.Providers.HashiCorpVault.Fetcher

extension Fetcher: Sendable {}

extension Fetcher: SecretFetcherProtocol {
  /// Source type for HashiCorp Vault fetcher.
  public typealias Source = ImportSecrets.Providers.HashiCorpVault.Source

  /// Fetches secrets from HashiCorp Vault using the configured reader.
  ///
  /// - Parameters:
  ///   - secrets: Dictionary mapping secret names to their HashiCorp Vault source configurations.
  ///   - sourceConfiguration: Configuration containing default account and vault settings.
  /// - Returns: Result containing successfully fetched secrets and any errors encountered.
  /// - Throws: Error if the HashiCorp Vault cannot be initialized, configured or throws error during fetching.
  public func fetch(
    secrets: [String: ImportSecrets.Providers.HashiCorpVault.Source],
    sourceConfiguration: ImportSecrets.Providers.HashiCorpVault.Source.Configuration?,
  ) async throws -> SecretsFetchResult {
    guard !secrets.isEmpty else { return .init() }
    guard let sourceConfiguration else { throw FetchError.configurationNotSet }

    let result = try await reader.fetch(secrets: secrets, configuration: sourceConfiguration)

    return SecretsFetchResult(fetchedSecrets: result, errors: [:])
  }

  enum FetchError: Error {
    case failedToFetch(secret: String, labelMissing: String)
    case configurationNotSet
  }
}
