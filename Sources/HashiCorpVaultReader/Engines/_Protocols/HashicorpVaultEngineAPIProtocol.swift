import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Protocol for HashiCorp Vault engine API functionality.
public protocol HashiCorpVaultEngineAPIProtocol: Equatable, Hashable, Sendable {
  /// The element type this API works with.
  associatedtype Element: HashiCorpVaultEngineElement
  /// Adapt a URL request for a specific element.
  ///
  /// - Parameters:
  ///   - urlRequest: The base URL request to adapt.
  ///   - element: The element to adapt the request for.
  /// - Returns: The adapted URL request.
  /// - Throws: Various errors related to URL construction.
  func adaptURLRequest(urlRequest: URLRequest, for element: Element) throws -> URLRequest

  /// Decode the get secrets result from response data.
  ///
  /// - Parameters:
  ///   - data: The response data to decode.
  ///   - element: The element decode data for.
  /// - Returns: Dictionary of secrets.
  /// - Throws: DecodingError if decoding fails.
  func decodeGetSecretsResult(data: Data, for element: Element) throws -> [String: String]
}

extension HashiCorpVaultEngineAPIProtocol {
  func decodeGetSecretsResult<GetSecretsResult: HashiCorpVaultEngineGetSecretsResultProtocol>(
    data: Data,
    type: GetSecretsResult.Type
  ) throws -> [String: String] {
    try JSONDecoder().decode(HashiCorpVaultReader.SecretsFetchResult<GetSecretsResult>.self, from: data).data.secrets
  }
}

/// Protocol describing HashiCorp Vault engine element (KeyValue or AWS).
public protocol HashiCorpVaultEngineElement: Sendable {}
