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
    let keyValueElement = HashiCorpVaultReader.Engine.KeyValue.Item(
      engineVersion: .default,
      secretMountPath: "secret",
      path: "myapp/database",
      version: 1,
    )

    // WHEN: Creating Element with KeyValue configuration
    let sut = HashiCorpVaultReader.Element.init(item: .keyValue(keyValueElement), keys: ["password"])

    // THEN: Element is configured correctly
    #expect(sut.keys == ["password"])
    #expect(sut.item == .keyValue(keyValueElement))
  }

  @Test("Element initialization with AWS engine")
  func test_element_initWithAWS() {
    // GIVEN: AWS element configuration
    let awsElement = HashiCorpVaultReader.Engine.AWS.Item(enginePath: "aws", role: "my-role")

    // WHEN: Creating Element with AWS configuration
    let sut = HashiCorpVaultReader.Element(item: .aws(awsElement))

    // THEN: Element is configured correctly
    #expect(sut.item == .aws(awsElement))
  }

  @Test("Element initialization with both engines fails validation")
  func test_element_initWithBothEngines_failsValidation() async throws {
    // GIVEN: Both KeyValue and AWS element configurations
    let keyValueElement = HashiCorpVaultReader.Engine.KeyValue.Item(
      engineVersion: .v2,
      secretMountPath: "secret",
      path: "myapp/database",
      version: 1,
    )
    let configuration = try createMockConfiguration()

    // WHEN: Creating Element with both configurations
    let _ = HashiCorpVaultReader.Element(item: .keyValue(keyValueElement))

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
