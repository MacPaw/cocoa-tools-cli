import Foundation
import SecretsInterface

/// Mock implementation of `SecretProviderProtocol` for testing purposes.
///
/// This mock provides configurable behavior for testing secret provider scenarios.
public struct MockSecretProvider: SecretProviderProtocol {
  /// The source type handled by this provider.
  public typealias Source = MockSecretSource
  /// The fetcher type used to retrieve secrets.
  public typealias Fetcher = MockSecretFetcher

  /// The fetcher implementation for this provider.
  public var fetcher: Fetcher

  /// Flag to control whether source decoding should throw an error.
  public var shouldFailSourceDecoding: Bool

  /// Custom source decoding error to throw when source decoding fails.
  public var sourceDecodingError: String?

  /// Flag to control whether configuration decoding should throw an error.
  public var shouldFailConfigurationDecoding: Bool

  /// Custom configuration decoding error to throw when configuration decoding fails.
  public var configurationDecodingError: String?

  /// Predefined source to return during decoding.
  public var predefinedSource: Source?

  /// Predefined configuration to return during decoding.
  public var predefinedConfiguration: Source.Configuration?

  /// Tracks all source decoding calls made to this provider.
  public private(set) var sourceDecodingCalls: [(decoder: String, sourceConfiguration: Source.Configuration?)]

  /// Tracks all configuration decoding calls made to this provider.
  public private(set) var configurationDecodingCalls: [String]

  /// Initialize the provider with a fetcher (required by protocol).
  /// - Parameter fetcher: The fetcher implementation to use for retrieving secrets.
  public init(fetcher: Fetcher) {
    self.fetcher = fetcher
    self.shouldFailSourceDecoding = false
    self.sourceDecodingError = nil
    self.shouldFailConfigurationDecoding = false
    self.configurationDecodingError = nil
    self.predefinedSource = nil
    self.predefinedConfiguration = nil
    self.sourceDecodingCalls = []
    self.configurationDecodingCalls = []
  }

  /// Creates a new mock secret provider with additional configuration.
  ///
  /// - Parameters:
  ///   - fetcher: The fetcher implementation to use for retrieving secrets.
  ///   - shouldFailSourceDecoding: Whether source decoding should fail. Defaults to `false`.
  ///   - sourceDecodingError: Custom error message to throw during source decoding.
  ///   - shouldFailConfigurationDecoding: Whether configuration decoding should fail. Defaults to `false`.
  ///   - configurationDecodingError: Custom error message to throw during configuration decoding.
  ///   - predefinedSource: Source to return during decoding. If `nil`, creates a default source.
  ///   - predefinedConfiguration: Configuration to return during decoding. If `nil`, creates a default configuration.
  public init(
    fetcher: Fetcher = MockSecretFetcher(),
    shouldFailSourceDecoding: Bool = false,
    sourceDecodingError: String? = nil,
    shouldFailConfigurationDecoding: Bool = false,
    configurationDecodingError: String? = nil,
    predefinedSource: Source? = nil,
    predefinedConfiguration: Source.Configuration? = nil
  ) {
    self.fetcher = fetcher
    self.shouldFailSourceDecoding = shouldFailSourceDecoding
    self.sourceDecodingError = sourceDecodingError
    self.shouldFailConfigurationDecoding = shouldFailConfigurationDecoding
    self.configurationDecodingError = configurationDecodingError
    self.predefinedSource = predefinedSource
    self.predefinedConfiguration = predefinedConfiguration
    self.sourceDecodingCalls = []
    self.configurationDecodingCalls = []
  }

  /// Decode source from decoder.
  ///
  /// - Parameters:
  ///   - decoder: The decoder to read the source configuration from.
  ///   - sourceConfiguration: Optional configuration to use during decoding.
  /// - Returns: The decoded secret source.
  /// - Throws: The configured source decoding error if `shouldFailSourceDecoding` is `true`.
  public func decodeSource(from decoder: any Decoder, sourceConfiguration: Source.Configuration?) throws -> Source {
    // Note: In a real implementation, we'd track this call
    // For simplicity in this mock, we skip call tracking in the non-mutating version

    if shouldFailSourceDecoding {
      guard let sourceDecodingError else { throw MockError.sourceDecodingFailed }
      throw MockError.sourceDecodingFailedWithMessage(sourceDecodingError)
    }

    return predefinedSource ?? MockSecretSource()
  }

  /// Decode configuration from decoder.
  ///
  /// - Parameter decoder: The decoder to read the configuration from.
  /// - Returns: The decoded source configuration.
  /// - Throws: The configured configuration decoding error if `shouldFailConfigurationDecoding` is `true`.
  public func decodeConfiguration(from decoder: any Decoder) throws -> Source.Configuration {
    // Note: In a real implementation, we'd track this call
    // For simplicity in this mock, we skip call tracking in the non-mutating version

    if shouldFailConfigurationDecoding {
      guard let configurationDecodingError else { throw MockError.configurationDecodingFailed }
      throw MockError.configurationDecodingFailedWithMessage(configurationDecodingError)
    }

    return predefinedConfiguration ?? MockSecretConfiguration()
  }
}

extension MockSecretProvider {
  /// Errors that can be thrown by the mock provider.
  public enum MockError: Error, Equatable {
    case sourceDecodingFailed
    case sourceDecodingFailedWithMessage(String)
    case configurationDecodingFailed
    case configurationDecodingFailedWithMessage(String)
  }

  /// Factory method for creating a provider with a specific fetcher.
  public static func withFetcher(_ fetcher: Fetcher) -> MockSecretProvider { MockSecretProvider(fetcher: fetcher) }

  /// Factory method for creating a provider that will fail source decoding.
  public static func failingSourceDecoding(errorMessage: String? = nil) -> MockSecretProvider {
    MockSecretProvider(shouldFailSourceDecoding: true, sourceDecodingError: errorMessage)
  }

  /// Factory method for creating a provider that will fail configuration decoding.
  public static func failingConfigurationDecoding(errorMessage: String? = nil) -> MockSecretProvider {
    MockSecretProvider(shouldFailConfigurationDecoding: true, configurationDecodingError: errorMessage)
  }

  /// Factory method for creating a provider with predefined responses.
  public static func withPredefined(
    source: Source? = nil,
    configuration: Source.Configuration? = nil,
    fetcher: Fetcher = MockSecretFetcher()
  ) -> MockSecretProvider {
    MockSecretProvider(fetcher: fetcher, predefinedSource: source, predefinedConfiguration: configuration)
  }

  /// Resets the provider's state for reuse in tests.
  public mutating func reset() {
    sourceDecodingCalls = []
    configurationDecodingCalls = []
    fetcher.reset()
  }
}
