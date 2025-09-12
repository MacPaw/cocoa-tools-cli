import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

extension HashiCorpVaultReader {
  /// Configuration for connecting to and authenticating with a HashiCorp Vault server.
  public struct Configuration {
    /// The address of the Vault server.
    public var vaultAddress: URL
    /// The API version to use.
    ///
    /// Defaults to `v1`.
    public var apiVersion: String
    /// The contexts to use to read secrets from the Vault server.
    public var defaultEngineConfigurations: HashiCorpVaultReader.Configuration.EngineConfigurations

    /// The credentials to use to authenticate with the Vault server.
    public var authenticationCredentials: HashiCorpVaultReader.Configuration.AuthenticationCredentials

    /// The method to use to authenticate with the Vault server.
    public var authenticationMethod: HashiCorpVaultReader.Configuration.AuthenticationMethod

    /// Initialize a new vault configuration.
    ///
    /// - Parameters:
    ///   - vaultAddress: The address of the Vault server.
    ///   - apiVersion: The API version to use (defaults to "v1").
    ///   - defaultEngineConfigurations: Default configurations for vault engines.
    ///   - authenticationCredentials: Credentials for vault authentication.
    ///   - authenticationMethod: The authentication method to use.
    public init(
      vaultAddress: URL,
      apiVersion: String = "v1",
      defaultEngineConfigurations: HashiCorpVaultReader.Configuration.EngineConfigurations,
      authenticationCredentials: HashiCorpVaultReader.Configuration.AuthenticationCredentials,
      authenticationMethod: HashiCorpVaultReader.Configuration.AuthenticationMethod
    ) {
      self.vaultAddress = vaultAddress
      self.apiVersion = apiVersion
      self.defaultEngineConfigurations = defaultEngineConfigurations
      self.authenticationCredentials = authenticationCredentials
      self.authenticationMethod = authenticationMethod
    }
  }
}

extension HashiCorpVaultReader.Configuration: Decodable {
  private enum CodingKeys: String, CodingKey {
    case vaultAddress
    case apiVersion
    case authenticationCredentials
    case authenticationMethod
    case engineContexts
  }

  /// Initialize configuration from decoder.
  ///
  /// - Parameter decoder: The decoder to read data from.
  /// - Throws: DecodingError if decoding fails.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.vaultAddress = try container.decode(URL.self, forKey: .vaultAddress)
    self.apiVersion = try container.decodeIfPresent(String.self, forKey: .apiVersion) ?? "v1"
    self.authenticationCredentials = try container.decode(
      HashiCorpVaultReader.Configuration.AuthenticationCredentials.self,
      forKey: .authenticationCredentials
    )
    self.authenticationMethod = try container.decode(
      HashiCorpVaultReader.Configuration.AuthenticationMethod.self,
      forKey: .authenticationMethod
    )
    self.defaultEngineConfigurations = try .init(from: decoder)
    // self.engineContexts = try container.decode([String: any HashiCorpVaultEngineContextProtocol].self, forKey: .engineContexts)
  }
}

extension HashiCorpVaultReader.Configuration {
  func buildBaseURL(path: String = "") throws -> URL {
    var url = vaultAddress
    url.append(component: apiVersion, directoryHint: .isDirectory)
    if !path.isEmpty { url.append(path: path) }
    return url
  }

  func buildURLRequest(httpMethod: String = "GET", vaultToken: String) throws -> URLRequest {
    let url = try buildBaseURL()
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = httpMethod
    urlRequest.setValue(vaultToken, forHTTPHeaderField: "X-Vault-Token")
    urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
    return urlRequest
  }
}

extension HashiCorpVaultReader.Configuration: Equatable {}
extension HashiCorpVaultReader.Configuration: Sendable {}
