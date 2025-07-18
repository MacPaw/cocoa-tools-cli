extension ImportSecrets.Providers.OnePassword.Source {
  /// Configuration for the 1Password provider.
  /// This defines default settings that apply to all secrets from this provider.
  public struct Configuration {
    /// Default account shorthand, sign-in address, account ID, or user ID.
    public var account: String?

    /// Default vault name or ID to use when sources don't specify one.
    public var vault: String?

    /// Creates a new 1Password configuration.
    /// - Parameters:
    ///   - account: Optional default account shorthand, sign-in address, account ID, or user ID.
    ///   - vault: Optional default vault name or ID.
    public init(account: String? = nil, vault: String? = nil) {
      self.account = account
      self.vault = vault
    }
  }
}

private typealias Configuration = ImportSecrets.Providers.OnePassword.Source.Configuration

extension Configuration: Equatable {}
extension Configuration: Decodable {}
extension Configuration: Sendable {}

extension Configuration: SecretConfigurationProtocol { public static let configurationKey: String = "op" }
