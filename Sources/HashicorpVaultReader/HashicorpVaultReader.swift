import Foundation

public protocol HashicorpVaultEngineProtocol {
  associatedtype DefaultConfiguration: HashicorpVaultEngineDefaultConfigurationProtocol
  associatedtype APIContext: HashicorpVaultEngineContextProtocol
  func readSecrets(context: APIContext) async throws -> [String: String]

  static var name: String { get }
}

public protocol HashicorpVaultEngineDefaultConfigurationProtocol: Equatable {}

public protocol HashicorpVaultEngineContextProtocol: Equatable, Hashable {
  func adaptURLRequest(urlRequest: URLRequest) throws -> URLRequest

  func decodeGetSecretsResult(data: Data) throws -> [String: String]
}

public protocol HashicorpVaultEngineGetSecretsResultProtocol: Decodable { var secrets: [String: String] { get } }

extension HashicorpVaultEngineContextProtocol {
  func decodeGetSecretsResult<GetSecretsResult: HashicorpVaultEngineGetSecretsResultProtocol>(
    data: Data,
    type: GetSecretsResult.Type
  ) throws -> [String: String] {
    try JSONDecoder().decode(HashicorpVaultReader.SecretsFetchResult<GetSecretsResult>.self, from: data).data.secrets
  }
}

extension HashicorpVaultReader.Engine.KeyValue.APIContext {
  public struct GetSecretsResult { public let data: [String: String] }
}

extension HashicorpVaultReader.Engine.KeyValue.APIContext.GetSecretsResult: Decodable {}
extension HashicorpVaultReader.Engine.KeyValue.APIContext.GetSecretsResult: HashicorpVaultEngineGetSecretsResultProtocol
{ public var secrets: [String: String] { self.data } }

extension HashicorpVaultReader.Engine.AWS.APIContext {
  public struct GetSecretsResult {
    public let accessKey: String
    public let secretKey: String
  }
}

extension HashicorpVaultReader.Engine.AWS.APIContext.GetSecretsResult: Decodable {}
extension HashicorpVaultReader.Engine.AWS.APIContext.GetSecretsResult: HashicorpVaultEngineGetSecretsResultProtocol {
  public var secrets: [String: String] { ["accessKey": accessKey, "secretKey": secretKey] }
}

public protocol HashicorpVaultReaderProtocol {
  func readSecrets<Engine: HashicorpVaultEngineProtocol, APIContext: HashicorpVaultEngineContextProtocol>(
    from engine: Engine,
    context: APIContext
  ) async throws -> [String: String] where Engine.APIContext == APIContext
}

public enum HashicorpVaultReader { public enum Engine {} }

extension HashicorpVaultReader.Engine { public struct KeyValue { public static let name: String = "kv2" } }

extension HashicorpVaultReader.Engine { public struct AWS { public static let name: String = "aws" } }

extension HashicorpVaultReader.Engine.AWS {
  public struct DefaultConfiguration {
    /// The path to the AWS engine to configure, such as `aws`.
    ///
    /// Defaults to `aws`.
    public let defaultEnginePath: String
  }
}

extension HashicorpVaultReader.Engine.AWS.DefaultConfiguration: Decodable {
  private enum CodingKeys: String, CodingKey { case defaultEnginePath }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.defaultEnginePath = try container.decodeIfPresent(String.self, forKey: .defaultEnginePath) ?? "aws"
  }
}

extension HashicorpVaultReader.Engine.AWS {
  public struct APIContext {
    /// The path to the AWS engine to use, such as `aws`.
    public let enginePath: String
    /// Specifies the name of the role to generate credentials against.
    public let role: String
  }
}

extension HashicorpVaultReader.Engine.AWS.APIContext: Decodable {
  private enum CodingKeys: String, CodingKey {
    case enginePath
    case role
  }
}

extension HashicorpVaultReader.Engine.AWS.APIContext: DecodableWithConfiguration {
  public struct DecodingConfiguration {
    let vaultConfiguration: HashicorpVaultReader.Configuration
    let defaultConfiguration: HashicorpVaultReader.Engine.AWS.DefaultConfiguration
  }

  public init(from decoder: any Decoder, configuration: DecodingConfiguration) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.enginePath =
      try container.decodeIfPresent(String.self, forKey: .enginePath)
      ?? configuration.defaultConfiguration.defaultEnginePath
    self.role = try container.decode(String.self, forKey: .role)
  }
}

extension HashicorpVaultReader.Engine.AWS.APIContext: HashicorpVaultEngineContextProtocol {
  public func decodeGetSecretsResult(data: Data) throws -> [String: String] {
    try self.decodeGetSecretsResult(data: data, type: GetSecretsResult.self)
  }

  private func adaptURL(url: URL?) throws -> URL {
    guard let url = url else { throw HashicorpVaultReader.Error.urlIsNotSet }
    guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      throw HashicorpVaultReader.Error.invalidURL(url: url, message: "Failed to read URL components from URL \(url)")
    }
    urlComponents.path = "/\(enginePath)/creds/\(role)"
    guard let url = urlComponents.url else {
      throw HashicorpVaultReader.Error.invalidURL(url: url, message: "Failed to create URL from URL components")
    }
    return url
  }

  public func adaptURLRequest(urlRequest: URLRequest) throws -> URLRequest {
    var urlRequest = urlRequest
    urlRequest.url = try adaptURL(url: urlRequest.url)
    return urlRequest
  }
}

extension HashicorpVaultReader.Engine.KeyValue {
  public struct APIContext {
    /// The path to the KV mount to config, such as `secret`.
    ///
    /// Defaults to `secret`.
    public let secretMountPath: String
    /// Specifies the path of the secret to read.
    public let path: String
    /// Specifies the version to return.
    ///
    /// If not set or the value is not positive integer (`<= 0`), the latest version is returned.
    public let version: Int
  }
}

extension HashicorpVaultReader.Engine.KeyValue {
  public struct DefaultConfiguration { public let defaultSecretMountPath: String }
}

extension HashicorpVaultReader.Engine.KeyValue.DefaultConfiguration: Decodable {
  private enum CodingKeys: String, CodingKey { case defaultSecretMountPath }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.defaultSecretMountPath =
      try container.decodeIfPresent(String.self, forKey: .defaultSecretMountPath) ?? "secret"
  }
}

extension HashicorpVaultReader.Engine.KeyValue.DefaultConfiguration: HashicorpVaultEngineDefaultConfigurationProtocol {}

extension HashicorpVaultReader.Engine.KeyValue.APIContext {}

extension HashicorpVaultReader.Engine.KeyValue.APIContext: DecodableWithConfiguration {
  public struct DecodingConfiguration {
    let vaultConfiguration: HashicorpVaultReader.Configuration
    let defaultConfiguration: HashicorpVaultReader.Engine.KeyValue.DefaultConfiguration
  }

  private enum CodingKeys: String, CodingKey {
    case secretMountPath
    case path
    case version
  }

  public init(from decoder: any Decoder, configuration: DecodingConfiguration) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.secretMountPath =
      try container.decodeIfPresent(String.self, forKey: .secretMountPath)
      ?? configuration.defaultConfiguration.defaultSecretMountPath
    self.path = try container.decode(String.self, forKey: .path)
    self.version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 0
  }
}

extension HashicorpVaultReader.Engine.KeyValue.APIContext: HashicorpVaultEngineContextProtocol {
  public func decodeGetSecretsResult(data: Data) throws -> [String: String] {
    try self.decodeGetSecretsResult(data: data, type: GetSecretsResult.self)
  }

  private func adaptURL(url: URL?) throws -> URL {
    guard let url = url else { throw HashicorpVaultReader.Error.urlIsNotSet }
    guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      throw HashicorpVaultReader.Error.invalidURL(url: url, message: "Failed to read URL components from URL \(url)")
    }
    urlComponents.path = "/\(secretMountPath)/data/\(path)"
    if version > 0 {
      var queryItems = urlComponents.queryItems ?? []
      queryItems.append(URLQueryItem(name: "version", value: String(version)))
      urlComponents.queryItems = queryItems
    }
    guard let url = urlComponents.url else {
      throw HashicorpVaultReader.Error.invalidURL(url: url, message: "Failed to create URL from URL components")
    }

    return url
  }

  public func adaptURLRequest(urlRequest: URLRequest) throws -> URLRequest {
    var urlRequest = urlRequest
    urlRequest.url = try adaptURL(url: urlRequest.url)
    return urlRequest
  }
}

extension HashicorpVaultReader {
  public enum Error: Swift.Error {
    case invalidURL(url: URL, message: String)
    case urlIsNotSet
  }
}

extension HashicorpVaultReader {
  struct Configuration {
    /// The address of the Vault server.
    let vaultAddress: URL
    /// The API version to use.
    ///
    /// Defaults to `v1`.
    let apiVersion: String
    /// The token to use to authenticate with the Vault server.
    let vaultToken: String
    /// The contexts to use to read secrets from the Vault server.
    let engineContexts: [String: any HashicorpVaultEngineContextProtocol]
  }
}

extension HashicorpVaultReader.Configuration: Decodable {
  private enum CodingKeys: String, CodingKey {
    case vaultAddress
    case apiVersion
    case vaultToken
    case engineContexts
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.vaultAddress = try container.decode(URL.self, forKey: .vaultAddress)
    self.apiVersion = try container.decodeIfPresent(String.self, forKey: .apiVersion) ?? "v1"
    self.vaultToken = try container.decode(String.self, forKey: .vaultToken)
    self.engineContexts = [:]
    // self.engineContexts = try container.decode([String: any HashicorpVaultEngineContextProtocol].self, forKey: .engineContexts)
  }
}

extension HashicorpVaultReader {
  struct SecretsFetchResult<ContainedData: Decodable>: Decodable { let data: ContainedData }
}

extension HashicorpVaultReader.Configuration {
  func buildBaseURL() throws -> URL {
    let url = vaultAddress
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      throw HashicorpVaultReader.Error.invalidURL(url: url, message: "Failed to read URL components from URL \(url)")
    }
    components.path += "/\(apiVersion)"
    guard let url = components.url else {
      throw HashicorpVaultReader.Error.invalidURL(url: url, message: "Failed to create URL from URL components")
    }
    return url
  }

  func buildURLRequest(for engineContext: any HashicorpVaultEngineContextProtocol, httpMethod: String = "GET") throws
    -> URLRequest
  {
    let url = try buildBaseURL()
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = httpMethod
    urlRequest.setValue(vaultToken, forHTTPHeaderField: "X-Vault-Token")
    urlRequest = try engineContext.adaptURLRequest(urlRequest: urlRequest)
    urlRequest.url = url
    return urlRequest
  }

  func fetch(secret: any HashicorpVaultEngineContextProtocol) async throws -> [String: String] {
    let urlRequest = try buildURLRequest(for: secret)
    let (data, response) = try await URLSession.shared.data(for: urlRequest)
    let result = try secret.decodeGetSecretsResult(data: data)
    return result
  }
}
