#if canImport(FoundationNetworking)
  public import FoundationNetworking
#else
  public import Foundation
#endif

extension URLSession {
  /// A default session for `HashiCorpVaultReader`.
  public static var vault: URLSession { .init(configuration: .vault) }
}
