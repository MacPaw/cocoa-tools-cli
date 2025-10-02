import Foundation
import SharedLogger

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

extension HashiCorpVaultReader {
  /// HTTP-related errors that can occur during vault operations.
  enum HTTPError: Swift.Error {
    /// The response is not an HTTP response.
    case responseNotHTTP(URLResponse)
    /// The HTTP status code indicates an error.
    case wrongStatusCode(Int)
  }

  func fetch<API: HashiCorpVaultEngineAPIProtocol>(urlRequest: URLRequest, api: API, item: API.Item) async throws
    -> [String: String]
  {
    let (data, response) = try await urlSession.data(for: urlRequest)
    guard let response = response as? HTTPURLResponse else { throw HTTPError.responseNotHTTP(response) }
    guard (200..<300).contains(response.statusCode) else {
      if let string = String.init(data: data, encoding: .utf8) { log.error("\(string)") }
      throw HTTPError.wrongStatusCode(response.statusCode)
    }
    let result = try api.secretsFromResponse(data, for: item).mapValues(String.init(describing:))
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
