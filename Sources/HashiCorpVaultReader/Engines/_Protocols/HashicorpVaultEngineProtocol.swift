import Foundation

/// Protocol for HashiCorp Vault engine functionality.
public protocol HashiCorpVaultEngineProtocol {
  /// The default configuration type for this engine.
  associatedtype DefaultConfiguration: HashiCorpVaultEngineDefaultConfigurationProtocol
  /// The item type this engine works with.
  associatedtype Item
  /// The API type this engine uses.
  associatedtype API: HashiCorpVaultEngineAPIProtocol where API.Item == Item
  /// Read secrets using the provided API.
  ///
  /// - Parameter api: The API instance to use for reading secrets.
  /// - Returns: Dictionary of secrets.
  /// - Throws: Various errors related to secret retrieval.
  func readSecrets(api: API) async throws -> [String: String]
}
