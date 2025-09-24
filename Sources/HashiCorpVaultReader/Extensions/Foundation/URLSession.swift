import Foundation

extension URLSession {
  /// A default session for `HashiCorpVaultReader`.
  public static let vault: URLSession = .init(configuration: .vault)
}
