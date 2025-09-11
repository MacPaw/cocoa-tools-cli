extension HashiCorpVaultReader.Configuration {
  /// Authentication credentials for vault access.
  public struct AuthenticationCredentials {
    /// Token-based authentication credentials.
    public var token: Token?
    /// AppRole-based authentication credentials.
    public var appRole: AppRole?

    /// Initialize authentication credentials.
    ///
    /// - Parameters:
    ///   - token: Optional token credentials.
    ///   - appRole: Optional AppRole credentials.
    public init(token: Token? = nil, appRole: AppRole? = nil) {
      self.token = token
      self.appRole = appRole
    }
  }
}

extension HashiCorpVaultReader.Configuration {
  /// Available authentication methods for vault access.
  public enum AuthenticationMethod: String {
    /// Token-based authentication.
    case token
    /// AppRole-based authentication.
    case appRole
  }
}

private typealias AuthenticationCredentials = HashiCorpVaultReader.Configuration.AuthenticationCredentials

private typealias AuthenticationMethod = HashiCorpVaultReader.Configuration.AuthenticationMethod
extension AuthenticationMethod: Decodable {}
extension AuthenticationMethod: Equatable {}
extension AuthenticationMethod: Sendable {}

extension AuthenticationCredentials: Decodable {}
extension AuthenticationCredentials: Equatable {}
extension AuthenticationCredentials: Sendable {}

extension AuthenticationCredentials {
  /// Token-based authentication credentials.
  public struct Token {
    /// The vault token for authentication.
    public var vaultToken: String

    /// Initialize token credentials.
    ///
    /// - Parameter vaultToken: The vault token.
    public init(vaultToken: String) { self.vaultToken = vaultToken }
  }
  /// AppRole-based authentication credentials.
  public struct AppRole {
    /// The role ID for AppRole authentication.
    public var roleId: String
    /// The secret ID for AppRole authentication.
    public var secretId: String

    /// Initialize AppRole credentials.
    ///
    /// - Parameters:
    ///   - roleId: The role ID.
    ///   - secretId: The secret ID.
    public init(roleId: String, secretId: String) {
      self.roleId = roleId
      self.secretId = secretId
    }
  }
}

extension AuthenticationCredentials.Token: Decodable {}
extension AuthenticationCredentials.Token: Equatable {}
extension AuthenticationCredentials.Token: Sendable {}

extension AuthenticationCredentials.AppRole: Decodable {}
extension AuthenticationCredentials.AppRole: Equatable {}
extension AuthenticationCredentials.AppRole: Sendable {}
