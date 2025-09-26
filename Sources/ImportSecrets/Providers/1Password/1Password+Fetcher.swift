import SecretsInterface
import Shell

extension ImportSecrets.Providers.OnePassword {
  /// Fetcher implementation for retrieving secrets from 1Password.
  ///
  /// This handles the actual communication with the 1Password CLI and manages
  /// batching of requests for efficiency.
  public struct Fetcher {
    /// The 1Password CLI implementation to use for fetching secrets.
    public var onePasswordCLI: (any OnePasswordCLIProtocol)?

    /// Creates a new 1Password fetcher.
    /// - Parameter onePasswordCLI: Optional 1Password CLI implementation. If nil, uses the system CLI.
    public init(onePasswordCLI: (any OnePasswordCLIProtocol)? = .none) { self.onePasswordCLI = onePasswordCLI }
  }
}

private typealias Fetcher = ImportSecrets.Providers.OnePassword.Fetcher

extension Fetcher: Sendable {}

extension Fetcher: SecretFetcherProtocol {
  /// Initializes fetcher before fetching secrets with a given `configuration`.
  ///
  /// No-op.
  ///
  /// - Parameter configuration: A Secret Configuration to init this fetcher with.
  ///
  /// - Throws: An error if initialization failed.
  public mutating func initialize(configuration: ImportSecrets.Providers.OnePassword.Source.Configuration?) async throws
  {}

  /// Fetch a single item from 1Password.
  ///
  /// - Parameters:
  ///   - item: A secret item to fetch.
  ///   - keys: A list of secrets to fetch.
  ///   - configuration: The configuration to use for default values.
  /// - Returns: Dictionary mapping secret names to their values.
  /// - Throws: An error if fetching with CLI failed.
  public func fetchItem(
    _ item: ImportSecrets.Providers.OnePassword.Source.Item,
    keys: Set<String>,
    configuration: ImportSecrets.Providers.OnePassword.Source.Configuration
  ) throws -> [String: String] {
    // Get the 1Password CLI instance (injected for testing or default system CLI)
    let onePasswordCLI = try self.onePasswordCLI ?? Shell.OnePassword()

    return try onePasswordCLI.getItemFields(
      account: item.account,
      vault: item.vault,
      item: item.item,
      labels: keys.map(\.self),
    )
  }

  /// Source type for 1Password fetcher.
  public typealias Source = ImportSecrets.Providers.OnePassword.Source

  /// Fetches secrets from 1Password using the configured CLI.
  ///
  /// - Parameters:
  ///   - secrets: Dictionary mapping secret names to their 1Password source configurations.
  ///   - sourceConfiguration: Optional configuration containing default account and vault settings.
  /// - Returns: Result containing successfully fetched secrets and any errors encountered.
  /// - Throws: Shell.Error if the 1Password CLI cannot be initialized or configured.
  //  public func fetch(
  //    secrets: [String: ImportSecrets.Providers.OnePassword.Source],
  //    sourceConfiguration: ImportSecrets.Providers.OnePassword.Source.Configuration?,
  //  ) async throws -> SecretsFetchResult {
  //    guard !secrets.isEmpty else { return .init() }
  //
  //    var result: SecretsFetchResult = .init()
  //
  //    // Group secrets by unique item (vault + item name) to batch field requests
  //    // This optimization allows us to fetch multiple fields from the same item in one API call
  //    // instead of making separate calls for each field
  //    let itemsToFetch: [Source.Item: Set<String>] = secrets.itemsToFetch
  //
  //    // Get the 1Password CLI instance (injected for testing or default system CLI)
  //    let onePasswordCLI = try self.onePasswordCLI ?? Shell.OnePassword()
  //
  //    // Track errors and successful fetches for each unique item
  //    var notFetchedItemErrors: [Source.Item: any Swift.Error] = [:]
  //    var opFetchedItems: [Source.Item: [String: String]] = [:]
  //
  //    // Fetch all required fields for each unique item in a single API call
  //    for item in itemsToFetch {
  //      let uniqueItem = item.key
  //      let labels = item.value.sorted()  // Sort for consistent API calls
  //
  //      do {
  //        // Single API call to fetch multiple fields from the same item
  //        let fieldValues: [String: String] = try onePasswordCLI.getItemFields(
  //          account: uniqueItem.account,
  //          vault: uniqueItem.vault,
  //          item: uniqueItem.item,
  //          labels: labels,
  //        )
  //
  //        opFetchedItems[uniqueItem] = fieldValues
  //      }
  //      catch { notFetchedItemErrors[uniqueItem] = error }
  //    }
  //
  //    // Now map the fetched item data back to individual secrets
  //    // Each secret corresponds to one field from one item
  //    for (secretKey, secret) in secrets {
  //      let uniqueItem: Source.Item = secret.item
  //
  //      // Check if we successfully fetched data for this item
  //      guard let fetchedLabelValues = opFetchedItems[uniqueItem] else {
  //        // Item fetch failed - record the error for this secret
  //        if let error = notFetchedItemErrors[uniqueItem] { result.errors[secretKey, default: []].append(error) }
  //        continue
  //      }
  //
  //      if !secret.labels.isEmpty {
  //        for label in secret.keys {
  //          // Check if the specific field/label was found in the item
  //          guard let fetchedValue = fetchedLabelValues[label] else {
  //            // Item was fetched but this specific field wasn't found
  //            result.errors[secretKey, default: []]
  //              .append(FetchError.failedToFetch(secret: secretKey, labelMissing: label))
  //            continue
  //          }
  //
  //          if secret.labels.count == 1 {
  //            // Success - store the secret value
  //            result.fetchedSecrets[secretKey] = fetchedValue
  //          } else {
  //            // Success - store the secret value
  //            result.fetchedSecrets["\(secretKey)_\(label)".normalizedSecretName()] = fetchedValue
  //          }
  //        }
  //      } else {
  //        for (label, fetchedValue) in fetchedLabelValues {
  //          result.fetchedSecrets["\(secretKey)_\(label)".normalizedSecretName()] = fetchedValue
  //        }
  //      }
  //
  //    }
  //
  //    return result
  //  }
  //
  //  enum FetchError: Error { case failedToFetch(secret: String, labelMissing: String) }
}

extension String { func normalizedSecretName() -> String { replacing(/[^0-9a-zA-Z]+/) { _ in "_" } } }
