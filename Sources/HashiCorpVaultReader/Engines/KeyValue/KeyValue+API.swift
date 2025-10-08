import Foundation
import SharedLogger

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
  private enum CodingKeys: String, CodingKey { case data }
  /// Decode  the response `Data` and return fetched secrets for a given `item`.
  ///
  /// - Parameters:
  ///   - data: The response data to decode.
  ///   - item: The item to decode data for.
  /// - Returns: Dictionary of secrets.
  /// - Throws: DecodingError if decoding fails.
  public func secretsFromResponse(_ data: Data, for item: HashiCorpVaultReader.Engine.KeyValue.Item) throws -> [String:
    Any]
  {
    let dataObject = try getDataObjectFromResponse(data)
    guard item.engineVersion > .v1 else { return dataObject }

    guard let nestedDataAnyObject = dataObject["data"] else {
      throw DecodingError.keyNotFound(
        CodingKeys.data,
        .init(codingPath: [CodingKeys.data], debugDescription: "Can't find the root 'data' key in the JSON")
      )
    }
    guard let nestedDataObject = nestedDataAnyObject as? [String: Any] else {
      throw DecodingError.typeMismatch(
        type(of: nestedDataAnyObject),
        .init(
          codingPath: [CodingKeys.data, CodingKeys.data],
          debugDescription: "'data' is not a valid JSON object of Dictionary<String, Any> type"
        )
      )
    }

    return nestedDataObject
  }

  private func adaptURLV1(url: URL?, for item: HashiCorpVaultReader.Engine.KeyValue.Item) throws -> URL {
    // URL: /:secret-mount-path/:path
    // https://developer.hashicorp.com/vault/api-docs/secret/kv/kv-v1#read-secret
    guard var url = url else { throw HashiCorpVaultReader.Error.urlIsNotSet }
    url.append(path: item.secretMountPath, directoryHint: .isDirectory)
    url.append(path: item.path, directoryHint: .notDirectory)
    return url
  }

  private func adaptURLV2(url: URL?, for item: HashiCorpVaultReader.Engine.KeyValue.Item) throws -> URL {
    // URL: /:secret-mount-path/data/:path?version=:version-number
    // https://developer.hashicorp.com/vault/api-docs/secret/kv/kv-v2#read-secret-version
    guard var url = url else { throw HashiCorpVaultReader.Error.urlIsNotSet }
    url.append(path: item.secretMountPath, directoryHint: .isDirectory)
    url.append(component: "data", directoryHint: .isDirectory)
    url.append(path: item.path, directoryHint: .notDirectory)
    guard item.version > 0 else { return url }

    guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      throw HashiCorpVaultReader.Error.invalidURL(url: url, message: "Failed to read URL components from URL \(url)")
    }
    var queryItems = urlComponents.queryItems ?? []
    queryItems.append(URLQueryItem(name: "version", value: String(item.version)))
    urlComponents.queryItems = queryItems

    guard let url = urlComponents.url else {
      throw HashiCorpVaultReader.Error.invalidURL(url: url, message: "Failed to create URL from URL components")
    }

    return url
  }

  private func adaptURL(url: URL?, for item: HashiCorpVaultReader.Engine.KeyValue.Item) throws -> URL {
    let url =
      switch item.engineVersion {
      case .v1: try adaptURLV1(url: url, for: item)
      case .v2: try adaptURLV2(url: url, for: item)
      }
    return url
  }

  /// Adapt a URL request for KeyValue engine operations.
  ///
  /// - Parameters:
  ///   - urlRequest: The base URL request to adapt.
  ///   - item: The KeyValue element to adapt the request for.
  /// - Returns: The adapted URL request.
  /// - Throws: Various errors related to URL construction.
  public func adaptURLRequest(urlRequest: URLRequest, for item: HashiCorpVaultReader.Engine.KeyValue.Item) throws
    -> URLRequest
  {
    var urlRequest = urlRequest
    urlRequest.url = try adaptURL(url: urlRequest.url, for: item)
    return urlRequest
  }
}
