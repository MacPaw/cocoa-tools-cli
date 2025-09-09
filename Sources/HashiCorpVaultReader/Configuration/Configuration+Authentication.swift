extension HashiCorpVaultReader.Configuration {
  public struct AuthenticationCredentials {
    public var token: Token?
    public var appRole: AppRole?

    public init(token: Token? = nil, appRole: AppRole? = nil) {
      self.token = token
      self.appRole = appRole
    }
  }
}

extension HashiCorpVaultReader.Configuration {
  public enum AuthenticationMethod: String {
    case token
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
  public struct Token {
    public var vaultToken: String

    public init(vaultToken: String) { self.vaultToken = vaultToken }
  }
  public struct AppRole {
    public var roleId: String
    public var secretId: String

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
