import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Protocol for HashiCorp Vault engine API functionality.
public protocol HashiCorpVaultEngineAPIProtocol: Equatable, Hashable, Sendable {
  /// The element type this API works with.
  associatedtype Item: HashiCorpVaultEngineItem
  /// Adapt a URL request for a specific item.
  ///
  /// - Parameters:
  ///   - urlRequest: The base URL request to adapt.
  ///   - item: The item to adapt the request for.
  /// - Returns: The adapted URL request.
  /// - Throws: Various errors related to URL construction.
  func adaptURLRequest(urlRequest: URLRequest, for item: Item) throws -> URLRequest

  /// Decode  the response `Data` and return fetched secrets for a given `item`.
  ///
  /// - Parameters:
  ///   - data: The response data to decode.
  ///   - item: The item to decode data for.
  /// - Returns: Dictionary of secrets.
  /// - Throws: DecodingError if decoding fails.
  func secretsFromResponse(_ data: Data, for item: Item) throws -> [String: Any]
}

extension HashiCorpVaultEngineAPIProtocol {
  /// Decodes the response `Data` and returns nested dictionary for the`data` key.
  ///
  /// - Parameter data: The response data to decode.
  /// - Returns: Dictionary of `data` object.
  /// - Throws: DecodingError if decoding fails.
  func getDataObjectFromResponse(_ data: Data) throws -> [String: Any] {
    let jsonObject: Any = try JSONSerialization.jsonObject(with: data)
    guard let json = jsonObject as? [String: Any] else {
      throw DecodingError.typeMismatch(
        type(of: jsonObject),
        .init(codingPath: [], debugDescription: "Can't decode JSON to the Dictionary<String, Any> type")
      )
    }
    guard let dataAnyObject = json["data"] else {
      throw DecodingError.keyNotFound(
        CodingKeys.data,
        .init(codingPath: [], debugDescription: "Can't find the root 'data' key in the JSON")
      )
    }
    guard let dataObject = dataAnyObject as? [String: Any] else {
      throw DecodingError.typeMismatch(
        type(of: jsonObject),
        .init(
          codingPath: [CodingKeys.data],
          debugDescription: "'data' is not a valid JSON object of Dictionary<String, Any> type"
        )
      )
    }

    return dataObject
  }
}

/// Protocol describing HashiCorp Vault engine item (KeyValue or AWS).
public protocol HashiCorpVaultEngineItem: Sendable {}

private enum CodingKeys: String, CodingKey { case data }
