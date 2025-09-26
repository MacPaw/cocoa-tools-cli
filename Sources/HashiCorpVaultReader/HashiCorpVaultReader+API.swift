import Foundation
import SharedLogger

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif


/// Protocol for HashiCorp Vault engine get secrets result.
public protocol HashiCorpVaultEngineGetSecretsResultProtocol: Decodable {
  /// The secrets dictionary containing key-value pairs.
  var secrets: [String: String] { get }
}

extension HashiCorpVaultReader {
  /// HTTP-related errors that can occur during vault operations.
  enum HTTPError: Swift.Error {
    /// The response is not an HTTP response.
    case responseNotHTTP(URLResponse)
    /// The HTTP status code indicates an error.
    case wrongStatusCode(Int)
  }

  func fetch(urlRequest: URLRequest, api: any HashiCorpVaultEngineAPIProtocol) async throws -> [String: String] {
    let (data, response) = try await urlSession.data(for: urlRequest)
    guard let response = response as? HTTPURLResponse else { throw HTTPError.responseNotHTTP(response) }
    guard (200..<300).contains(response.statusCode) else { throw HTTPError.wrongStatusCode(response.statusCode) }
    let result = try api.decodeGetSecretsResult(data: data)
    return result
  }

  func authenticateWithAppRole(configuration: Configuration) async throws -> String {
    log.debug("Authenticating with App Role")
    var urlRequest: URLRequest = try URLRequest(url: configuration.buildBaseURL(path: "/auth/approle/login"))
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let appRole = configuration.authenticationCredentials.appRole
    guard let appRole else { throw HashiCorpVaultReader.Error.appRoleAuthenticationCredentialsAreNotSet }
    urlRequest.httpBody = Data(#"{"role_id": "\#(appRole.roleId)", "secret_id": "\#(appRole.secretId)"}"#.utf8)

    struct Response: Decodable {
      struct Auth: Decodable {
        var clientToken: String
        var leaseDuration: TimeInterval
        var renewable: Bool
        var tokenType: String
      }
      var auth: Auth
    }
    let (data, response) = try await urlSession.data(for: urlRequest)
    guard let response = response as? HTTPURLResponse else { throw HTTPError.responseNotHTTP(response) }
    guard (200..<300).contains(response.statusCode) else { throw HTTPError.wrongStatusCode(response.statusCode) }
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let result = try decoder.decode(Response.self, from: data)
    let vaultToken = result.auth.clientToken
    return vaultToken
  }

  func authenticate(configuration: Configuration) async throws -> String {
    switch configuration.authenticationMethod {
    case .token:
      guard let token = configuration.authenticationCredentials.token?.vaultToken else {
        throw HashiCorpVaultReader.Error.tokenAuthenticationCredentialsIsNotSet
      }
      return token
    case .appRole: return try await authenticateWithAppRole(configuration: configuration)
    }
  }
}

extension HashiCorpVaultReader {
  /// A box container for HashiCorp Vault API responses.
  struct SecretsFetchResult<ContainedData: Decodable>: Decodable { let data: ContainedData }
}
