import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

public protocol HashiCorpVaultReaderAWSUniqueElement: Hashable {
  var enginePath: String { get }
  var role: String { get }
}

extension HashiCorpVaultReader.Engine.AWS { public struct API { public init() {} } }

private typealias API = HashiCorpVaultReader.Engine.AWS.API

extension API: Sendable {}

extension API: HashiCorpVaultEngineAPIProtocol {
  public func decodeGetSecretsResult(data: Data) throws -> [String: String] {
    try self.decodeGetSecretsResult(data: data, type: GetSecretsResult.self)
  }

  private func adaptURL(url: URL?, for element: any HashiCorpVaultReaderAWSUniqueElement) throws -> URL {
    guard let url = url else { throw HashiCorpVaultReader.Error.urlIsNotSet }
    guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      throw HashiCorpVaultReader.Error.invalidURL(url: url, message: "Failed to read URL components from URL \(url)")
    }
    urlComponents.path += "/\(element.enginePath)/creds/\(element.role)"
    guard let url = urlComponents.url else {
      throw HashiCorpVaultReader.Error.invalidURL(url: url, message: "Failed to create URL from URL components")
    }
    return url
  }

  public func adaptURLRequest(urlRequest: URLRequest, for element: any HashiCorpVaultReaderAWSUniqueElement) throws
    -> URLRequest
  {
    var urlRequest = urlRequest
    urlRequest.url = try adaptURL(url: urlRequest.url, for: element)
    return urlRequest
  }
}

extension API {
  public struct GetSecretsResult {
    public let accessKey: String
    public let secretKey: String
  }
}

extension API.GetSecretsResult: Decodable {}
extension API.GetSecretsResult: HashiCorpVaultEngineGetSecretsResultProtocol {
  public var secrets: [String: String] { ["accessKey": accessKey, "secretKey": secretKey] }
}
