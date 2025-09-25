import Foundation
import SharedLogger

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Protocol for HashiCorp Vault engine get secrets result.
public protocol HashiCorpVaultEngineGetSecretsResultProtocol: Decodable {
  /// The secrets dictionary containing key-value pairs.
  var secrets: [String: String] { get }
}

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

  private var urlSession: URLSession

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

extension HashiCorpVaultReader {
  struct SecretsFetchResult<ContainedData: Decodable>: Decodable { let data: ContainedData }
}

extension HashiCorpVaultReader.Element {
  /// A unique Vault item.
  public enum Item {
    case keyValue(HashiCorpVaultReader.Engine.KeyValue.Element)
    case aws(HashiCorpVaultReader.Engine.AWS.Element)
  }
}

extension HashiCorpVaultReader.Element.Item: Sendable {}
extension HashiCorpVaultReader.Element.Item: Equatable {}
extension HashiCorpVaultReader.Element.Item: Hashable {}
extension HashiCorpVaultReader.Element.Item: DecodableWithConfiguration {
  private enum CodingKeys: String, CodingKey {
    case keyValue
    case aws
  }

  /// Initialize a unique element item from decoder with configuration.
  ///
  /// - Parameters:
  ///   - decoder: The decoder to read data from.
  ///   - configuration: The vault configuration for default values.
  /// - Throws: DecodingError if decoding fails or validation fails.
  public init(from decoder: any Decoder, configuration: HashiCorpVaultReader.Configuration) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    let keyValue = try container.decodeIfPresent(
      HashiCorpVaultReader.Engine.KeyValue.Element.self,
      forKey: .keyValue,
      configuration: configuration
    )

    let aws = try container.decodeIfPresent(
      HashiCorpVaultReader.Engine.AWS.Element.self,
      forKey: .aws,
      configuration: configuration
    )

    let engineConfigs: [Any?] = [keyValue, aws]
    guard !engineConfigs.compactMap(\.self).isEmpty else {
      throw DecodingError.valueNotFound(
        Self.self,
        .init(codingPath: decoder.codingPath, debugDescription: "No engine configured for this item.")
      )
    }
    guard engineConfigs.compactMap(\.self).count == 1 else {
      throw DecodingError.dataCorrupted(
        .init(
          codingPath: decoder.codingPath,
          debugDescription: "Too many engine configs. Only one engine can be configured per item (kv or aws, not both)."
        )
      )
    }

    if let keyValue = keyValue {
      self = .keyValue(keyValue)
    }
    else if let aws = aws {
      self = .aws(aws)
    }
    else {
      throw DecodingError.dataCorrupted(
        .init(
          codingPath: decoder.codingPath,
          debugDescription: "Vault configuration is malformed and has no keyValue or aws configuration."
        )
      )
    }
  }
}

extension HashiCorpVaultReader {
  /// Represents a vault element that can be either KeyValue or AWS engine type.
  public struct Element {
    /// Engine item configuration for this element.
    public var item: HashiCorpVaultReader.Element.Item
    /// Keys within the secret to retrieve.
    public var keys: [String]

    /// Initialize a new vault element.
    ///
    /// - Parameters:
    ///   - item: A unique Element item.
    ///   - keys: A list of key to fetch. Optional. Default value is empty list.
    public init(item: Item, keys: [String] = []) {
      self.item = item
      self.keys = keys
    }
  }
}

extension HashiCorpVaultReader.Element: DecodableWithConfiguration {
  private enum CodingKeys: String, CodingKey { case keys }
  /// Initialize element from decoder with configuration.
  ///
  /// - Parameters:
  ///   - decoder: The decoder to read data from.
  ///   - configuration: The vault configuration for default values.
  /// - Throws: DecodingError if decoding fails or validation fails.
  public init(from decoder: any Decoder, configuration: HashiCorpVaultReader.Configuration) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.keys = try container.decodeIfPresent([String].self, forKey: .keys) ?? []

    self.item = try HashiCorpVaultReader.Element.Item(from: decoder, configuration: configuration)
  }
}

extension HashiCorpVaultReader.Element: Sendable {}
extension HashiCorpVaultReader.Element: Equatable {}
extension HashiCorpVaultReader.Element: Hashable {}

extension HashiCorpVaultReader: Sendable {}

extension HashiCorpVaultReader: HashiCorpVaultReaderProtocol {
  /// HTTP-related errors that can occur during vault operations.
  public enum HTTPError: Swift.Error {
    /// The response is not an HTTP response.
    case responseNotHTTP(URLResponse)
    /// The HTTP status code indicates an error.
    case wrongStatusCode(Int)
  }

  func fetch(urlRequest: URLRequest, api: any HashiCorpVaultEngineAPIProtocol) async throws -> [String: String] {
    let (data, response) = try await urlSession.data(for: urlRequest)
    guard let response = response as? HTTPURLResponse else { throw HTTPError.responseNotHTTP(response) }
    guard (200..<300).contains(response.statusCode) else { throw HTTPError.wrongStatusCode(response.statusCode) }
    let result = try api.decodeGetSecretsResult(data: data)
    return result
  }

  func authenticateWithAppRole(configuration: Configuration) async throws -> String {
    log.debug("Authenticating with App Role")
    var urlRequest: URLRequest = try URLRequest(url: configuration.buildBaseURL(path: "/auth/approle/login"))
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let appRole = configuration.authenticationCredentials.appRole
    guard let appRole else { throw HashiCorpVaultReader.Error.appRoleAuthenticationCredentialsAreNotSet }
    urlRequest.httpBody = Data(#"{"role_id": "\#(appRole.roleId)", "secret_id": "\#(appRole.secretId)"}"#.utf8)

    struct Response: Decodable {
      struct Auth: Decodable {
        var clientToken: String
        var leaseDuration: TimeInterval
        var renewable: Bool
        var tokenType: String
      }
      var auth: Auth
    }
    let (data, response) = try await urlSession.data(for: urlRequest)
    guard let response = response as? HTTPURLResponse else { throw HTTPError.responseNotHTTP(response) }
    guard (200..<300).contains(response.statusCode) else { throw HTTPError.wrongStatusCode(response.statusCode) }
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let result = try decoder.decode(Response.self, from: data)
    let vaultToken = result.auth.clientToken
    return vaultToken
  }

  func authenticate(configuration: Configuration) async throws -> String {
    switch configuration.authenticationMethod {
    case .token:
      guard let token = configuration.authenticationCredentials.token?.vaultToken else {
        throw HashiCorpVaultReader.Error.tokenAuthenticationCredentialsIsNotSet
      }
      return token
    case .appRole: return try await authenticateWithAppRole(configuration: configuration)
    }
  }

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

    let urlRequest: URLRequest
    let api: any HashiCorpVaultEngineAPIProtocol

    switch item {
    case .keyValue(let keyValue):
      urlRequest = try keyValueAPI.adaptURLRequest(urlRequest: baseRequest, for: keyValue)
      api = keyValueAPI
    case .aws(let aws):
      urlRequest = try awsAPI.adaptURLRequest(urlRequest: baseRequest, for: aws)
      api = awsAPI
    }

    let fetchedSecrets = try await self.fetch(urlRequest: urlRequest, api: api)

    return fetchedSecrets
  }
}
