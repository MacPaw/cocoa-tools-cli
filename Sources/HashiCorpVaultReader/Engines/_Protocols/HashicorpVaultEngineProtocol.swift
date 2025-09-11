import Foundation

/// Protocol for HashiCorp Vault engine functionality.
public protocol HashiCorpVaultEngineProtocol {
  /// The default configuration type for this engine.
  associatedtype DefaultConfiguration: HashiCorpVaultEngineDefaultConfigurationProtocol
  /// The element type this engine works with.
  associatedtype Element
  /// The API type this engine uses.
  associatedtype API: HashiCorpVaultEngineAPIProtocol where API.Element == Element
  /// Read secrets using the provided API.
  ///
  /// - Parameter api: The API instance to use for reading secrets.
  /// - Returns: Dictionary of secrets.
  /// - Throws: Various errors related to secret retrieval.
  func readSecrets(api: API) async throws -> [String: String]
}

extension HashiCorpVaultEngineAPIProtocol {
  func decodeGetSecretsResult<GetSecretsResult: HashiCorpVaultEngineGetSecretsResultProtocol>(
    data: Data,
    type: GetSecretsResult.Type
  ) throws -> [String: String] {
    try JSONDecoder().decode(HashiCorpVaultReader.SecretsFetchResult<GetSecretsResult>.self, from: data).data.secrets
  }
}
