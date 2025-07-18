import Foundation

extension ImportSecrets.Configuration {
  /// Configuration used for decoding YAML configurations with registered providers.
  /// This provides the context needed by the YAML decoder to properly instantiate
  /// the correct provider types during deserialization.
  public struct DecodingConfiguration: Sendable {
    /// Array of registered secret providers that can be used during decoding.
    /// These providers define how to decode and fetch secrets from different sources.
    public let sourceProviders: [any SecretProviderProtocol]

    /// Creates a new decoding configuration.
    /// - Parameter sourceProviders: Array of secret providers to register for decoding.
    public init(sourceProviders: [any SecretProviderProtocol]) { self.sourceProviders = sourceProviders }
  }
}
