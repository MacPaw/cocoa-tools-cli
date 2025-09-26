import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

extension URLSession {
  /// A default session for `HashiCorpVaultReader`.
  public static var vault: URLSession { .init(configuration: .vault) }
}
