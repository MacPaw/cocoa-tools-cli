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
  /// Decode the get secrets result from response data.
  ///
  /// - Parameter data: The response data to decode.
  /// - Returns: Dictionary of secrets.
  /// - Throws: DecodingError if decoding fails.
  public func decodeGetSecretsResult(data: Data) throws -> [String: String] {
    try self.decodeGetSecretsResult(data: data, type: GetSecretsResult.self)
  }

  private func adaptURL(url: URL?, for element: HashiCorpVaultReader.Engine.AWS.Element) throws -> URL {
    guard var url = url else { throw HashiCorpVaultReader.Error.urlIsNotSet }
    url.append(path: element.enginePath, directoryHint: .isDirectory)
    url.append(components: "creds", element.role, directoryHint: .notDirectory)
    return url
  }

  /// Adapt a URL request for AWS engine operations.
  ///
  /// - Parameters:
  ///   - urlRequest: The base URL request to adapt.
  ///   - element: The AWS element to adapt the request for.
  /// - Returns: The adapted URL request.
  /// - Throws: Various errors related to URL construction.
  public func adaptURLRequest(urlRequest: URLRequest, for element: HashiCorpVaultReader.Engine.AWS.Element) throws
    -> URLRequest
  {
    var urlRequest = urlRequest
    urlRequest.url = try adaptURL(url: urlRequest.url, for: element)
    return urlRequest
  }
}

extension API {
  /// Result structure for AWS get secrets operations.
  public struct GetSecretsResult {
    /// The AWS access key.
    public let accessKey: String
    /// The AWS secret key.
    public let secretKey: String
  }
}

extension API.GetSecretsResult: Decodable {}
extension API.GetSecretsResult: HashiCorpVaultEngineGetSecretsResultProtocol {
  /// The secrets dictionary from the result.
  public var secrets: [String: String] { ["accessKey": accessKey, "secretKey": secretKey] }
}
