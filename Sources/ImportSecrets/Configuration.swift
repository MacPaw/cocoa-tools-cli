import Foundation
import SecretsInterface

extension ImportSecrets {
  /// Namespace for secret fetcher implementations.
  public enum SecretFetchers {}
}

extension ImportSecrets {
  /// The main configuration structure for ImportSecrets.
  ///
  /// This contains all the information needed to fetch secrets from various providers.
  public struct Configuration {
    /// The configuration version for compatibility checking.
    public var version: Int?
    /// Source configurations that define how to connect to secret providers.
    public var sourceConfigurations: SourceConfigurations
    /// The list of secrets to import with their source mappings.
    public var secrets: [ImportSecrets.Secret]
    /// The registered source providers that can fetch secrets.
    public var sourceProviders: [any SecretProviderProtocol]
    /// Secret names mapping.
    public var secretNamesMapping: [String: String]
  }
}

extension ImportSecrets.Configuration {
  /// Validates the entire configuration for consistency and completeness.
  /// - Throws: ImportSecrets.Error if there are duplicate environment variable names or other validation issues.
  mutating public func validate() throws {
    // Validate all source configurations (e.g., 1Password vault settings)
    try sourceConfigurations.validate()

    // Validate each secret individually, allowing them to update themselves with default configurations
    for index in 0..<secrets.count { try secrets[index].validate(with: sourceConfigurations) }
  }
}

extension ImportSecrets.Configuration: Sendable {}

extension ImportSecrets.Configuration: DecodableWithConfiguration {
  /// Initializes a configuration from a decoder with the given decoding configuration.
  ///
  /// - Parameters:
  ///   - decoder: The decoder to read configuration data from.
  ///   - configuration: The decoding configuration containing source providers.
  /// - Throws: Decoding errors if the configuration cannot be parsed.
  public init(from decoder: any Decoder, configuration: DecodingConfiguration) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    // Decode optional version field for future compatibility checking
    let version = try container.decodeIfPresent(Int.self, forKey: .version)

    // Decode source configurations first since secrets may reference them during decoding
    // If no configurations are provided, use an empty container
    let sourceConfigurations =
      try container.decodeIfPresent(
        ImportSecrets.SourceConfigurations.self,
        forKey: .sourceConfigurations,
        configuration: configuration,
      ) ?? .init(configurations: [:])

    var secretsContainer = try container.nestedUnkeyedContainer(forKey: .secrets)
    var secrets: [ImportSecrets.Secret] = []
    let decodingConfiguration = ImportSecrets.Secret.DecodingConfiguration(
      topLevelDecodingConfiguration: configuration,
      sourcesConfigurations: sourceConfigurations
    )

    // Decode secrets, and ignore secretHasNoKnownSources errors.
    while !secretsContainer.isAtEnd {
      do {
        let secret: ImportSecrets.Secret = try secretsContainer.decode(
          ImportSecrets.Secret.self,
          configuration: decodingConfiguration
        )
        secrets.append(secret)
      }
      catch let error as DecodingError {
        switch error {
        case .dataCorrupted(let context)
        where context.underlyingError as? ImportSecrets.Error == .secretHasNoKnownSources: continue
        default: throw error
        }
      }
    }

    let secretNamesMapping: [String: String] = try container.decodeIfPresent(key: .secretNamesMapping) ?? [:]

    self.init(
      version: version,
      sourceConfigurations: sourceConfigurations,
      secrets: secrets,
      sourceProviders: configuration.sourceProviders,
      secretNamesMapping: secretNamesMapping
    )
  }

  private enum CodingKeys: String, CodingKey {
    case version
    case secrets
    case sourceConfigurations
    case secretNamesMapping
  }
}

extension ImportSecrets.Configuration: Decodable {
  /// Fallback initializer for Decodable conformance (should not be used directly).
  ///
  /// - Parameter decoder: The decoder (unused).
  /// - Throws: Always throws a precondition failure as this method should not be called.
  public init(from decoder: any Decoder) throws {
    // This initializer should never be called directly - it's only here for ArgumentParser compatibility
    // ArgumentParser requires Decodable conformance but we need the custom configuration-aware decoding
    preconditionFailure(
      "Should never happen. Use `init(from:configuration:)` instead. This is only needed for compatibility with AsyncParsableCommand, so we can use ImportSecrets.Configuration as a Decodable property"
    )
  }
}
