import EnvSubst
import Foundation
import Shell
import Yams

/// Main entry point for importing secrets from various providers.
///
/// ImportSecrets provides a unified interface for loading secret configurations,
/// fetching secrets from different providers, and managing the import process.
public struct ImportSecrets {
  /// Creates a configuration from a YAML file.
  /// - Parameters:
  ///   - configurationURL: URL to the YAML configuration file.
  ///   - sourceProviders: Array of secret source providers to use for decoding.
  ///   - encoding: Text encoding for parsing the configuration file.
  ///   - envSubstOptions: Optional environment variable substitution options.
  ///   - environment: Environment variables to use for substitution. Defaults to the current process environment.
  ///   - fileManager: File manager for reading the configuration file.
  /// - Returns: A parsed ImportSecrets configuration.
  /// - Throws: ImportSecrets.Error if the file is not found or cannot be read, or parsing errors.
  public static func configuration(
    configurationURL: URL,
    sourceProviders: [any SecretProviderProtocol],
    encoding: Parser.Encoding = .default,
    envSubstOptions: EnvSubst.Options? = .none,
    environment: [String: String] = ProcessInfo.processInfo.environment,
    fileManager: FileManagerProtocol = FileManager.default,
  ) throws -> ImportSecrets.Configuration {
    guard try configurationURL.checkResourceIsReachable() else { throw Error.configurationFileNotFound }

    guard let data: Data = fileManager.contents(atPath: configurationURL.filePath) else {
      throw Error.cantReadConfigurationFile
    }

    let configuration = try configuration(
      configurationData: data,
      sourceProviders: sourceProviders,
      encoding: encoding,
      envSubstOptions: envSubstOptions,
      environment: environment
    )

    return configuration
  }

  /// Creates a configuration from YAML data.
  /// - Parameters:
  ///   - data: Raw YAML data containing the configuration.
  ///   - sourceProviders: Array of secret source providers to use for decoding.
  ///   - encoding: Text encoding for parsing the configuration data.
  ///   - envSubstOptions: Optional environment variable substitution options.
  ///   - environment: Environment variables to use for substitution. Defaults to the current process environment.
  /// - Returns: A parsed ImportSecrets configuration.
  /// - Throws: Parsing errors or validation errors from the configuration.
  public static func configuration(
    configurationData data: Data,
    sourceProviders: [any SecretProviderProtocol],
    encoding: Parser.Encoding = .default,
    envSubstOptions: EnvSubst.Options? = .none,
    environment: [String: String] = ProcessInfo.processInfo.environment,
  ) throws -> ImportSecrets.Configuration {
    // Apply environment variable substitution to the configuration data if options are provided
    // This allows configuration files to contain ${VAR} placeholders that get replaced with actual env values
    let data: Data =
      try envSubstOptions.map {
        try EnvSubst.substitute(data, environment: environment, options: $0, encoding: encoding.swiftStringEncoding)
      } ?? data

    let decodingConfig = ImportSecrets.Configuration.DecodingConfiguration(sourceProviders: sourceProviders)

    let decoder = YAMLDecoder(encoding: encoding)
    let configuration = try decoder.decode(ImportSecrets.Configuration.self, from: data, configuration: decodingConfig)

    return configuration
  }

  /// Loads configuration from a file and fetches all secrets.
  /// - Parameters:
  ///   - configurationURL: URL to the YAML configuration file.
  ///   - sourceProviders: Array of secret source providers to use for fetching.
  ///   - encoding: Text encoding for parsing the configuration file.
  ///   - envSubstOptions: Optional environment variable substitution options.
  ///   - environment: Environment variables to use for substitution. Defaults to the current process environment.
  ///   - fileManager: File manager for reading the configuration file.
  /// - Returns: A dictionary mapping environment variable names to their secret values.
  /// - Throws: Configuration errors, validation errors, or fetching errors.
  public static func getSecrets(
    configurationURL: URL,
    sourceProviders: [any SecretProviderProtocol],
    encoding: Parser.Encoding = .default,
    envSubstOptions: EnvSubst.Options? = .none,
    environment: [String: String] = ProcessInfo.processInfo.environment,
    fileManager: FileManagerProtocol = FileManager.default,
  ) async throws -> [String: String] {
    var configuration = try configuration(
      configurationURL: configurationURL,
      sourceProviders: sourceProviders,
      encoding: encoding,
      envSubstOptions: envSubstOptions,
      environment: environment,
      fileManager: fileManager,
    )

    try configuration.validate()

    return try await ImportSecrets.getSecrets(configuration: configuration)
  }

  /// Loads configuration from data and fetches all secrets.
  /// - Parameters:
  ///   - configurationData: Raw YAML data containing the configuration.
  ///   - sourceProviders: Array of secret source providers to use for fetching.
  ///   - encoding: Text encoding for parsing the configuration data.
  ///   - envSubstOptions: Optional environment variable substitution options.
  ///   - environment: Environment variables to use for substitution. Defaults to the current process environment.
  /// - Returns: A dictionary mapping environment variable names to their secret values.
  /// - Throws: Configuration errors, validation errors, or fetching errors.
  public static func getSecrets(
    configurationData: Data,
    sourceProviders: [any SecretProviderProtocol],
    encoding: Parser.Encoding = .default,
    envSubstOptions: EnvSubst.Options? = .none,
    environment: [String: String] = ProcessInfo.processInfo.environment,
  ) async throws -> [String: String] {
    var configuration = try configuration(
      configurationData: configurationData,
      sourceProviders: sourceProviders,
      encoding: encoding,
      envSubstOptions: envSubstOptions,
      environment: environment,
    )

    try configuration.validate()

    return try await ImportSecrets.getSecrets(configuration: configuration)
  }

  /// Fetches secrets using an already-loaded configuration.
  /// - Parameter configuration: The ImportSecrets configuration to use.
  /// - Returns: A dictionary mapping environment variable names to their secret values.
  /// - Throws: Validation errors or fetching errors.
  public static func getSecrets(configuration: ImportSecrets.Configuration) async throws -> [String: String] {
    var configuration = configuration
    try configuration.validate()

    return try await ImportSecrets.getSecrets(
      secrets: configuration.secrets,
      sourceProviders: configuration.sourceProviders,
      sourceConfigurations: configuration.sourceConfigurations,
    )
  }

  private static func getSecrets(
    secrets: [ImportSecrets.Secret],
    sourceProviders: [any SecretProviderProtocol],
    sourceConfigurations: ImportSecrets.SourceConfigurations,
  ) async throws -> [String: String] {
    guard !secrets.isEmpty else { throw Error.noSecretsToFetch }

    // Track all fetched secrets and which ones are still missing
    var allFetchedSecrets: [String: String] = [:]
    var missingSecrets: Set<String> = Set(secrets.map(\.envVarName))

    // Group secrets by provider type for efficient fetching - this allows us to batch requests
    // to the same provider instead of making individual calls for each secret
    let secretsBySource = try groupSecretsBySourceProvider(secrets: secrets, sourceProviders: sourceProviders)

    var result: SecretsFetchResult = .init()

    // Fetch secrets from each provider sequentially
    // Note: This could be parallelized in the future for better performance
    for sourceProvider in sourceProviders {
      let configurationKey = type(of: sourceProvider).configurationKey
      // Skip providers that don't have any secrets to fetch
      guard let sourceSecrets = secretsBySource[configurationKey] else { continue }

      let sourceConfiguration: (any SecretConfigurationProtocol)? = sourceConfigurations.getConfiguration(
        for: configurationKey
      )

      let fetchedSecretsResult: SecretsFetchResult = try await sourceProvider.fetch(
        secrets: sourceSecrets as [ImportSecrets.Secret],
        sourceConfiguration: sourceConfiguration,
      )

      // Merge the fetched secrets, preferring new values over existing ones
      result.fetchedSecrets.merge(fetchedSecretsResult.fetchedSecrets) { $1 }

      // Accumulate errors from all providers, combining error arrays for the same secret
      result.errors.merge(fetchedSecretsResult.errors) { $0 + $1 }

      // Clear errors for secrets that were successfully fetched
      for secretName in fetchedSecretsResult.fetchedSecrets.keys { result.errors[secretName] = nil }

      // Update our tracking collections
      allFetchedSecrets.merge(fetchedSecretsResult.fetchedSecrets) { $1 }
      missingSecrets.subtract(fetchedSecretsResult.fetchedSecrets.keys)
    }

    // Fail if any secrets had errors during fetching
    guard result.errors.isEmpty else { throw Error.failedToFetchSecrets(result.errors) }

    // Fail if any secrets are still missing (couldn't be fetched from any provider)
    guard missingSecrets.isEmpty else { throw Error.missingSecrets(Set(missingSecrets)) }

    return allFetchedSecrets
  }

  /// Groups secrets by their available providers for efficient batch fetching.
  ///
  /// This optimization allows providers to fetch multiple secrets in a single request
  /// rather than making individual API calls for each secret.
  private static func groupSecretsBySourceProvider(
    secrets: [ImportSecrets.Secret],
    sourceProviders: [any SecretProviderProtocol],
  ) throws -> [String: [ImportSecrets.Secret]] {
    var result: [String: [ImportSecrets.Secret]] = [:]

    for secret in secrets {
      let availableSourceKeys: [String] = secret.availableSourceKeys

      // For each source that this secret can be fetched from
      for configurationKey in availableSourceKeys {
        // Ensure we have a provider registered for this source type
        guard let sourceProvider = sourceProviders.first(where: { type(of: $0).configurationKey == configurationKey })
        else { throw Error.unsupportedSecretSource(configurationKey) }

        // Group this secret under the provider's configuration key
        result[type(of: sourceProvider).configurationKey, default: []].append(secret)
      }
    }

    return result
  }
}
