import Foundation

extension HashiCorpVaultReader {
  public enum Error: Swift.Error {
    case invalidURL(url: URL, message: String)
    case urlIsNotSet
  }
}
