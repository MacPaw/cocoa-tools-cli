import Foundation

extension ImportSecrets {
  /// Container for source configurations used by secret providers.
  /// This stores the configuration parameters needed by different secret providers
  /// to authenticate and connect to their respective services.
  public struct SourceConfigurations {
    /// Maps source keys to their corresponding configurations.
    private var configurations: [String: any SecretConfigurationProtocol]

    /// Creates a new source configurations container.
    /// - Parameter configurations: Dictionary mapping source keys to their configurations.
    init(configurations: [String: any SecretConfigurationProtocol]) { self.configurations = configurations }

    /// Gets the configuration for a configuration source key.
    /// - Parameter configurationKey: The configuration source key to look up.
    /// - Returns: The configuration if found, nil otherwise.
    func getConfiguration(for configurationKey: String) -> (any SecretConfigurationProtocol)? {
      configurations[configurationKey]
    }

    /// Gets a typed configuration for the specified configuration key.
    /// - Parameters:
    ///   - configurationKey: The configuration source key to look up.
    ///   - type: The expected configuration type.
    /// - Returns: The typed configuration if found and matches the expected type, nil if not found.
    /// - Throws: ImportSecrets.Error.configurationTypeMismatch if the configuration exists but has the wrong type.
    func getConfiguration<Configuration: SecretConfigurationProtocol>(
      for configurationKey: String,
      type: Configuration.Type = Configuration.self
    ) throws -> Configuration? {
      guard let configuration = configurations[configurationKey] else { return nil }
      guard let configuration = configuration as? Configuration else {
        throw ImportSecrets.Error.configurationTypeMismatch(expected: type, got: Swift.type(of: configuration))
      }
      return configuration
    }

    /// Validates all stored configurations.
    /// - Throws: Validation errors from any of the stored configurations.
    mutating public func validate() throws { for key in configurations.keys { try configurations[key]?.validate() } }

    /// Adds a new configuration to the container.
    /// - Parameter configuration: The configuration to add.
    /// - Throws: ImportSecrets.Error.configurationWithSameKeyAlreadyExists if a configuration with the same key already exists.
    mutating func addConfiguration(_ configuration: any SecretConfigurationProtocol) throws {
      let configurationKey: String = type(of: configuration).configurationKey
      guard configurations[configurationKey] == nil else {
        throw Error.configurationWithSameKeyAlreadyExists(key: configurationKey)
      }
      configurations[type(of: configuration).configurationKey] = configuration
    }
  }
}

// Custom decoding is handled in Configuration.swift using YAML parsing

extension ImportSecrets.SourceConfigurations: DecodableWithConfiguration {
  public typealias DecodingConfiguration = ImportSecrets.Configuration.DecodingConfiguration

  public init(from decoder: any Decoder, configuration: DecodingConfiguration) throws {
    let sourcesContainer = try decoder.container(keyedBy: DynamicCodingKey.self)

    // Decode sources using providers
    var configurations: [String: any SecretConfigurationProtocol] = [:]

    for sourceProvider in configuration.sourceProviders {
      let sourceConfigurationKey = type(of: sourceProvider).configurationKey
      let sourceProviderKey = DynamicCodingKey(stringValue: sourceConfigurationKey)
      guard sourcesContainer.contains(sourceProviderKey) else { continue }
      let configurationDecoder = try sourcesContainer.superDecoder(forKey: sourceProviderKey)
      let configuration = try sourceProvider.decodeConfiguration(from: configurationDecoder)

      guard configurations[sourceConfigurationKey] == nil else {
        throw DecodingError.dataCorrupted(
          DecodingError.Context(
            codingPath: decoder.codingPath,
            debugDescription: "Multiple configurations for source key \(sourceConfigurationKey)"
          )
        )
      }

      configurations[sourceConfigurationKey] = configuration
    }

    self.configurations = configurations
  }
}

extension ImportSecrets.SourceConfigurations: Sendable {}
