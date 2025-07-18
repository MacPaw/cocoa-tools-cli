extension ImportSecrets.Providers.OnePassword {
  /// Represents a specific secret source within 1Password.
  /// This defines the vault, item, and field label needed to locate a secret.
  public struct Source {
    /// The account shorthand, sign-in address, account ID, or user ID.
    public var account: String?
    /// The vault name or ID. If nil, searches all accessible vaults.
    public var vault: String?

    /// The item name or ID containing the secret.
    public var item: String
    /// The field label within the item that contains the secret value.
    public var label: String

    /// Creates a new 1Password source.
    /// - Parameters:
    ///   - account: Optional account shorthand, sign-in address, account ID, or user ID.
    ///   - vault: Optional vault name or ID. If nil, searches all accessible vaults.
    ///   - item: The item name or ID containing the secret.
    ///   - label: The field label within the item that contains the secret value.
    public init(account: String? = .none, vault: String? = .none, item: String, label: String) {
      self.account = account
      self.vault = vault
      self.item = item
      self.label = label
    }
  }
}

private typealias Source = ImportSecrets.Providers.OnePassword.Source

extension Source: Equatable {}
extension Source: Decodable {}
extension Source: Sendable {}

extension Source: SecretSourceProtocol {
  public static let configurationKey: String = "op"

  public mutating func validate(with configuration: Configuration?) throws {
    account = account ?? configuration?.account
    vault = vault ?? configuration?.vault
  }
}
