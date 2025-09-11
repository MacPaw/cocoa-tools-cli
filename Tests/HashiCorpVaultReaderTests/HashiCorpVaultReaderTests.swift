import Foundation
import Testing

@testable import HashiCorpVaultReader

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

@Suite("HashiCorpVaultReader Tests")
struct HashiCorpVaultReaderTests {
  // MARK: - Element Tests

  @Test("Element initialization with KeyValue engine")
  func test_element_initWithKeyValue() {
    // GIVEN: KeyValue element configuration
    let keyValueElement = HashiCorpVaultReader.Engine.KeyValue.Element(
      secretMountPath: "secret",
      path: "myapp/database",
      version: 1,
      key: "password"
    )

    // WHEN: Creating Element with KeyValue configuration
    let sut = HashiCorpVaultReader.Element(keyValue: keyValueElement)

    // THEN: Element is configured correctly
    #expect(sut.keyValue != nil)
    #expect(sut.aws == nil)
    #expect(sut.keyValue?.secretMountPath == "secret")
    #expect(sut.keyValue?.path == "myapp/database")
    #expect(sut.keyValue?.version == 1)
    #expect(sut.keyValue?.key == "password")
  }

  @Test("Element initialization with AWS engine")
  func test_element_initWithAWS() {
    // GIVEN: AWS element configuration
    let awsElement = HashiCorpVaultReader.Engine.AWS.Element(enginePath: "aws", role: "my-role", key: "accessKey")

    // WHEN: Creating Element with AWS configuration
    let sut = HashiCorpVaultReader.Element(aws: awsElement)

    // THEN: Element is configured correctly
    #expect(sut.aws != nil)
    #expect(sut.keyValue == nil)
    #expect(sut.aws?.enginePath == "aws")
    #expect(sut.aws?.role == "my-role")
    #expect(sut.aws?.key == "accessKey")
  }

  @Test("Element initialization with both engines fails validation")
  func test_element_initWithBothEngines_failsValidation() async throws {
    // GIVEN: Both KeyValue and AWS element configurations
    let keyValueElement = HashiCorpVaultReader.Engine.KeyValue.Element(
      secretMountPath: "secret",
      path: "myapp/database",
      version: 1,
      key: "password"
    )
    let awsElement = HashiCorpVaultReader.Engine.AWS.Element(enginePath: "aws", role: "my-role", key: "accessKey")
    let configuration = try createMockConfiguration()

    // WHEN: Creating Element with both configurations
    let _ = HashiCorpVaultReader.Element(keyValue: keyValueElement, aws: awsElement)

    // THEN: Decoding should fail with validation error
    let jsonData = """
      {
        "keyValue": {
          "secretMountPath": "secret",
          "path": "myapp/database",
          "version": 1,
          "key": "password"
        },
        "aws": {
          "enginePath": "aws",
          "role": "my-role",
          "key": "accessKey"
        }
      }
      """
      .data(using: .utf8)!

    let decoder = JSONDecoder()

    #expect(throws: DecodingError.self) {
      try decoder.decode(HashiCorpVaultReader.Element.self, from: jsonData, configuration: configuration)
    }
  }

  @Test("Element initialization with no engines fails validation")
  func test_element_initWithNoEngines_failsValidation() async throws {
    // GIVEN: No engine configurations
    let configuration = try createMockConfiguration()

    // WHEN: Creating Element with no configurations
    let jsonData = """
      {
      }
      """
      .data(using: .utf8)!

    let decoder = JSONDecoder()

    // THEN: Decoding should fail with validation error
    #expect(throws: DecodingError.self) {
      try decoder.decode(HashiCorpVaultReader.Element.self, from: jsonData, configuration: configuration)
    }
  }

  // MARK: - HTTP Error Tests

  @Test("HTTPError cases are correctly defined")
  func test_httpError_cases() {
    // GIVEN: Mock URL response and status codes
    let mockResponse = URLResponse()

    // WHEN: Creating HTTP errors
    let responseNotHTTP = HashiCorpVaultReader.HTTPError.responseNotHTTP(mockResponse)
    let wrongStatusCode = HashiCorpVaultReader.HTTPError.wrongStatusCode(404)

    // THEN: Errors are created correctly
    switch responseNotHTTP {
    case .responseNotHTTP(let response): #expect(response === mockResponse)
    default: #expect(Bool(false), "Expected responseNotHTTP case")
    }

    switch wrongStatusCode {
    case .wrongStatusCode(let code): #expect(code == 404)
    default: #expect(Bool(false), "Expected wrongStatusCode case")
    }
  }

  // MARK: - Authentication Tests

  @Test("authenticate with token returns token")
  func test_authenticate_withToken_returnsToken() async throws {
    // GIVEN: Configuration with token authentication
    var configuration = try createMockConfiguration()
    configuration.authenticationMethod = .token
    let sut = HashiCorpVaultReader()

    // WHEN: Authenticating
    let result = try await sut.authenticate(configuration: configuration)

    // THEN: Returns the token
    #expect(result == "test-token")
  }

  @Test("authenticate with token but no credentials throws error")
  func test_authenticate_withTokenButNoCredentials_throwsError() async throws {
    // GIVEN: Configuration with token authentication but no token credentials
    let configuration = HashiCorpVaultReader.Configuration(
      vaultAddress: URL(string: "https://vault.example.com")!,
      defaultEngineConfigurations: .init(),
      authenticationCredentials: .init(),
      authenticationMethod: .token
    )
    let sut = HashiCorpVaultReader()

    // WHEN/THEN: Authenticating should throw error
    await #expect(throws: HashiCorpVaultReader.Error.tokenAuthenticationCredentialsIsNotSet) {
      try await sut.authenticate(configuration: configuration)
    }
  }

  // MARK: - UniqueItem Tests

  // MARK: - Helper Methods

  private func createMockConfiguration() throws -> HashiCorpVaultReader.Configuration {
    try HashiCorpVaultReader.Configuration(
      vaultAddress: #require(URL(string: "https://vault.example.com")),
      defaultEngineConfigurations: .init(
        keyValue: .init(defaultSecretMountPath: "secret"),
        aws: .init(defaultEnginePath: "aws")
      ),
      authenticationCredentials: .init(token: .init(vaultToken: "test-token")),
      authenticationMethod: .token
    )
  }
}
