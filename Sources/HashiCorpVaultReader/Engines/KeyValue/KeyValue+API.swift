import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Protocol for unique KeyValue elements used in API operations.
public protocol HashiCorpVaultReaderKeyValueUniqueElement: Hashable {
  /// The secret mount path.
  var secretMountPath: String { get }
  /// The path of the secret.
  var path: String { get }
  /// The version of the secret.
  var version: Int { get }
}

extension HashiCorpVaultReader.Engine.KeyValue {
  /// API implementation for KeyValue engine operations.
  public struct API {
    /// Initialize a new KeyValue API instance.
    public init() {}
  }
}

private typealias API = HashiCorpVaultReader.Engine.KeyValue.API

extension API: Sendable {}

extension API: HashiCorpVaultEngineAPIProtocol {
  /// Decode the get secrets result from response data.
  ///
  /// - Parameter data: The response data to decode.
  /// - Returns: Dictionary of secrets.
  /// - Throws: DecodingError if decoding fails.
  public func decodeGetSecretsResult(data: Data) throws -> [String: String] {
    try self.decodeGetSecretsResult(data: data, type: GetSecretsResult.self)
  }

  private func adaptURL(url: URL?, for element: HashiCorpVaultReader.Engine.KeyValue.Element) throws -> URL {
    guard var url = url else { throw HashiCorpVaultReader.Error.urlIsNotSet }
    url.append(path: element.secretMountPath, directoryHint: .isDirectory)
    url.append(component: "data", directoryHint: .isDirectory)
    url.append(path: element.path, directoryHint: .notDirectory)
    guard element.version > 0 else { return url }

    guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      throw HashiCorpVaultReader.Error.invalidURL(url: url, message: "Failed to read URL components from URL \(url)")
    }
    var queryItems = urlComponents.queryItems ?? []
    queryItems.append(URLQueryItem(name: "version", value: String(element.version)))
    urlComponents.queryItems = queryItems

    guard let url = urlComponents.url else {
      throw HashiCorpVaultReader.Error.invalidURL(url: url, message: "Failed to create URL from URL components")
    }

    return url
  }

  /// Adapt a URL request for KeyValue engine operations.
  ///
  /// - Parameters:
  ///   - urlRequest: The base URL request to adapt.
  ///   - element: The KeyValue element to adapt the request for.
  /// - Returns: The adapted URL request.
  /// - Throws: Various errors related to URL construction.
  public func adaptURLRequest(urlRequest: URLRequest, for element: HashiCorpVaultReader.Engine.KeyValue.Element) throws
    -> URLRequest
  {
    var urlRequest = urlRequest
    urlRequest.url = try adaptURL(url: urlRequest.url, for: element)
    return urlRequest
  }
}

extension API {
  /// Result structure for KeyValue get secrets operations.
  public struct GetSecretsResult {
    /// The secrets data returned from the vault.
    public let data: [String: String]
  }
}

extension API.GetSecretsResult: Decodable {}
extension API.GetSecretsResult: HashiCorpVaultEngineGetSecretsResultProtocol {
  /// The secrets dictionary from the result.
  public var secrets: [String: String] { self.data }
}
