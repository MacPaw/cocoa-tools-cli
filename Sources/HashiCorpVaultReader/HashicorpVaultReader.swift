import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Protocol for HashiCorp Vault reader functionality.
public protocol HashiCorpVaultReaderProtocol: Sendable {
  /// Initializes HashiCorp Vault reader for fetching secrets with a given `configuration`.
  ///
  /// - Parameter configuration: A HashiCorp Vault Configuration to init this reader with.
  ///
  /// - Throws: An error if initialization failed.
  mutating func initialize(configuration: HashiCorpVaultReader.Configuration?) async throws

  /// Fetch secrets from HashiCorp Vault.
  ///
  /// - Parameters:
  ///   - item: A secret item to fetch.
  ///   - keys: A list of secrets to fetch.
  ///   - configuration: The vault configuration containing authentication and connection details.
  /// - Returns: Dictionary mapping secret names to their values.
  /// - Throws: Various errors related to authentication, network, or vault operations.
  func fetchItem(
    _ item: HashiCorpVaultReader.Element.Item,
    keys: Set<String>,
    configuration: HashiCorpVaultReader.Configuration
  ) async throws -> [String: String]
}

/// HashiCorp Vault reader for fetching secrets from Vault servers.
public struct HashiCorpVaultReader {
  /// A vault token to authorize with.
  private(set) var vaultToken: String?

  /// An URL session used for for API requests.
  let urlSession: URLSession

  /// Initialize a new HashiCorp Vault reader.
  ///
  /// - Parameters:
  ///   - vaultToken: A vault token to authorize with.
  ///   - urlSession: An URLSession to use to fetch secrets from Vault.
  public init(vaultToken: String? = .none, urlSession: URLSession = URLSession.vault) {
    self.vaultToken = vaultToken
    self.urlSession = urlSession
  }
}

extension HashiCorpVaultReader: Sendable {}

extension HashiCorpVaultReader: HashiCorpVaultReaderProtocol {
  /// Initializes HashiCorp Vault reader for fetching secrets with a given `configuration`.
  ///
  /// - Parameter configuration: A HashiCorp Vault Configuration to init this reader with.
  ///
  /// - Throws: An error if initialization failed.
  mutating public func initialize(configuration: Configuration?) async throws {
    guard let configuration else { throw Error.noConfigsForItem }
    self.vaultToken = try await authenticate(configuration: configuration)
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
  public func fetchItem(_ item: Element.Item, keys: Set<String>, configuration: Configuration) async throws -> [String:
    String]
  {
    guard let vaultToken else {
      preconditionFailure("Vault token has not been initialized. Call initialize(configuration:) first.")
    }

    let baseRequest: URLRequest = try configuration.buildURLRequest(vaultToken: vaultToken)

    let keyValueAPI = HashiCorpVaultReader.Engine.KeyValue.API()
    let awsAPI = HashiCorpVaultReader.Engine.AWS.API()

    let fetchedSecrets =
      switch item {
      case .keyValue(let keyValue):
        try await self.fetch(
          urlRequest: keyValueAPI.adaptURLRequest(urlRequest: baseRequest, for: keyValue),
          api: keyValueAPI,
          item: keyValue
        )
      case .aws(let aws):
        try await self.fetch(
          urlRequest: awsAPI.adaptURLRequest(urlRequest: baseRequest, for: aws),
          api: awsAPI,
          item: aws
        )
      }

    return fetchedSecrets
  }
}
