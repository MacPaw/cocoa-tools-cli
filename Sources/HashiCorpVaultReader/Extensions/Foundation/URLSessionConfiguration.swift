import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

extension URLSessionConfiguration {
  /// A default URL session configuration for `HashiCorpVaultReader`.
  static var vault: URLSessionConfiguration {
    let configuration: URLSessionConfiguration = .ephemeral

    configuration.httpMaximumConnectionsPerHost = 10

    return configuration
  }
}
