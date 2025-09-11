import Foundation
import Testing
@testable import HashiCorpVaultReader

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

@Suite("Integration Tests")
struct IntegrationTests {

  // MARK: - Mock URL Protocol

  class MockURLProtocol: URLProtocol, @unchecked Sendable {
    static let lock = NSLock()
    nonisolated(unsafe) static var mockResponses: [String: (data: Data, statusCode: Int)] = [:]
    nonisolated(unsafe) static var error: Error?

    override class func canInit(with request: URLRequest) -> Bool {
      return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
      return request
    }

    override func startLoading() {
      MockURLProtocol.lock.lock()
      defer { MockURLProtocol.lock.unlock() }

      if let error = MockURLProtocol.error {
        client?.urlProtocol(self, didFailWithError: error)
        return
      }

      guard let url = request.url?.absoluteString,
            let mockResponse = MockURLProtocol.mockResponses[url] else {
        let error = NSError(domain: "MockError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Mock response not found", NSURLErrorKey: request.url!])
        client?.urlProtocol(self, didFailWithError: error)
        return
      }

      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: mockResponse.statusCode,
        httpVersion: "HTTP/1.1",
        headerFields: ["Content-Type": "application/json"]
      )!

      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: mockResponse.data)
      client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static func reset() {
      lock.lock()
      defer { lock.unlock() }
      mockResponses.removeAll()
      error = nil
    }

    static func setMockResponse(for url: String, data: Data, statusCode: Int) {
      lock.lock()
      defer { lock.unlock() }
      mockResponses[url] = (data: data, statusCode: statusCode)
    }
  }

  // MARK: - Mock HashiCorpVaultReader

  final class MockHashiCorpVaultReader: HashiCorpVaultReaderProtocol, @unchecked Sendable {
    var fetchResult: [String: String] = [:]
    var fetchError: Error?
    var fetchCallCount = 0
    var lastSecrets: [String: HashiCorpVaultReader.Element]?
    var lastConfiguration: HashiCorpVaultReader.Configuration?

    func fetch(
      secrets: [String: HashiCorpVaultReader.Element],
      configuration: HashiCorpVaultReader.Configuration
    ) async throws -> [String: String] {
      fetchCallCount += 1
      lastSecrets = secrets
      lastConfiguration = configuration

      if let error = fetchError {
        throw error
      }

      return fetchResult
    }

    func reset() {
      fetchResult = [:]
      fetchError = nil
      fetchCallCount = 0
      lastSecrets = nil
      lastConfiguration = nil
    }
  }

  // MARK: - Setup and Teardown

  init() {
    // Configure URLSession to use mock protocol
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    URLProtocol.registerClass(MockURLProtocol.self)
  }


  // MARK: - Fetch Integration Tests

  @Test("fetch with KeyValue engine returns secrets")
  func test_fetch_withKeyValueEngine_returnsSecrets() async throws {
    // GIVEN: Configuration and KeyValue secrets
    let configuration = createMockConfiguration()
    let secrets = [
      "DATABASE_PASSWORD": HashiCorpVaultReader.Element(
        keyValue: .init(
          secretMountPath: "secret",
          path: "myapp/database",
          version: 1,
          key: "password"
        )
      )
    ]

    // Mock vault authentication response
    MockURLProtocol.setMockResponse(
      for: "https://vault.example.com/v1",
      data: Data(),
      statusCode: 200
    )

    // Mock KeyValue secrets response
    MockURLProtocol.setMockResponse(
      for: "https://vault.example.com/v1/secret/data/myapp/database?version=1",
      data: """
      {
        "data": {
          "data": {
            "password": "secret123",
            "username": "admin"
          }
        }
      }
      """.data(using: .utf8)!,
      statusCode: 200
    )

    let sut = HashiCorpVaultReader()

    // WHEN: Fetching secrets
    let result = try await sut.fetch(secrets: secrets, configuration: configuration)

    // THEN: Secrets are returned correctly
    #expect(result["DATABASE_PASSWORD"] == "secret123")
    #expect(result.count == 1)
  }

  @Test("fetch with AWS engine returns credentials")
  func test_fetch_withAWSEngine_returnsCredentials() async throws {
    // GIVEN: Configuration and AWS secrets
    let configuration = createMockConfiguration()
    let secrets = [
      "AWS_ACCESS_KEY": HashiCorpVaultReader.Element(
        aws: .init(
          enginePath: "aws",
          role: "my-role",
          key: "accessKey"
        )
      ),
      "AWS_SECRET_KEY": HashiCorpVaultReader.Element(
        aws: .init(
          enginePath: "aws",
          role: "my-role",
          key: "secretKey"
        )
      )
    ]

    // Mock vault authentication response
    MockURLProtocol.setMockResponse(
      for: "https://vault.example.com/v1",
      data: Data(),
      statusCode: 200
    )

    // Mock AWS credentials response
    MockURLProtocol.setMockResponse(for: "https://vault.example.com/v1/aws/creds/my-role",
      data: """
      {
        "data": {
          "accessKey": "AKIA123456789",
          "secretKey": "secret123456789"
        }
      }
      """.data(using: .utf8)!,
      statusCode: 200
    )

    let sut = HashiCorpVaultReader()

    // WHEN: Fetching secrets
    let result = try await sut.fetch(secrets: secrets, configuration: configuration)

    // THEN: AWS credentials are returned correctly
    #expect(result["AWS_ACCESS_KEY"] == "AKIA123456789")
    #expect(result["AWS_SECRET_KEY"] == "secret123456789")
    #expect(result.count == 2)
  }

  @Test("fetch with mixed engines returns all secrets")
  func test_fetch_withMixedEngines_returnsAllSecrets() async throws {
    // GIVEN: Configuration with both KeyValue and AWS secrets
    let configuration = createMockConfiguration()
    let secrets = [
      "DATABASE_PASSWORD": HashiCorpVaultReader.Element(
        keyValue: .init(
          secretMountPath: "secret",
          path: "myapp/database",
          version: 0, // Latest version
          key: "password"
        )
      ),
      "AWS_ACCESS_KEY": HashiCorpVaultReader.Element(
        aws: .init(
          enginePath: "aws",
          role: "my-role",
          key: "accessKey"
        )
      )
    ]

    // Mock vault authentication response
    MockURLProtocol.setMockResponse(
      for: "https://vault.example.com/v1",
      data: Data(),
      statusCode: 200
    )

    // Mock KeyValue secrets response
    MockURLProtocol.setMockResponse(for: "https://vault.example.com/v1/secret/data/myapp/database",
      data: """
      {
        "data": {
          "data": {
            "password": "secret123",
            "username": "admin"
          }
        }
      }
      """.data(using: .utf8)!,
      statusCode: 200
    )

    // Mock AWS credentials response
    MockURLProtocol.setMockResponse(for: "https://vault.example.com/v1/aws/creds/my-role",
      data: """
      {
        "data": {
          "accessKey": "AKIA123456789",
          "secretKey": "secret123456789"
        }
      }
      """.data(using: .utf8)!,
      statusCode: 200
    )

    let sut = HashiCorpVaultReader()

    // WHEN: Fetching mixed secrets
    let result = try await sut.fetch(secrets: secrets, configuration: configuration)

    // THEN: All secrets are returned correctly
    #expect(result["DATABASE_PASSWORD"] == "secret123")
    #expect(result["AWS_ACCESS_KEY"] == "AKIA123456789")
    #expect(result.count == 2)
  }

  @Test("fetch with HTTP error throws HTTPError")
  func test_fetch_withHTTPError_throwsHTTPError() async throws {
    // GIVEN: Configuration and secrets with HTTP error response
    let configuration = createMockConfiguration()
    let secrets = [
      "DATABASE_PASSWORD": HashiCorpVaultReader.Element(
        keyValue: .init(
          secretMountPath: "secret",
          path: "myapp/database",
          version: 2,
          key: "password"
        )
      )
    ]

    // Mock vault authentication response
    MockURLProtocol.setMockResponse(
      for: "https://vault.example.com/v1",
      data: Data(),
      statusCode: 200
    )

    // Mock KeyValue secrets response with error
    MockURLProtocol.setMockResponse(for: "https://vault.example.com/v1/secret/data/myapp/database?version=2",
      data: """
      {
        "errors": ["permission denied"]
      }
      """.data(using: .utf8)!,
      statusCode: 403
    )

    let sut = HashiCorpVaultReader()

    // WHEN/THEN: Fetching secrets should throw HTTP error
    await #expect(throws: HashiCorpVaultReader.HTTPError.self) {
      try await sut.fetch(secrets: secrets, configuration: configuration)
    }
  }

  @Test("fetch with missing secret key throws error")
  func test_fetch_withMissingSecretKey_throwsError() async throws {
    // GIVEN: Configuration and secrets where response doesn't contain requested key
    let configuration = createMockConfiguration()
    let secrets = [
      "DATABASE_PASSWORD": HashiCorpVaultReader.Element(
        keyValue: .init(
          secretMountPath: "secret",
          path: "myapp/database",
          version: 4,
          key: "missing_key" // This key won't be in the response
        )
      )
    ]

    // Mock vault authentication response
    MockURLProtocol.setMockResponse(
      for: "https://vault.example.com/v1",
      data: Data(),
      statusCode: 200
    )

    // Mock KeyValue secrets response without the requested key
    MockURLProtocol.setMockResponse(for: "https://vault.example.com/v1/secret/data/myapp/database?version=4",
      data: """
      {
        "data": {
          "data": {
            "password": "secret123",
            "username": "admin"
          }
        }
      }
      """.data(using: .utf8)!,
      statusCode: 200
    )

    let sut = HashiCorpVaultReader()

    // WHEN/THEN: Fetching secrets should throw error for missing key
    await #expect(throws: HashiCorpVaultReader.Error.self) {
      try await sut.fetch(secrets: secrets, configuration: configuration)
    }
  }

  // MARK: - AppRole Authentication Tests

  @Test("authenticateWithAppRole returns token")
  func test_authenticateWithAppRole_returnsToken() async throws {
    // GIVEN: Configuration with AppRole authentication
    let configuration = HashiCorpVaultReader.Configuration(
      vaultAddress: URL(string: "https://vault.example.com")!,
      apiVersion: "v2",
      defaultEngineConfigurations: .init(),
      authenticationCredentials: .init(
        appRole: .init(roleId: "role-123", secretId: "secret-456")
      ),
      authenticationMethod: .appRole
    )

    // Mock AppRole authentication response
    MockURLProtocol.setMockResponse(for: "https://vault.example.com/v2/auth/approle/login",
      data: """
      {
        "auth": "some",
        "client_token": "hvs.token123"
      }
      """.data(using: .utf8)!,
      statusCode: 200
    )

    let sut = HashiCorpVaultReader()

    // WHEN: Authenticating with AppRole
    let result = try await sut.authenticateWithAppRole(configuration: configuration)

    // THEN: Token is returned
    #expect(result == "hvs.token123")
  }

  @Test("authenticateWithAppRole without credentials throws error")
  func test_authenticateWithAppRole_withoutCredentials_throwsError() async throws {
    // GIVEN: Configuration without AppRole credentials
    let configuration = HashiCorpVaultReader.Configuration(
      vaultAddress: URL(string: "https://vault.example.com")!,
      defaultEngineConfigurations: .init(),
      authenticationCredentials: .init(), // No AppRole credentials
      authenticationMethod: .appRole
    )

    let sut = HashiCorpVaultReader()

    // WHEN/THEN: Authenticating should throw error
    await #expect(throws: HashiCorpVaultReader.Error.appRoleAuthenticationCredentialsAreNotSet) {
      try await sut.authenticateWithAppRole(configuration: configuration)
    }
  }

  @Test("authenticateWithAppRole with invalid response throws error")
  func test_authenticateWithAppRole_withInvalidResponse_throwsError() async throws {
    // GIVEN: Configuration with AppRole authentication and invalid response
    let configuration = HashiCorpVaultReader.Configuration(
      vaultAddress: URL(string: "https://vault.example.com")!,
      defaultEngineConfigurations: .init(),
      authenticationCredentials: .init(
        appRole: .init(roleId: "role-123", secretId: "secret-456")
      ),
      authenticationMethod: .appRole
    )

    // Mock AppRole authentication response without client_token
    MockURLProtocol.setMockResponse(for: "https://vault.example.com/v1/auth/approle/login",
      data: """
      {
        "auth": "some"
      }
      """.data(using: .utf8)!,
      statusCode: 200
    )

    let sut = HashiCorpVaultReader()

    // WHEN/THEN: Authenticating should throw error
    await #expect(throws: HashiCorpVaultReader.Error.cantGetTokenFromAppRoleAuthenticationResponse) {
      try await sut.authenticateWithAppRole(configuration: configuration)
    }
  }

  // MARK: - Batching Optimization Tests

  @Test("fetch batches requests for same KeyValue item")
  func test_fetch_batchesRequestsForSameKeyValueItem() async throws {
    // GIVEN: Multiple secrets from the same KeyValue item
    let configuration = createMockConfiguration()
    let secrets = [
      "DB_HOST": HashiCorpVaultReader.Element(
        keyValue: .init(
          secretMountPath: "secret",
          path: "myapp/database",
          version: 3,
          key: "host"
        )
      ),
      "DB_PORT": HashiCorpVaultReader.Element(
        keyValue: .init(
          secretMountPath: "secret",
          path: "myapp/database", // Same path as above
          version: 3,
          key: "port"
        )
      ),
      "DB_NAME": HashiCorpVaultReader.Element(
        keyValue: .init(
          secretMountPath: "secret",
          path: "myapp/database", // Same path as above
          version: 3,
          key: "database"
        )
      )
    ]

    // Mock vault authentication response
    MockURLProtocol.setMockResponse(
      for: "https://vault.example.com/v1",
      data: Data(),
      statusCode: 200
    )

    // Mock single KeyValue secrets response with all requested fields
    MockURLProtocol.setMockResponse(for: "https://vault.example.com/v1/secret/data/myapp/database?version=3",
      data: """
      {
        "data": {
          "data": {
            "host": "localhost",
            "port": "5432",
            "database": "myapp_prod",
            "username": "admin"
          }
        }
      }
      """.data(using: .utf8)!,
      statusCode: 200
    )

    let sut = HashiCorpVaultReader()

    // WHEN: Fetching secrets
    let result = try await sut.fetch(secrets: secrets, configuration: configuration)

    // THEN: All secrets are returned from single API call
    #expect(result["DB_HOST"] == "localhost")
    #expect(result["DB_PORT"] == "5432")
    #expect(result["DB_NAME"] == "myapp_prod")
    #expect(result.count == 3)
  }

  @Test("fetch batches requests for same AWS role")
  func test_fetch_batchesRequestsForSameAWSRole() async throws {
    // GIVEN: Multiple secrets from the same AWS role
    let configuration = createMockConfiguration()
    let secrets = [
      "AWS_ACCESS_KEY": HashiCorpVaultReader.Element(
        aws: .init(
          enginePath: "aws",
          role: "my-role", // Same role
          key: "accessKey"
        )
      ),
      "AWS_SECRET_KEY": HashiCorpVaultReader.Element(
        aws: .init(
          enginePath: "aws",
          role: "my-role", // Same role
          key: "secretKey"
        )
      )
    ]

    // Mock vault authentication response
    MockURLProtocol.setMockResponse(
      for: "https://vault.example.com/v1",
      data: Data(),
      statusCode: 200
    )

    // Mock single AWS credentials response
    MockURLProtocol.setMockResponse(for: "https://vault.example.com/v1/aws/creds/my-role",
      data: """
      {
        "data": {
          "accessKey": "AKIA123456789",
          "secretKey": "secret123456789"
        }
      }
      """.data(using: .utf8)!,
      statusCode: 200
    )

    let sut = HashiCorpVaultReader()

    // WHEN: Fetching secrets
    let result = try await sut.fetch(secrets: secrets, configuration: configuration)

    // THEN: Both secrets are returned from single API call
    #expect(result["AWS_ACCESS_KEY"] == "AKIA123456789")
    #expect(result["AWS_SECRET_KEY"] == "secret123456789")
    #expect(result.count == 2)
  }

  // MARK: - Helper Methods

  private func createMockConfiguration() -> HashiCorpVaultReader.Configuration {
    HashiCorpVaultReader.Configuration(
      vaultAddress: URL(string: "https://vault.example.com")!,
      defaultEngineConfigurations: .init(
        keyValue: .init(defaultSecretMountPath: "secret"),
        aws: .init(defaultEnginePath: "aws")
      ),
      authenticationCredentials: .init(
        token: .init(vaultToken: "test-token")
      ),
      authenticationMethod: .token
    )
  }
}
