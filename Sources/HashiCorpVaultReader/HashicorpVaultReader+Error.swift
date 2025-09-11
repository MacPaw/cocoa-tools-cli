import Foundation

extension HashiCorpVaultReader {
  /// Errors that can occur during HashiCorp Vault operations.
  public enum Error: Swift.Error {
    /// The URL is invalid or cannot be constructed.
    case invalidURL(url: URL, message: String)
    /// The URL is not set when required.
    case urlIsNotSet
    /// No secrets were fetched for the specified item.
    case noSecretsFetched(secretName: String, item: HashiCorpVaultReader.Element)
    /// No secret value found for the specified item key.
    case noSecretValueForItemKey(secretName: String, item: HashiCorpVaultReader.Element, key: String)
    /// Too many engine configurations specified for a single item.
    case tooManyEngineConfigs
    /// No engine configurations specified for the item.
    case noConfigsForItem
    /// AppRole authentication credentials are not set when required.
    case appRoleAuthenticationCredentialsAreNotSet
    /// Token authentication credentials are not set when required.
    case tokenAuthenticationCredentialsIsNotSet
    /// Cannot extract token from AppRole authentication response.
    case cantGetTokenFromAppRoleAuthenticationResponse
  }
}
