import Foundation

extension HashicorpVaultReader {
  public enum Error: Swift.Error {
    case invalidURL(url: URL, message: String)
    case urlIsNotSet
  }
}
