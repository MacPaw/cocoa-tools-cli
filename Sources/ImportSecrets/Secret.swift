import Foundation

extension ImportSecrets {
  /// Represents a secret to be imported from one or more sources.
  ///
  /// A secret defines the environment variable name and the sources from which
  /// the secret value can be retrieved.
  public struct Secret {
    /// The environment variable name to import the secret to.
    public var envVarName: String
    /// Typed secret sources for extensible secret sources.
    ///
    /// Maps source keys to their corresponding source configurations.
    private var sources: [String: any SecretSourceProtocol]

    /// Creates a new secret with the specified environment variable name and sources.
    /// - Parameters:
    ///   - envVarName: The environment variable name to import the secret to.
    ///   - sources: Array of secret sources that can provide the secret value.
    /// - Throws: ImportSecrets.Error.secretSourceWithSameKeyAlreadyExists if multiple sources have the same configuration key.
    public init(envVarName: String, sources: [any SecretSourceProtocol]) throws {
      // Convert array of sources to dictionary, ensuring no duplicate configuration keys
      // This prevents conflicts where multiple sources have the same provider type
      let sources = try sources.reduce(into: [String: any SecretSourceProtocol]()) { accum, source in
        let configurationKey: String = Swift.type(of: source).configurationKey
        guard accum[configurationKey] == nil else {
          throw ImportSecrets.Error.secretSourceWithSameKeyAlreadyExists(key: configurationKey)
        }
        accum[configurationKey] = source
      }
      self.init(envVarName: envVarName, sources: sources)
    }

    /// Internal initializer for creating a secret with a pre-validated sources dictionary.
    /// - Parameters:
    ///   - envVarName: The environment variable name to import the secret to.
    ///   - sources: Dictionary mapping configuration keys to their corresponding sources.
    init(envVarName: String, sources: [String: any SecretSourceProtocol]) {
      self.envVarName = envVarName
      self.sources = sources
    }

    /// Gets the configuration for a configuration source key.
    /// - Parameter configurationKey: The configuration source key to look up.
    /// - Returns: The configuration if found, nil otherwise.
    func getSource(for configurationKey: String) -> (any SecretSourceProtocol)? { sources[configurationKey] }

    /// Gets a typed source for the specified configuration key.
    /// - Parameters:
    ///   - configurationKey: The configuration source key to look up.
    ///   - type: The expected source type.
    /// - Returns: The typed source if found and matches the expected type, nil if not found.
    /// - Throws: ImportSecrets.Error.sourceTypeMismatch if the source exists but has the wrong type.
    func getSource<Source: SecretSourceProtocol>(for configurationKey: String, type: Source.Type = Source.self) throws
      -> Source?
    {
      guard let source = sources[configurationKey] else { return nil }
      guard let source = source as? Source else {
        throw ImportSecrets.Error.sourceTypeMismatch(expected: type, got: Swift.type(of: source))
      }
      return source
    }

    /// Check if this secret has a source for the given configuration key.
    ///
    /// - Parameters:
    ///   - configurationKey: The configuration key to check for.
    ///   - type: The source type to check for.
    /// - Returns: True if the secret has a source for the given key, false otherwise.
    func hasSource<Source: SecretSourceProtocol>(
      for configurationKey: String = Source.configurationKey,
      type: Source.Type = Source.self
    ) -> Bool { sources[configurationKey] is Source }

    /// Get all available source keys for this secret.
    /// - Returns: Array of configuration keys for all sources configured for this secret.
    var availableSourceKeys: [String] { Array(sources.keys) }

    /// Add a source to the secret.
    /// - Parameter source: The source to add.
    /// - Throws: ImportSecrets.Error.secretSourceWithSameKeyAlreadyExists if a source with the same configuration key already exists.
    mutating func addSource(_ source: any SecretSourceProtocol) throws {
      let configurationKey: String = type(of: source).configurationKey
      guard sources[configurationKey] == nil else {
        throw Error.secretSourceWithSameKeyAlreadyExists(key: configurationKey)
      }
      sources[type(of: source).configurationKey] = source
    }
  }
}

extension ImportSecrets.Secret: Sendable {}

// Custom decoding is handled in Configuration.swift using YAML parsing

extension ImportSecrets.Secret: DecodableWithConfiguration {
  public struct DecodingConfiguration {
    let topLevelDecodingConfiguration: ImportSecrets.Configuration.DecodingConfiguration
    let sourcesConfigurations: ImportSecrets.SourceConfigurations
    let secretEnvVarName: String
  }

  private enum CodingKeys: String, CodingKey { case sources }

  public init(from decoder: any Decoder, configuration: DecodingConfiguration) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    // The environment variable name comes from the YAML key, not from the decoded content
    self.envVarName = configuration.secretEnvVarName

    // Get the nested container for the 'sources' field in the YAML
    let sourcesContainer = try container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .sources)

    // Decode sources by iterating through available providers and checking if they have config in YAML
    var sources: [String: any SecretSourceProtocol] = [:]

    // Try to decode a source for each registered provider
    for sourceProvider in configuration.topLevelDecodingConfiguration.sourceProviders {
      let sourceConfigurationKey = type(of: sourceProvider).configurationKey
      let providerKey = DynamicCodingKey(stringValue: sourceConfigurationKey)

      // Skip providers that don't have configuration in this secret's YAML
      guard sourcesContainer.contains(providerKey) else { continue }

      // Get the global configuration for this provider (e.g., default vault for 1Password)
      let sourceConfiguration: (any SecretConfigurationProtocol)? = configuration.sourcesConfigurations
        .getConfiguration(for: sourceConfigurationKey)

      // Decode the source-specific configuration (e.g., specific item and field for this secret)
      let sourceDecoder = try sourcesContainer.superDecoder(forKey: providerKey)
      let source = try sourceProvider.decodeSource(from: sourceDecoder, sourceConfiguration: sourceConfiguration)

      sources[sourceConfigurationKey] = source
    }

    // Ensure at least one source was successfully decoded
    // This prevents secrets that reference only unknown/unsupported providers
    guard !sources.isEmpty else {
      throw DecodingError.dataCorruptedError(
        forKey: .sources,
        in: container,
        debugDescription: "No known sources specified for \(configuration.secretEnvVarName) secret"
      )
    }

    self.sources = sources
  }

  mutating public func validate(with sourceConfigurations: ImportSecrets.SourceConfigurations) throws {
    // Validate each source, allowing them to apply default configurations
    // For example, 1Password sources can inherit default vault from global config
    for key in sources.keys { try sources[key]?.validate(with: sourceConfigurations) }
  }
}
