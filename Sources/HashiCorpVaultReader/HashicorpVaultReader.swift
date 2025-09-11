import Foundation

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
  /// Fetch secrets from HashiCorp Vault.
  ///
  /// - Parameters:
  ///   - secrets: Dictionary mapping secret names to their element configurations.
  ///   - configuration: The vault configuration containing authentication and connection details.
  /// - Returns: Dictionary mapping secret names to their values.
  /// - Throws: Various errors related to authentication, network, or vault operations.
  func fetch(secrets: [String: HashiCorpVaultReader.Element], configuration: HashiCorpVaultReader.Configuration)
    async throws -> [String: String]
}

/// HashiCorp Vault reader for fetching secrets from Vault servers.
public struct HashiCorpVaultReader {
  /// Initialize a new HashiCorp Vault reader.
  public init() {}
}

extension HashiCorpVaultReader {
  struct SecretsFetchResult<ContainedData: Decodable>: Decodable { let data: ContainedData }
}

extension HashiCorpVaultReader {
  /// Represents a vault element that can be either KeyValue or AWS engine type.
  public struct Element {
    /// KeyValue engine configuration for this element.
    public var keyValue: HashiCorpVaultReader.Engine.KeyValue.Element?
    /// AWS engine configuration for this element.
    public var aws: HashiCorpVaultReader.Engine.AWS.Element?

    /// Initialize a new vault element.
    ///
    /// - Parameters:
    ///   - keyValue: Optional KeyValue engine configuration.
    ///   - aws: Optional AWS engine configuration.
    public init(
      keyValue: HashiCorpVaultReader.Engine.KeyValue.Element? = nil,
      aws: HashiCorpVaultReader.Engine.AWS.Element? = nil
    ) {
      self.keyValue = keyValue
      self.aws = aws
    }
  }
}

extension HashiCorpVaultReader.Element: DecodableWithConfiguration {
  private enum CodingKeys: String, CodingKey {
    case keyValue
    case aws
  }
  /// Initialize element from decoder with configuration.
  ///
  /// - Parameters:
  ///   - decoder: The decoder to read data from.
  ///   - configuration: The vault configuration for default values.
  /// - Throws: DecodingError if decoding fails or validation fails.
  public init(from decoder: any Decoder, configuration: HashiCorpVaultReader.Configuration) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.keyValue = try container.decodeIfPresent(
      HashiCorpVaultReader.Engine.KeyValue.Element.self,
      forKey: .keyValue,
      configuration: configuration
    )

    self.aws = try container.decodeIfPresent(
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
    let (data, response) = try await URLSession.shared.data(for: urlRequest)
    guard let response = response as? HTTPURLResponse else { throw HTTPError.responseNotHTTP(response) }
    guard (200..<300).contains(response.statusCode) else { throw HTTPError.wrongStatusCode(response.statusCode) }
    let result = try api.decodeGetSecretsResult(data: data)
    return result
  }

  func authenticateWithAppRole(configuration: Configuration) async throws -> String {
    var urlRequest: URLRequest = try URLRequest(url: configuration.buildBaseURL(path: "/auth/approle/login"))
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let appRole = configuration.authenticationCredentials.appRole
    guard let appRole else { throw HashiCorpVaultReader.Error.appRoleAuthenticationCredentialsAreNotSet }
    urlRequest.httpBody = Data(#"{"role_id": "\#(appRole.roleId)", "secret_id": "\#(appRole.secretId)"}"#.utf8)

    let (data, response) = try await URLSession.shared.data(for: urlRequest)
    guard let response = response as? HTTPURLResponse else { throw HTTPError.responseNotHTTP(response) }
    guard (200..<300).contains(response.statusCode) else { throw HTTPError.wrongStatusCode(response.statusCode) }
    let result = try JSONDecoder().decode([String: String].self, from: data)
    let vaultToken = result["client_token"]
    guard let vaultToken else { throw HashiCorpVaultReader.Error.cantGetTokenFromAppRoleAuthenticationResponse }
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

  /// Fetch secrets from HashiCorp Vault.
  ///
  /// - Parameters:
  ///   - secrets: Dictionary mapping secret names to their element configurations.
  ///   - configuration: The vault configuration containing authentication and connection details.
  /// - Returns: Dictionary mapping secret names to their values.
  /// - Throws: Various errors related to authentication, network, or vault operations.
  public func fetch(secrets: [String: Element], configuration: Configuration) async throws -> [String: String] {
    // Group secrets by unique item (vault + item name) to batch field requests
    // This optimization allows us to fetch multiple fields from the same item in one API call
    // instead of making separate calls for each field
    let itemsToFetch: [UniqueItem: Set<String>] = secrets.values.reduce(into: [:]) { accum, source in
      let uniqueItem: UniqueItem = .init(source: source)
      if let key = source.keyValue?.key {
        accum[uniqueItem, default: []].insert(key)
      }
      else if let key = source.aws?.key {
        accum[uniqueItem, default: []].insert(key)
      }
    }

    let vaultToken = try await authenticate(configuration: configuration)

    let keyValueAPI = HashiCorpVaultReader.Engine.KeyValue.API()
    let awsAPI = HashiCorpVaultReader.Engine.AWS.API()

    let baseRequest: URLRequest = try configuration.buildURLRequest(vaultToken: vaultToken)
    let uniqueFetchedResult: [UniqueItem: [String: String]] = try await withThrowingTaskGroup(
      of: [UniqueItem: [String: String]].self,
      returning: [UniqueItem: [String: String]].self
    ) { taskGroup in
      for (item, keys) in itemsToFetch {
        let urlRequest: URLRequest
        let api: any HashiCorpVaultEngineAPIProtocol
        if let keyValue = item.keyValue {
          urlRequest = try keyValueAPI.adaptURLRequest(urlRequest: baseRequest, for: keyValue)
          api = keyValueAPI
        }
        else if let aws = item.aws {
          urlRequest = try awsAPI.adaptURLRequest(urlRequest: baseRequest, for: aws)
          api = awsAPI
        }
        else {
          continue
        }

        taskGroup.addTask { [self, item, urlRequest, keys] in
          let fetchedSecrets = try await self.fetch(urlRequest: urlRequest, api: api)
          let itemSecrets = fetchedSecrets.filter { keys.contains($0.key) }
          return [item: itemSecrets]
        }
      }

      return try await taskGroup.reduce(into: [UniqueItem: [String: String]]()) { partialResult, name in
        partialResult.merge(name) { $0.merging($1) { old, _ in old } }
      }
    }

    var result: [String: String] = [:]
    for (secretName, item) in secrets {
      let uniqueItem = UniqueItem(source: item)

      // Check if we successfully fetched data for this item
      guard let fetchedSecrets = uniqueFetchedResult[uniqueItem] else {
        throw Error.noSecretsFetched(secretName: secretName, item: item)
      }

      let key: String

      if let keyValue = item.keyValue {
        key = keyValue.key
      }
      else if let aws = item.aws {
        key = aws.key
      }
      else {
        continue
      }

      // Check if we successfully fetched data for required key
      guard let fetchedValue = fetchedSecrets[key] else {
        throw Error.noSecretValueForItemKey(secretName: secretName, item: item, key: key)
      }

      result[secretName] = fetchedValue
    }

    return result
  }

  /// Represents a unique 1Password item (vault + item name combination).
  ///
  /// Used to group multiple field requests for the same item to optimize API calls.
  struct UniqueItem: Equatable, Hashable {
    struct KeyValue: Equatable, Hashable, HashiCorpVaultReaderKeyValueUniqueElement {
      var secretMountPath: String
      var path: String
      var version: Int

      init?(source: HashiCorpVaultReader.Engine.KeyValue.Element?) {
        guard let source else { return nil }
        self.init(source: source)
      }

      init(source: HashiCorpVaultReader.Engine.KeyValue.Element) {
        self.secretMountPath = source.secretMountPath
        self.path = source.path
        self.version = source.version
      }
    }

    struct AWS: Equatable, Hashable, HashiCorpVaultReaderAWSUniqueElement {
      var enginePath: String
      var role: String
      init?(source: HashiCorpVaultReader.Engine.AWS.Element?) {
        guard let source else { return nil }
        self.init(source: source)
      }

      init(source: HashiCorpVaultReader.Engine.AWS.Element) {
        self.enginePath = source.enginePath
        self.role = source.role
      }
    }

    var keyValue: KeyValue?
    var aws: AWS?

    /// Creates a UniqueItem from a source, applying default account and vault if needed.
    init(source: HashiCorpVaultReader.Element) {
      keyValue = .init(source: source.keyValue)
      aws = .init(source: source.aws)
    }
  }
}
