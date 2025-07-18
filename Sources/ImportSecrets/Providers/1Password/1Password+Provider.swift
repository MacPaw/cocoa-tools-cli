extension ImportSecrets.Providers {
  /// 1Password secret provider implementation.
  /// This provider integrates with the 1Password CLI to fetch secrets from 1Password vaults.
  public struct OnePassword {
    /// The fetcher implementation used to retrieve secrets from 1Password.
    public let fetcher: Fetcher

    /// Creates a new 1Password provider.
    /// - Parameter fetcher: The fetcher implementation to use. Defaults to a new Fetcher instance.
    public init(fetcher: Fetcher = Fetcher(onePasswordCLI: .none)) { self.fetcher = fetcher }
  }
}

extension ImportSecrets.Providers.OnePassword: SecretProviderProtocol {}
