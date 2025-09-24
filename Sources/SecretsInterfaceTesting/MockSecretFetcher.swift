import SecretsInterface

/// Mock implementation of `SecretFetcherProtocol` for testing purposes.
///
/// This mock provides configurable behavior for testing secret fetching scenarios.
public struct MockSecretFetcher: SecretFetcherProtocol {
  /// The type of secret source this fetcher can work with.
  public typealias Source = MockSecretSource

  /// Configuration used for initialization tracking.
  public private(set) var initializedConfiguration: Source.Configuration?

  /// Flag to control whether initialization should throw an error.
  public var shouldFailInitialization: Bool

  /// Custom initialization error to throw when initialization fails.
  public var initializationError: String?

  /// Predefined secrets to return during fetch operations.
  /// Key is the item ID, value is a dictionary of secret key-value pairs.
  public var predefinedSecrets: [String: [String: String]]

  /// Flag to control whether fetching should throw an error.
  public var shouldFailFetch: Bool

  /// Custom fetch error to throw when fetching fails.
  public var fetchError: String?

  /// Tracks all fetch calls made to this fetcher.
  public private(set) var fetchCalls: [(item: Source.Item, keys: Set<String>, configuration: Source.Configuration)]

  /// Creates a new mock secret fetcher.
  ///
  /// - Parameters:
  ///   - shouldFailInitialization: Whether initialization should fail. Defaults to `false`.
  ///   - initializationError: Custom error message to throw during initialization.
  ///   - predefinedSecrets: Secrets to return during fetch operations. Defaults to empty.
  ///   - shouldFailFetch: Whether fetching should fail. Defaults to `false`.
  ///   - fetchError: Custom error message to throw during fetch operations.
  public init(
    shouldFailInitialization: Bool = false,
    initializationError: String? = nil,
    predefinedSecrets: [String: [String: String]] = [:],
    shouldFailFetch: Bool = false,
    fetchError: String? = nil
  ) {
    self.shouldFailInitialization = shouldFailInitialization
    self.initializationError = initializationError
    self.predefinedSecrets = predefinedSecrets
    self.shouldFailFetch = shouldFailFetch
    self.fetchError = fetchError
    self.fetchCalls = []
  }

  /// Initializes fetcher before fetching secrets with a given configuration.
  ///
  /// - Parameter configuration: A Secret Configuration to init this fetcher with.
  /// - Throws: The configured initialization error if `shouldFailInitialization` is `true`.
  public mutating func initialize(configuration: Source.Configuration) async throws {
    if shouldFailInitialization {
      guard let initializationError else { throw MockError.initializationFailed }
      throw MockError.initializationFailedWithMessage(initializationError)
    }
    initializedConfiguration = configuration
  }

  /// Fetches a single source item.
  ///
  /// - Parameters:
  ///   - item: A unique source item.
  ///   - keys: A set of keys to fetch. If set is empty it will fetch all keys from a given item.
  ///   - configuration: A source configuration to use when fetching secrets.
  /// - Returns: A map where secret name is a key, and secret value is a value.
  /// - Throws: The configured fetch error if `shouldFailFetch` is `true`.
  public func fetchItem(_ item: Source.Item, keys: Set<String>, configuration: Source.Configuration) throws -> [String:
    String]
  {
    // Note: In a real implementation, we'd track this call
    // For simplicity in this mock, we skip call tracking in the non-mutating version

    if shouldFailFetch {
      guard let fetchError else { throw MockError.fetchFailed }
      throw MockError.fetchFailedWithMessage(fetchError)
    }

    let itemSecrets = predefinedSecrets[item.id] ?? [:]

    // If no specific keys requested, return all secrets for the item
    if keys.isEmpty { return itemSecrets }

    // Filter to only requested keys
    return itemSecrets.filter { keys.contains($0.key) }
  }
}

extension MockSecretFetcher {
  /// Errors that can be thrown by the mock fetcher.
  public enum MockError: Error, Equatable {
    case initializationFailed
    case initializationFailedWithMessage(String)
    case fetchFailed
    case fetchFailedWithMessage(String)
  }

  /// Factory method for creating a fetcher with predefined secrets.
  public static func withSecrets(_ secrets: [String: [String: String]]) -> MockSecretFetcher {
    MockSecretFetcher(predefinedSecrets: secrets)
  }

  /// Factory method for creating a fetcher that will fail initialization.
  public static func failingInitialization(errorMessage: String? = nil) -> MockSecretFetcher {
    MockSecretFetcher(shouldFailInitialization: true, initializationError: errorMessage)
  }

  /// Factory method for creating a fetcher that will fail fetch operations.
  public static func failingFetch(errorMessage: String? = nil) -> MockSecretFetcher {
    MockSecretFetcher(shouldFailFetch: true, fetchError: errorMessage)
  }

  /// Resets the fetcher's state for reuse in tests.
  public mutating func reset() {
    initializedConfiguration = nil
    fetchCalls = []
  }
}
