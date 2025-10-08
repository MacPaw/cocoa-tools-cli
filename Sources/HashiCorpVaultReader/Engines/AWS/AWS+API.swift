import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Protocol for unique AWS elements used in API operations.
public protocol HashiCorpVaultReaderAWSUniqueElement: Hashable {
  /// The AWS engine path.
  var enginePath: String { get }
  /// The AWS role name.
  var role: String { get }
}

extension HashiCorpVaultReader.Engine.AWS {
  /// API implementation for AWS engine operations.
  public struct API {
    /// Initialize a new AWS API instance.
    public init() {}
  }
}

private typealias API = HashiCorpVaultReader.Engine.AWS.API

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
  public func secretsFromResponse(_ data: Data, for item: HashiCorpVaultReader.Engine.AWS.Item) throws -> [String: Any]
  { try getDataObjectFromResponse(data) }

  private func adaptURL(url: URL?, for item: HashiCorpVaultReader.Engine.AWS.Item) throws -> URL {
    guard var url = url else { throw HashiCorpVaultReader.Error.urlIsNotSet }
    url.append(path: item.enginePath, directoryHint: .isDirectory)
    url.append(components: "creds", item.role, directoryHint: .notDirectory)
    return url
  }

  /// Adapt a URL request for AWS engine operations.
  ///
  /// - Parameters:
  ///   - urlRequest: The base URL request to adapt.
  ///   - item: The AWS item to adapt the request for.
  /// - Returns: The adapted URL request.
  /// - Throws: Various errors related to URL construction.
  public func adaptURLRequest(urlRequest: URLRequest, for item: HashiCorpVaultReader.Engine.AWS.Item) throws
    -> URLRequest
  {
    var urlRequest = urlRequest
    urlRequest.url = try adaptURL(url: urlRequest.url, for: item)
    return urlRequest
  }
}
