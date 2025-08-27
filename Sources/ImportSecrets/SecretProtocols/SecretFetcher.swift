import Foundation

/// Result structure for secret fetching operations.
///
/// Contains both successfully fetched secrets and any errors that occurred during fetching.
public struct SecretsFetchResult {
  /// Dictionary mapping environment variable names to their fetched secret values.
  public var fetchedSecrets: [String: String]
  /// Dictionary mapping environment variable names to arrays of errors that occurred during fetching.
  public var errors: [String: [Swift.Error]]

  /// Creates a new fetch result.
  /// - Parameters:
  ///   - fetchedSecrets: Dictionary of successfully fetched secrets. Defaults to empty.
  ///   - errors: Dictionary of errors that occurred during fetching. Defaults to empty.
  public init(fetchedSecrets: [String: String] = [:], errors: [String: [Swift.Error]] = [:]) {
    self.fetchedSecrets = fetchedSecrets
    self.errors = errors
  }
}

/// Protocol that describes a secret fetcher type.
///
/// A secret fetcher is responsible for actually retrieving secret values from a provider
/// using the specified sources and configuration.
public protocol SecretFetcherProtocol: Sendable {
  /// The type of secret source this fetcher can work with.
  associatedtype Source: SecretSourceProtocol

  /// Fetches secrets from the provider using the specified sources and configuration.
  /// - Parameters:
  ///   - secrets: A dictionary mapping environment variable names to their corresponding secret sources.
  ///   - sourceConfiguration: Optional configuration for the secret source provider.
  /// - Returns: A dictionary mapping environment variable names to their secret values.
  /// - Throws: An error if fetching fails.
  func fetch(secrets: [String: Source], sourceConfiguration: Source.Configuration?) async throws -> SecretsFetchResult
}

extension ImportSecrets {
  /// Namespace for secret fetcher implementations.
  public enum SecretFetchers {}
}
