import Foundation

extension ImportSecrets {
  /// The main configuration structure for ImportSecrets.
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
  }
}

extension ImportSecrets.Configuration {
  /// Validates the entire configuration for consistency and completeness.
  /// - Throws: ImportSecrets.Error if there are duplicate environment variable names or other validation issues.
  mutating public func validate() throws {
    // Check for duplicate environment variable names across all secrets
    // This prevents conflicts where multiple secrets would try to set the same env var
    let variableNames = secrets.map(\.envVarName)
    let uniqueEnvVarNames = Set(secrets.map(\.envVarName))
    if uniqueEnvVarNames.count != secrets.count {
      // Find which variable names appear more than once
      let duplicatedEnvVarNames = uniqueEnvVarNames.filter { varName in variableNames.filter { $0 == varName }.count > 1
      }
      throw ImportSecrets.Error.duplicatedEnvVarNames(duplicatedEnvVarNames)
    }

    // Validate all source configurations (e.g., 1Password vault settings)
    try sourceConfigurations.validate()

    // Validate each secret individually, allowing them to update themselves with default configurations
    for index in 0..<secrets.count { try secrets[index].validate(with: sourceConfigurations) }
  }
}

extension ImportSecrets.Configuration: Sendable {}

extension ImportSecrets.Configuration: DecodableWithConfiguration {
  public init(from decoder: any Decoder, configuration: DecodingConfiguration) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    // Decode optional version field for future compatibility checking
    self.version = try container.decodeIfPresent(Int.self, forKey: .version)

    // Decode source configurations first since secrets may reference them during decoding
    // If no configurations are provided, use an empty container
    self.sourceConfigurations =
      try container.decodeIfPresent(
        ImportSecrets.SourceConfigurations.self,
        forKey: .sourceConfigurations,
        configuration: configuration
      ) ?? .init(configurations: [:])

    // Decode secrets using dynamic keys (the YAML keys become the environment variable names)
    let secretsContainer = try container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .secrets)
    var secrets: [ImportSecrets.Secret] = []

    // Decode each secret, using the YAML key as the environment variable name
    for key in secretsContainer.allKeys {
      let secretDecoder = try secretsContainer.superDecoder(forKey: key)
      let secret = try ImportSecrets.Secret(
        from: secretDecoder,
        configuration: .init(
          topLevelDecodingConfiguration: configuration,
          sourcesConfigurations: sourceConfigurations,
          secretEnvVarName: key.stringValue  // YAML key becomes the env var name
        )
      )
      secrets.append(secret)
    }
    self.secrets = secrets
    self.sourceProviders = configuration.sourceProviders
  }

  private enum CodingKeys: String, CodingKey {
    case version
    case secrets
    case sourceConfigurations
  }
}

extension ImportSecrets.Configuration: Decodable {
  public init(from decoder: any Decoder) throws {
    // This initializer should never be called directly - it's only here for ArgumentParser compatibility
    // ArgumentParser requires Decodable conformance but we need the custom configuration-aware decoding
    preconditionFailure(
      "Should never happen. Use `init(from:configuration:)` instead. This is only needed for compatibility with AsyncParsableCommand, so we can use ImportSecrets.Configuration as a Decodable property"
    )
  }
}
