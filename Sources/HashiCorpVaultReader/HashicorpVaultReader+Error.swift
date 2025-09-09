import Foundation

extension HashiCorpVaultReader {
  public enum Error: Swift.Error {
    case invalidURL(url: URL, message: String)
    case urlIsNotSet
    case noSecretsFetched(secretName: String, item: HashiCorpVaultReader.Element)
    case noSecretValueForItemKey(secretName: String, item: HashiCorpVaultReader.Element, key: String)
    case tooManyEngineConfigs
    case noConfigsForItem
  }
}
