import Foundation

extension HashicorpVaultReader {
  public struct Configuration {
    /// The address of the Vault server.
    public var vaultAddress: URL
    /// The API version to use.
    ///
    /// Defaults to `v1`.
    public var apiVersion: String
    /// The token to use to authenticate with the Vault server.
    public var vaultToken: String
    /// The contexts to use to read secrets from the Vault server.
    public var defaultEngineConfigurations: HashicorpVaultReader.Configuration.EngineConfigurations

    public init(
      vaultAddress: URL,
      apiVersion: String = "v1",
      vaultToken: String,
      defaultEngineConfigurations: HashicorpVaultReader.Configuration.EngineConfigurations
    ) {
      self.vaultAddress = vaultAddress
      self.apiVersion = apiVersion
      self.vaultToken = vaultToken
      self.defaultEngineConfigurations = defaultEngineConfigurations
    }
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
    self.defaultEngineConfigurations = try .init(from: decoder)
    // self.engineContexts = try container.decode([String: any HashicorpVaultEngineContextProtocol].self, forKey: .engineContexts)
  }
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

  func buildURLRequest(httpMethod: String = "GET") throws -> URLRequest {
    let url = try buildBaseURL()
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = httpMethod
    urlRequest.setValue(vaultToken, forHTTPHeaderField: "X-Vault-Token")
    //    urlRequest = try engineContext.adaptURLRequest(urlRequest: urlRequest)
    return urlRequest
  }
}

extension HashicorpVaultReader.Configuration: Equatable {}
extension HashicorpVaultReader.Configuration: Sendable {}
