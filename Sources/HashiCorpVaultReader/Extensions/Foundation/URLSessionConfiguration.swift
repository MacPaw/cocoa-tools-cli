import Foundation

extension URLSessionConfiguration {
  /// A default URL session configuration for `HashiCorpVaultReader`.
  static let vault: URLSessionConfiguration = {
    var configuration: URLSessionConfiguration = .ephemeral

    configuration.httpMaximumConnectionsPerHost = 10

    return configuration
  }()
}
