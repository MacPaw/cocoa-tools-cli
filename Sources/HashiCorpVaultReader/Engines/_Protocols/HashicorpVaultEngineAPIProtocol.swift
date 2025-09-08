import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol HashiCorpVaultEngineAPIProtocol: Equatable, Hashable, Sendable {
  associatedtype Element
  func adaptURLRequest(urlRequest: URLRequest, for element: Element) throws -> URLRequest

  func decodeGetSecretsResult(data: Data) throws -> [String: String]
}
