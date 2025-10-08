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
  /// Source type for 1Password fetcher.
  public typealias Source = ImportSecrets.Providers.OnePassword.Source

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
}

extension String { func normalizedSecretName() -> String { replacing(/[^0-9a-zA-Z]+/) { _ in "_" } } }
