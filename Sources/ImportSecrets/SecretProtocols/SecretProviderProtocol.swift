import Foundation

/// Protocol defining a secret provider that combines a source and fetcher.
public protocol SecretProviderProtocol: Sendable {
  associatedtype Source: SecretSourceProtocol
  associatedtype Fetcher: SecretFetcherProtocol where Fetcher.Source == Source

  /// The fetcher implementation for this provider
  var fetcher: Fetcher { get }

  /// Initialize the provider with a fetcher.
  /// - Parameter fetcher: The fetcher implementation to use for retrieving secrets.
  init(fetcher: Fetcher)

  /// Decode source from decoder.
  /// - Parameters:
  ///   - decoder: The decoder to read the source configuration from.
  ///   - sourceConfiguration: Optional configuration to use during decoding.
  /// - Returns: The decoded secret source.
  /// - Throws: Decoding errors if the source cannot be decoded.
  func decodeSource(from decoder: any Decoder, sourceConfiguration: Source.Configuration?) throws -> Source

  /// Decode configuration from decoder.
  /// - Parameter decoder: The decoder to read the configuration from.
  /// - Returns: The decoded source configuration.
  /// - Throws: Decoding errors if the configuration cannot be decoded.
  func decodeConfiguration(from decoder: any Decoder) throws -> Source.Configuration
}

// MARK: - Source key accessors

extension SecretProviderProtocol { static var configurationKey: String { Source.configurationKey } }

// MARK: - Decodable support
// These extensions provide automatic implementations based on the source's Decodable conformance

// For sources with simple Decodable configurations
extension SecretProviderProtocol where Source.Configuration: Decodable {
  /// Decodes a configuration from the given decoder.
  ///
  /// - Parameter decoder: The decoder to read configuration data from.
  /// - Returns: The decoded configuration.
  /// - Throws: Decoding errors if the configuration cannot be parsed.
  public func decodeConfiguration(from decoder: any Decoder) throws -> Source.Configuration {
    try Source.Configuration.init(from: decoder)
  }
}

// For sources that can be decoded without additional configuration
extension SecretProviderProtocol where Source: Decodable {
  /// Decodes a source from the given decoder without requiring configuration.
  ///
  /// - Parameters:
  ///   - decoder: The decoder to read source data from.
  ///   - sourceConfiguration: Optional source configuration (unused for simple Decodable sources).
  /// - Returns: The decoded source.
  /// - Throws: Decoding errors if the source cannot be parsed.
  public func decodeSource(from decoder: any Decoder, sourceConfiguration: Source.Configuration?) throws -> Source {
    try Source.init(from: decoder)
  }
}

// For sources that need optional configuration during decoding
extension SecretProviderProtocol
where Source: DecodableWithConfiguration, Source.DecodingConfiguration == Source.Configuration? {
  /// Decodes a source from the given decoder with optional configuration.
  ///
  /// - Parameters:
  ///   - decoder: The decoder to read source data from.
  ///   - sourceConfiguration: Optional source configuration to use during decoding.
  /// - Returns: The decoded source.
  /// - Throws: Decoding errors if the source cannot be parsed.
  public func decodeSource(from decoder: any Decoder, sourceConfiguration: Source.Configuration?) throws -> Source {
    try Source.init(from: decoder, configuration: sourceConfiguration)
  }
}

// For sources that require configuration during decoding (configuration cannot be nil)
extension SecretProviderProtocol
where Source: DecodableWithConfiguration, Source.DecodingConfiguration == Source.Configuration {
  /// Decodes a source from the given decoder with required configuration.
  ///
  /// - Parameters:
  ///   - decoder: The decoder to read source data from.
  ///   - sourceConfiguration: Required source configuration to use during decoding.
  /// - Returns: The decoded source.
  /// - Throws: Decoding errors if the source cannot be parsed, or fatal error if configuration is nil.
  public func decodeSource(from decoder: any Decoder, sourceConfiguration: Source.Configuration?) throws -> Source {
    guard let sourceConfiguration else { fatalError("Cannot decode source without configuration") }
    return try Source.init(from: decoder, configuration: sourceConfiguration)
  }
}

// MARK: - Default fetching

extension SecretProviderProtocol {
  /// Fetches secrets using the provider's fetcher implementation.
  ///
  /// - Parameters:
  ///   - secrets: Dictionary mapping secret names to their source configurations.
  ///   - sourceConfiguration: Optional configuration to use for fetching.
  /// - Returns: Result containing successfully fetched secrets and any errors encountered.
  /// - Throws: Fetching errors if the operation fails.
  public func fetch(secrets: [String: Source], sourceConfiguration: Source.Configuration?) async throws
    -> SecretsFetchResult
  { try await fetcher.fetch(secrets: secrets, sourceConfiguration: sourceConfiguration) }
}

// MARK: - Type-erased method signatures

extension SecretProviderProtocol {
  /// Gets a typed source configuration from a type-erased configuration.
  /// - Parameters:
  ///   - configuration: The type-erased configuration to cast.
  ///   - type: The expected configuration type.
  /// - Returns: The typed configuration if the cast succeeds, nil if the input is nil.
  /// - Throws: ImportSecrets.Error.configurationTypeMismatch if the configuration has the wrong type.
  static func getSourceConfiguration<T: SecretConfigurationProtocol>(
    _ configuration: (any SecretConfigurationProtocol)?,
    is type: T.Type = T.self
  ) throws -> T? {
    guard let configuration else { return nil }
    guard let typedConfiguration = configuration as? T else {
      throw ImportSecrets.Error.configurationTypeMismatch(expected: type, got: Swift.type(of: configuration))
    }
    return typedConfiguration
  }

  /// Maps a type-erased secret source to a typed source.
  /// - Parameters:
  ///   - source: The type-erased source to cast.
  ///   - type: The expected source type.
  /// - Returns: The typed source.
  /// - Throws: ImportSecrets.Error.sourceTypeMismatch if the source has the wrong type.
  static func mapSecretSource<Source: SecretSourceProtocol>(
    _ source: any SecretSourceProtocol,
    as type: Source.Type = Source.self
  ) throws -> Source {
    guard let typedSource = source as? Source else {
      throw ImportSecrets.Error.sourceTypeMismatch(expected: type, got: Swift.type(of: source))
    }
    return typedSource
  }

  func fetch(secrets: [ImportSecrets.Secret], sourceConfiguration: (any SecretConfigurationProtocol)?) async throws
    -> SecretsFetchResult
  {
    // Cast the type-erased configuration to our specific configuration type
    let sourceConfiguration: Source.Configuration? = try Self.getSourceConfiguration(sourceConfiguration)

    // Extract the source configurations from each secret for this provider
    // This converts from Secret objects to provider-specific Source objects
    let secretsToFetch: [String: Source] = try secrets.reduce(into: [:]) { accum, secret in
      accum[secret.envVarName] = try secret.getSource(for: Self.configurationKey)
    }

    // Delegate to the typed fetch method
    return try await self.fetch(secrets: secretsToFetch, sourceConfiguration: sourceConfiguration)
  }

  /// Type-erased source decoding - converts from any secret configuration protocol to specific Source type.
  func decodeSource(from decoder: any Decoder, sourceConfiguration: (any SecretConfigurationProtocol)?) throws
    -> any SecretSourceProtocol
  {
    // Cast the type-erased configuration and delegate to typed decoding
    let sourceConfiguration: Source.Configuration? = try Self.getSourceConfiguration(sourceConfiguration)
    let source: Source = try decodeSource(from: decoder, sourceConfiguration: sourceConfiguration)
    return source
  }

  /// Type-erased configuration decoding - converts from specific Configuration to any protocol.
  func decodeConfiguration(from decoder: any Decoder) throws -> any SecretConfigurationProtocol {
    // Decode using typed method then return as type-erased protocol
    let configuration: Source.Configuration = try decodeConfiguration(from: decoder)
    return configuration
  }
}

// MARK: Default generics implementations

/// Basic provider implementation for sources that conform to Decodable.
///
/// This provides a standard implementation for providers where the source can be decoded directly.
public struct BasicProviderDecodableSource<Source: SecretSourceProtocol & Decodable, Fetcher: SecretFetcherProtocol>
where Fetcher.Source == Source, Source.Configuration: Decodable {
  /// The source type handled by this provider.
  public typealias Source = Source
  /// The fetcher type used to retrieve secrets.
  public typealias Fetcher = Fetcher

  /// The fetcher implementation used to retrieve secrets.
  public var fetcher: Fetcher

  /// Creates a new basic provider.
  /// - Parameter fetcher: The fetcher implementation to use.
  public init(fetcher: Fetcher) { self.fetcher = fetcher }
}

/// Basic provider implementation for sources that conform to DecodableWithConfiguration.
///
/// This provides a standard implementation for providers where the source requires configuration during decoding.
public struct BasicProviderDecodableWithConfigurationSource<
  Source: SecretSourceProtocol & DecodableWithConfiguration,
  Fetcher: SecretFetcherProtocol
> where Fetcher.Source == Source, Source.Configuration: Decodable {
  /// The source type handled by this provider.
  public typealias Source = Source
  /// The fetcher type used to retrieve secrets.
  public typealias Fetcher = Fetcher

  /// The fetcher implementation used to retrieve secrets.
  public var fetcher: Fetcher

  /// Creates a new basic provider.
  /// - Parameter fetcher: The fetcher implementation to use.
  public init(fetcher: Fetcher) { self.fetcher = fetcher }
}
