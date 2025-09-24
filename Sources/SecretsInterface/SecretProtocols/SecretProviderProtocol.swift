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

extension SecretProviderProtocol {
  @inlinable
  @inline(__always)
  static package var configurationKey: String { Source.configurationKey }
}

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
  ///   - secrets: A list of secrets source configurations to fetch.
  ///   - sourceConfiguration: Optional configuration to use for fetching.
  /// - Returns: Result containing successfully fetched secrets and any errors encountered.
  /// - Throws: Fetching errors if the operation fails.
  public func fetch(secrets: [Source], sourceConfiguration: Source.Configuration?) async throws -> [Source.Item:
    SecretsFetchResult]
  {
    guard let sourceConfiguration else { preconditionFailure("Cannot fetch without configuration") }

    var fetcher = fetcher

    try await fetcher.initialize(configuration: sourceConfiguration)

    let fetchResult = try await fetcher.fetch(secrets: secrets, sourceConfiguration: sourceConfiguration)

    return fetchResult
  }
}

// MARK: - Type-erased method signatures

extension SecretProviderProtocol {
  /// Gets a typed source configuration from a type-erased configuration.
  /// - Parameters:
  ///   - configuration: The type-erased configuration to cast.
  ///   - type: The expected configuration type.
  /// - Returns: The typed configuration if the cast succeeds, nil if the input is nil.
  /// - Throws: SecretsInterface.Error.configurationTypeMismatch if the configuration has the wrong type.
  package static func getSourceConfiguration<T: SecretConfigurationProtocol>(
    _ configuration: (any SecretConfigurationProtocol)?,
    is type: T.Type = T.self,
  ) throws -> T? {
    guard let configuration else { return nil }
    guard let typedConfiguration = configuration as? T else {
      throw SecretsInterface.Error.configurationTypeMismatch(expected: type, got: Swift.type(of: configuration))
    }
    return typedConfiguration
  }

  /// Type-erased source decoding - converts from any secret configuration protocol to specific Source type.
  package func decodeSource(from decoder: any Decoder, sourceConfiguration: (any SecretConfigurationProtocol)?) throws
    -> any SecretSourceProtocol
  {
    // Cast the type-erased configuration and delegate to typed decoding
    let sourceConfiguration: Source.Configuration? = try Self.getSourceConfiguration(sourceConfiguration)
    let source: Source = try decodeSource(from: decoder, sourceConfiguration: sourceConfiguration)
    return source
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
  Fetcher: SecretFetcherProtocol,
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
