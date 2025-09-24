import Foundation

/// Result structure for secret fetching operations.
///
/// Contains both successfully fetched secrets and any errors that occurred during fetching.
public struct SecretsFetchResult {
  /// Dictionary mapping environment variable names to their fetched secret values.
  public var fetchedSecrets: [String: String]
  /// Dictionary mapping environment variable names to arrays of errors that occurred during fetching.
  public var errors: [String: [any Swift.Error]]

  /// Creates a new fetch result.
  /// - Parameters:
  ///   - fetchedSecrets: Dictionary of successfully fetched secrets. Defaults to empty.
  ///   - errors: Dictionary of errors that occurred during fetching. Defaults to empty.
  public init(fetchedSecrets: [String: String] = [:], errors: [String: [any Swift.Error]] = [:]) {
    self.fetchedSecrets = fetchedSecrets
    self.errors = errors
  }
}

extension SecretsFetchResult: Sendable {}

/// Protocol that describes a secret fetcher type.
///
/// A secret fetcher is responsible for actually retrieving secret values from a provider
/// using the specified sources and configuration.
public protocol SecretFetcherProtocol: Sendable {
  /// The type of secret source this fetcher can work with.
  associatedtype Source: SecretSourceProtocol

  /// Initializes fetcher before fetching secrets with a given `configuration`.
  ///
  /// - Parameter configuration: A Secret Configuration to init this fetcher with.
  ///
  /// - Throws: An error if initialization failed.
  mutating func initialize(configuration: Source.Configuration) async throws

  /// Fetches a single source item.
  /// - Parameters:
  ///   - item: A unique source item.
  ///   - keys: A set of keys to fetch. If set is empty it will fetch all keys from a given `item`.
  ///   - configuration: A source configuration to use when fetching secrets.
  ///
  /// - Note: There is no need to filter fetched secrets by passed keys in the implementation.
  ///
  /// - Returns: A map where secret name is a key, and secret value is a value.
  /// - Throws: If error occurred during item fetch.
  func fetchItem(_ item: Source.Item, keys: Set<String>, configuration: Source.Configuration) throws -> [String:
    String]
}

/// A secret fetcher is responsible for actually retrieving secret values from a provider
/// using the specified sources and configuration.
public protocol SecretFetcherAsyncProtocol: SecretFetcherProtocol {
  /// Initializes fetcher before fetching secrets with a given `configuration`.
  ///
  /// - Parameter configuration: A Secret Configuration to init this fetcher with.
  ///
  /// - Throws: An error if initialization failed.
  mutating func initialize(configuration: Source.Configuration) async throws

  /// Fetches a single source item.
  /// - Parameters:
  ///   - item: A unique source item.
  ///   - keys: A set of keys to fetch. If set is empty it will fetch all keys from a given `item`.
  ///   - configuration: A source configuration to use when fetching secrets.
  ///
  /// - Note: There is no need to filter fetched secrets by passed keys in the implementation.
  ///
  /// - Returns: A map where secret name is a key, and secret value is a value.
  /// - Throws: If error occurred during item fetch.
  func fetchItem(_ item: Source.Item, keys: Set<String>, configuration: Source.Configuration) async throws -> [String:
    String]
}

extension SecretFetcherAsyncProtocol {
  public func fetchItem(_ item: Source.Item, keys: Set<String>, configuration: Source.Configuration) throws -> [String : String] {
    throw SecretsInterface.Error.syncFetchNotSupported
  }
}

extension SecretFetcherProtocol {
  func convertFetchedSecretsToResult(fetchedSecrets: [String: String], keys: Set<String>) -> SecretsFetchResult {

    var fetchedSecrets = fetchedSecrets

    var result: SecretsFetchResult = .init()

    // If keys not empty
    if !keys.isEmpty {
      // Get only required keys
      fetchedSecrets = fetchedSecrets.filter { keys.contains($0.key) }

      // Check if the key fetched
      let missingKeys = keys.filter { !fetchedSecrets.keys.contains($0) }
      for missingKey in missingKeys {
        result.errors[missingKey, default: []].append(SecretsInterface.Error.missingSecrets([missingKey]))
      }

      // Check if the value is not empty
      let emptyKeys =
        fetchedSecrets.filter { key, value in value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .keys
      for emptyKey in emptyKeys {
        result.errors[emptyKey, default: []].append(SecretsInterface.Error.emptySecrets([emptyKey]))
      }
    }

    result.fetchedSecrets = fetchedSecrets

    return result
  }

  func fetchItem(_ item: Source.Item, keys: Set<String>, configuration: Source.Configuration) throws -> (Source.Item, SecretsFetchResult) {
      let fetchedSecrets: [String: String] = try self.fetchItem(
        item,
        keys: keys,
        configuration: configuration
      )

      let result: SecretsFetchResult = convertFetchedSecretsToResult(fetchedSecrets: fetchedSecrets, keys: keys)

      return (item, result)
  }

  /// Fetches secrets from the provider using the specified sources and configuration.
  /// - Parameters:
  ///   - secrets: A list of secrets source configurations to fetch.
  ///   - sourceConfiguration: Optional configuration for the secret source provider.
  /// - Returns: A dictionary mapping of the secrets fetch result to the source item.
  /// - Throws: An error if fetching fails.
  public func fetch(secrets: [Source], sourceConfiguration: Source.Configuration?) throws -> [Source.Item:
    SecretsFetchResult]
  {
    guard let sourceConfiguration else { preconditionFailure("No source configuration provided.") }

    // Group secrets by unique item (vault + item name) to batch field requests.
    // This optimization allows us to fetch multiple fields from the same item in one API call
    // instead of making separate calls for each field.
    let itemsToFetch: [Source.Item: Set<String>] = secrets.itemsToFetch

    var itemFetchResults: [(Source.Item, SecretsFetchResult)] = []
    for (item, keys) in itemsToFetch {
      let itemFetchResult: (Source.Item, SecretsFetchResult) = {
        do {
          return try self.fetchItem(item, keys: keys, configuration: sourceConfiguration)
        }
        catch { return (item, SecretsFetchResult(errors: ["all keys": [error]])) }
      }()
      itemFetchResults.append(itemFetchResult)
    }

    let uniqueFetchedResult: [Source.Item: SecretsFetchResult] = try itemFetchResults.reduce(into: [Source.Item: SecretsFetchResult]()) { partialResult, itemResult in
      let item: Source.Item
      let result: SecretsFetchResult
      (item, result) = itemResult
      try partialResult[item, default: SecretsFetchResult()].addFetchedSecrets(result.fetchedSecrets)
      partialResult[item, default: SecretsFetchResult()].addErrors(result.errors)
    }

    return uniqueFetchedResult
  }
}

extension SecretFetcherAsyncProtocol {
  func fetchItem(_ item: Source.Item, keys: Set<String>, configuration: Source.Configuration) async throws -> (Source.Item, SecretsFetchResult) {
      let fetchedSecrets: [String: String] = try await self.fetchItem(
        item,
        keys: keys,
        configuration: configuration
      )

      let result: SecretsFetchResult = convertFetchedSecretsToResult(fetchedSecrets: fetchedSecrets, keys: keys)

      return (item, result)
  }
}

extension SecretFetcherAsyncProtocol {
  /// Fetches secrets from the provider using the specified sources and configuration.
  /// - Parameters:
  ///   - secrets: A list of secrets source configurations to fetch.
  ///   - sourceConfiguration: Optional configuration for the secret source provider.
  /// - Returns: A dictionary mapping of the secrets fetch result to the source item.
  /// - Throws: An error if fetching fails.
  public func fetch(secrets: [Source], sourceConfiguration: Source.Configuration?) async throws -> [Source.Item:
    SecretsFetchResult]
  {
    guard let sourceConfiguration else { preconditionFailure("No source configuration provided.") }

    // Group secrets by unique item (vault + item name) to batch field requests.
    // This optimization allows us to fetch multiple fields from the same item in one API call
    // instead of making separate calls for each field.
    let itemsToFetch: [Source.Item: Set<String>] = secrets.itemsToFetch

    let uniqueFetchedResult: [Source.Item: SecretsFetchResult] = try await withThrowingTaskGroup(
      of: (Source.Item, SecretsFetchResult).self,
      returning: [Source.Item: SecretsFetchResult].self
    ) { taskGroup in
      for (item, keys) in itemsToFetch {
        taskGroup.addTask { [self, item, keys] in
          do {
            return try await self.fetchItem(item, keys: keys, configuration: sourceConfiguration)
          }
          catch { return (item, .init(errors: ["all keys": [error]])) }
        }
      }

      return try await taskGroup.reduce(into: [Source.Item: SecretsFetchResult]()) { partialResult, itemResult in
        let item: Source.Item
        let result: SecretsFetchResult
        (item, result) = itemResult
        try partialResult[item, default: .init()].addFetchedSecrets(result.fetchedSecrets)
        partialResult[item, default: .init()].addErrors(result.errors)
      }
    }

    return uniqueFetchedResult
  }
}

extension SecretsFetchResult {
  package mutating func addFetchedSecrets(_ fetchedSecrets: [String: String]) throws {
    for (secretKey, value) in fetchedSecrets {
      guard self.fetchedSecrets[secretKey] == nil else { fatalError("Duplicate secret key: \(secretKey)") }
      self.fetchedSecrets[secretKey] = value
    }
  }

  package mutating func addErrors(_ errors: [String: [any Swift.Error]]) {
    for (secretKey, errors) in errors { self.errors[secretKey, default: []].append(contentsOf: errors) }
  }
}
