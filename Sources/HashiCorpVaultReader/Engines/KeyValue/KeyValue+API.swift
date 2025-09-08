import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol HashiCorpVaultReaderKeyValueUniqueElement: Hashable {
  var secretMountPath: String { get }
  var path: String { get }
  var version: Int { get }
}

extension HashiCorpVaultReader.Engine.KeyValue { public struct API { public init() {} } }

private typealias API = HashiCorpVaultReader.Engine.KeyValue.API

extension API: Sendable {}

extension API: HashiCorpVaultEngineAPIProtocol {
  public func decodeGetSecretsResult(data: Data) throws -> [String: String] {
    try self.decodeGetSecretsResult(data: data, type: GetSecretsResult.self)
  }

  private func adaptURL(url: URL?, for element: any HashiCorpVaultReaderKeyValueUniqueElement) throws -> URL {
    guard let url = url else { throw HashiCorpVaultReader.Error.urlIsNotSet }
    guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      throw HashiCorpVaultReader.Error.invalidURL(url: url, message: "Failed to read URL components from URL \(url)")
    }
    urlComponents.path = "/\(element.secretMountPath)/data/\(element.path)"
    if element.version > 0 {
      var queryItems = urlComponents.queryItems ?? []
      queryItems.append(URLQueryItem(name: "version", value: String(element.version)))
      urlComponents.queryItems = queryItems
    }
    guard let url = urlComponents.url else {
      throw HashiCorpVaultReader.Error.invalidURL(url: url, message: "Failed to create URL from URL components")
    }

    return url
  }

  public func adaptURLRequest(urlRequest: URLRequest, for element: any HashiCorpVaultReaderKeyValueUniqueElement) throws
    -> URLRequest
  {
    var urlRequest = urlRequest
    urlRequest.url = try adaptURL(url: urlRequest.url, for: element)
    return urlRequest
  }
}

extension API { public struct GetSecretsResult { public let data: [String: String] } }

extension API.GetSecretsResult: Decodable {}
extension API.GetSecretsResult: HashiCorpVaultEngineGetSecretsResultProtocol {
  public var secrets: [String: String] { self.data }
}
