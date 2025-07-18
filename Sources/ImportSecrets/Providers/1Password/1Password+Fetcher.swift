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

extension Fetcher {
  /// Represents a unique 1Password item (vault + item name combination).
  ///
  /// Used to group multiple field requests for the same item to optimize API calls.
  private struct UniqueItem: Equatable, Hashable {
    var account: String?
    var vault: String?
    var item: String

    init(account: String? = nil, vault: String? = nil, item: String) {
      self.account = account
      self.vault = vault
      self.item = item
    }

    /// Creates a UniqueItem from a source, applying default account and vault if needed.
    init(source: ImportSecrets.Providers.OnePassword.Source, defaultAccount: String?, defaultVault: String?) {
      self.account = source.account ?? defaultAccount
      self.vault = source.vault ?? defaultVault
      self.item = source.item
    }
  }
}

extension Fetcher: Sendable {}

extension Fetcher: SecretFetcherProtocol {
  /// Source type for 1Password fetcher.
  public typealias Source = ImportSecrets.Providers.OnePassword.Source

  /// Fetches secrets from 1Password using the configured CLI.
  ///
  /// - Parameters:
  ///   - secrets: Dictionary mapping secret names to their 1Password source configurations.
  ///   - sourceConfiguration: Optional configuration containing default account and vault settings.
  /// - Returns: Result containing successfully fetched secrets and any errors encountered.
  /// - Throws: Shell.Error if the 1Password CLI cannot be initialized or configured.
  public func fetch(
    secrets: [String: ImportSecrets.Providers.OnePassword.Source],
    sourceConfiguration: ImportSecrets.Providers.OnePassword.Source.Configuration?,
  ) async throws -> SecretsFetchResult {
    guard !secrets.isEmpty else { return .init() }

    var result: SecretsFetchResult = .init()

    // Group secrets by unique item (vault + item name) to batch field requests
    // This optimization allows us to fetch multiple fields from the same item in one API call
    // instead of making separate calls for each field
    let itemsToFetch: [UniqueItem: Set<String>] = secrets.values.reduce(into: [:]) { accum, opSource in
      let uniqueItem: UniqueItem = .init(
        source: opSource,
        defaultAccount: sourceConfiguration?.account,
        defaultVault: sourceConfiguration?.vault,
      )
      accum[uniqueItem, default: []].insert(opSource.label)
    }

    // Get the 1Password CLI instance (injected for testing or default system CLI)
    let onePasswordCLI = try self.onePasswordCLI ?? Shell.OnePassword()

    // Track errors and successful fetches for each unique item
    var notFetchedItemErrors: [UniqueItem: any Swift.Error] = [:]
    var opFetchedItems: [UniqueItem: [String: String]] = [:]

    // Fetch all required fields for each unique item in a single API call
    for item in itemsToFetch {
      let uniqueItem = item.key
      let labels = item.value.sorted()  // Sort for consistent API calls

      do {
        // Single API call to fetch multiple fields from the same item
        let fieldValues: [String: String] = try onePasswordCLI.getItemFields(
          account: uniqueItem.account,
          vault: uniqueItem.vault,
          item: uniqueItem.item,
          labels: labels,
        )

        opFetchedItems[uniqueItem] = fieldValues
      }
      catch { notFetchedItemErrors[uniqueItem] = error }
    }

    // Now map the fetched item data back to individual secrets
    // Each secret corresponds to one field from one item
    for secret in secrets {
      let uniqueItem: UniqueItem = .init(
        source: secret.value,
        defaultAccount: sourceConfiguration?.account,
        defaultVault: sourceConfiguration?.vault,
      )

      // Check if we successfully fetched data for this item
      guard let fetchedLabelValues = opFetchedItems[uniqueItem] else {
        // Item fetch failed - record the error for this secret
        if let error = notFetchedItemErrors[uniqueItem] { result.errors[secret.key, default: []].append(error) }
        continue
      }

      // Check if the specific field/label was found in the item
      guard let fetchedValue = fetchedLabelValues[secret.value.label] else {
        // Item was fetched but this specific field wasn't found
        result.errors[secret.key, default: []]
          .append(FetchError.failedToFetch(secret: secret.key, labelMissing: secret.value.label))
        continue
      }

      // Success - store the secret value
      result.fetchedSecrets[secret.key] = fetchedValue
    }

    return result
  }

  enum FetchError: Error { case failedToFetch(secret: String, labelMissing: String) }
}
