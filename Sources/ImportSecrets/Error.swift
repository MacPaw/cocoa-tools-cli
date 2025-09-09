extension ImportSecrets {
  /// Errors that can occur during secret import operations.
  public enum Error: Swift.Error, Equatable {
    /// Thrown when no secrets are configured to be fetched.
    case noSecretsToFetch
    /// Thrown when some configured secrets could not be fetched from their sources.
    case missingSecrets(Set<String>)
    /// Thrown when provider failed to acquire secrets.
    case failedToFetchSecrets([String: [String]])
    /// Thrown when an invalid source type is encountered during processing.
    case invalidSourceType
    /// Thrown when an unsupported secret source type is referenced in configuration.
    case unsupportedSecretSource(String)
    /// Thrown when a secret is configured with multiple sources (not currently supported).
    case multipleSourcesForSecret(String)
    /// Thrown when a secret configuration is provided but has incorrect type.
    case configurationTypeMismatch(expected: String, got: String)
    /// Thrown when a secret source is provided but has incorrect type.
    case sourceTypeMismatch(expected: String, got: String)

    /// Thrown when configuration with the same key exists.
    case configurationWithSameKeyAlreadyExists(key: String)

    /// Thrown when secret source with the same key exists.
    case secretSourceWithSameKeyAlreadyExists(key: String)

    // MARK: - Configuration and validation errors

    /// Thrown when the configuration file cannot be found at the specified path.
    case configurationFileNotFound
    /// Thrown when the configuration file cannot be read.
    case cantReadConfigurationFile
    /// Thrown when the configuration has not been validated.
    case configurationNotValidated
    /// Thrown when multiple secrets are configured with the same environment variable name.
    case duplicatedEnvVarNames(Set<String>)

    /// Thrown when secret declaration in config file has no known sources.
    case secretHasNoKnownSources
  }
}

extension ImportSecrets.Error {
  static func sourceTypeMismatch(expected: any SecretSourceProtocol.Type, got: any SecretSourceProtocol.Type) -> Self {
    .sourceTypeMismatch(expected: String(describing: expected), got: String(describing: got))
  }

  static func configurationTypeMismatch(
    expected: any SecretConfigurationProtocol.Type,
    got: any SecretConfigurationProtocol.Type,
  ) -> Self { .configurationTypeMismatch(expected: String(describing: expected), got: String(describing: got)) }

  static func failedToFetchSecrets(_ secretFetchErrors: [String: [any Swift.Error]]) -> Self {
    .failedToFetchSecrets(secretFetchErrors.mapValues { $0.map(String.init(describing:)) })
  }
}
