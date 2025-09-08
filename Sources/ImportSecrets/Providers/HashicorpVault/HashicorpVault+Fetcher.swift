import HashicorpVaultReader
import Shell

extension ImportSecrets.Providers.HashicorpVault {
  /// Fetcher implementation for retrieving secrets from 1Password.
  ///
  /// This handles the actual communication with the 1Password CLI and manages
  /// batching of requests for efficiency.
  public struct Fetcher {
    var reader: any HashicorpVaultReaderProtocol
    public init(reader: any HashicorpVaultReaderProtocol = HashicorpVaultReader()) { self.reader = reader }
  }
}

private typealias Fetcher = ImportSecrets.Providers.HashicorpVault.Fetcher

extension Fetcher: Sendable {}

extension Fetcher: SecretFetcherProtocol {
  /// Source type for 1Password fetcher.
  public typealias Source = ImportSecrets.Providers.HashicorpVault.Source

  /// Fetches secrets from 1Password using the configured CLI.
  ///
  /// - Parameters:
  ///   - secrets: Dictionary mapping secret names to their 1Password source configurations.
  ///   - sourceConfiguration: Optional configuration containing default account and vault settings.
  /// - Returns: Result containing successfully fetched secrets and any errors encountered.
  /// - Throws: Shell.Error if the 1Password CLI cannot be initialized or configured.
  public func fetch(
    secrets: [String: ImportSecrets.Providers.HashicorpVault.Source],
    sourceConfiguration: ImportSecrets.Providers.HashicorpVault.Source.Configuration?,
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
