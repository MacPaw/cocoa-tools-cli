import Foundation
import Testing

@testable import HashiCorpVaultReader

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

@Suite("Configuration Tests")
struct ConfigurationTests {
  // MARK: - Configuration Initialization Tests

  @Test("Configuration initialization with all parameters")
  func test_configuration_initWithAllParameters() {
    // GIVEN: All configuration parameters
    let vaultAddress = URL(string: "https://vault.example.com:8200")!
    let apiVersion = "v2"
    let engineConfigurations = HashiCorpVaultReader.Configuration.EngineConfigurations(
      keyValue: .init(defaultSecretMountPath: "kv"),
      aws: .init(defaultEnginePath: "aws-prod")
    )
    let authCredentials = HashiCorpVaultReader.Configuration.AuthenticationCredentials(
      token: .init(vaultToken: "test-token")
    )
    let authMethod = HashiCorpVaultReader.Configuration.AuthenticationMethod.token

    // WHEN: Creating configuration
    let sut = HashiCorpVaultReader.Configuration(
      vaultAddress: vaultAddress,
      apiVersion: apiVersion,
      defaultEngineConfigurations: engineConfigurations,
      authenticationCredentials: authCredentials,
      authenticationMethod: authMethod
    )

    // THEN: Configuration is set correctly
    #expect(sut.vaultAddress == vaultAddress)
    #expect(sut.apiVersion == apiVersion)
    #expect(sut.defaultEngineConfigurations.keyValue?.defaultSecretMountPath == "kv")
    #expect(sut.defaultEngineConfigurations.aws?.defaultEnginePath == "aws-prod")
    #expect(sut.authenticationCredentials.token?.vaultToken == "test-token")
    #expect(sut.authenticationMethod == .token)
  }

  @Test("Configuration initialization with default API version")
  func test_configuration_initWithDefaultAPIVersion() {
    // GIVEN: Configuration without explicit API version
    let vaultAddress = URL(string: "https://vault.example.com")!
    let engineConfigurations = HashiCorpVaultReader.Configuration.EngineConfigurations()
    let authCredentials = HashiCorpVaultReader.Configuration.AuthenticationCredentials()
    let authMethod = HashiCorpVaultReader.Configuration.AuthenticationMethod.token

    // WHEN: Creating configuration with default API version
    let sut = HashiCorpVaultReader.Configuration(
      vaultAddress: vaultAddress,
      defaultEngineConfigurations: engineConfigurations,
      authenticationCredentials: authCredentials,
      authenticationMethod: authMethod
    )

    // THEN: API version defaults to "v1"
    #expect(sut.apiVersion == "v1")
  }

  @Test("Configuration decoding from JSON")
  func test_configuration_decodingFromJSON() throws {
    // GIVEN: JSON configuration data
    let jsonData = """
      {
        "vaultAddress": "https://vault.example.com:8200",
        "apiVersion": "v1",
        "authenticationCredentials": {
          "token": {
            "vaultToken": "hvs.test-token"
          }
        },
        "authenticationMethod": "token",
        "keyValue": {
          "defaultSecretMountPath": "secret"
        },
        "aws": {
          "defaultEnginePath": "aws"
        }
      }
      """
      .data(using: .utf8)!

    // WHEN: Decoding configuration
    let decoder = JSONDecoder()
    let sut = try decoder.decode(HashiCorpVaultReader.Configuration.self, from: jsonData)

    // THEN: Configuration is decoded correctly
    #expect(sut.vaultAddress.absoluteString == "https://vault.example.com:8200")
    #expect(sut.apiVersion == "v1")
    #expect(sut.authenticationMethod == .token)
    #expect(sut.authenticationCredentials.token?.vaultToken == "hvs.test-token")
    #expect(sut.defaultEngineConfigurations.keyValue?.defaultSecretMountPath == "secret")
    #expect(sut.defaultEngineConfigurations.aws?.defaultEnginePath == "aws")
  }

  @Test("Configuration decoding with missing API version uses default")
  func test_configuration_decodingWithMissingAPIVersion_usesDefault() throws {
    // GIVEN: JSON configuration data without API version
    let jsonData = """
      {
        "vaultAddress": "https://vault.example.com:8200",
        "authenticationCredentials": {
          "token": {
            "vaultToken": "hvs.test-token"
          }
        },
        "authenticationMethod": "token"
      }
      """
      .data(using: .utf8)!

    // WHEN: Decoding configuration
    let decoder = JSONDecoder()
    let sut = try decoder.decode(HashiCorpVaultReader.Configuration.self, from: jsonData)

    // THEN: API version defaults to "v1"
    #expect(sut.apiVersion == "v1")
  }

  // MARK: - URL Building Tests

  @Test("buildBaseURL with default path")
  func test_buildBaseURL_withDefaultPath() throws {
    // GIVEN: Configuration with vault address
    let sut = createMockConfiguration()

    // WHEN: Building base URL with default path
    let result = try sut.buildBaseURL()

    // THEN: URL is built correctly
    #expect(result.absoluteString == "https://vault.example.com/v1/")
  }

  @Test("buildBaseURL with custom path")
  func test_buildBaseURL_withCustomPath() throws {
    // GIVEN: Configuration with vault address
    let sut = createMockConfiguration()

    // WHEN: Building base URL with custom path
    let result = try sut.buildBaseURL(path: "/auth/approle/login")

    // THEN: URL is built correctly
    #expect(result.absoluteString == "https://vault.example.com/v1/auth/approle/login")
  }

  @Test("buildBaseURL with different API version")
  func test_buildBaseURL_withDifferentAPIVersion() throws {
    // GIVEN: Configuration with custom API version
    var sut = createMockConfiguration()
    sut = HashiCorpVaultReader.Configuration(
      vaultAddress: sut.vaultAddress,
      apiVersion: "v2",
      defaultEngineConfigurations: sut.defaultEngineConfigurations,
      authenticationCredentials: sut.authenticationCredentials,
      authenticationMethod: sut.authenticationMethod
    )

    // WHEN: Building base URL
    let result = try sut.buildBaseURL(path: "/secret/data/myapp")

    // THEN: URL includes custom API version
    #expect(result.absoluteString == "https://vault.example.com/v2/secret/data/myapp")
  }

  @Test("buildURLRequest with default parameters")
  func test_buildURLRequest_withDefaultParameters() throws {
    // GIVEN: Configuration and vault token
    let sut = createMockConfiguration()
    let vaultToken = "hvs.test-token"

    // WHEN: Building URL request
    let result = try sut.buildURLRequest(vaultToken: vaultToken)

    // THEN: URL request is configured correctly
    #expect(result.url?.absoluteString == "https://vault.example.com/v1/")
    #expect(result.httpMethod == "GET")
    #expect(result.value(forHTTPHeaderField: "X-Vault-Token") == vaultToken)
    #expect(result.value(forHTTPHeaderField: "Accept") == "application/json")
  }

  @Test("buildURLRequest with custom HTTP method")
  func test_buildURLRequest_withCustomHTTPMethod() throws {
    // GIVEN: Configuration and vault token
    let sut = createMockConfiguration()
    let vaultToken = "hvs.test-token"

    // WHEN: Building URL request with POST method
    let result = try sut.buildURLRequest(httpMethod: "POST", vaultToken: vaultToken)

    // THEN: HTTP method is set correctly
    #expect(result.httpMethod == "POST")
    #expect(result.value(forHTTPHeaderField: "X-Vault-Token") == vaultToken)
  }

  // MARK: - Authentication Credentials Tests

  @Test("AuthenticationCredentials initialization with token")
  func test_authenticationCredentials_initWithToken() {
    // GIVEN: Token credentials
    let token = HashiCorpVaultReader.Configuration.AuthenticationCredentials.Token(vaultToken: "hvs.test-token")

    // WHEN: Creating authentication credentials
    let sut = HashiCorpVaultReader.Configuration.AuthenticationCredentials(token: token)

    // THEN: Credentials are set correctly
    #expect(sut.token?.vaultToken == "hvs.test-token")
    #expect(sut.appRole == nil)
  }

  @Test("AuthenticationCredentials initialization with AppRole")
  func test_authenticationCredentials_initWithAppRole() {
    // GIVEN: AppRole credentials
    let appRole = HashiCorpVaultReader.Configuration.AuthenticationCredentials.AppRole(
      roleId: "role-id-123",
      secretId: "secret-id-456"
    )

    // WHEN: Creating authentication credentials
    let sut = HashiCorpVaultReader.Configuration.AuthenticationCredentials(appRole: appRole)

    // THEN: Credentials are set correctly
    #expect(sut.appRole?.roleId == "role-id-123")
    #expect(sut.appRole?.secretId == "secret-id-456")
    #expect(sut.token == nil)
  }

  @Test("AuthenticationCredentials decoding from JSON")
  func test_authenticationCredentials_decodingFromJSON() throws {
    // GIVEN: JSON authentication credentials data
    let jsonData = """
      {
        "token": {
          "vaultToken": "hvs.test-token"
        },
        "appRole": {
          "roleId": "role-id-123",
          "secretId": "secret-id-456"
        }
      }
      """
      .data(using: .utf8)!

    // WHEN: Decoding authentication credentials
    let decoder = JSONDecoder()
    let sut = try decoder.decode(HashiCorpVaultReader.Configuration.AuthenticationCredentials.self, from: jsonData)

    // THEN: Credentials are decoded correctly
    #expect(sut.token?.vaultToken == "hvs.test-token")
    #expect(sut.appRole?.roleId == "role-id-123")
    #expect(sut.appRole?.secretId == "secret-id-456")
  }

  // MARK: - Authentication Method Tests

  @Test("AuthenticationMethod token case")
  func test_authenticationMethod_tokenCase() {
    // GIVEN: Token authentication method
    let sut = HashiCorpVaultReader.Configuration.AuthenticationMethod.token

    // THEN: Raw value is correct
    #expect(sut.rawValue == "token")
  }

  @Test("AuthenticationMethod appRole case")
  func test_authenticationMethod_appRoleCase() {
    // GIVEN: AppRole authentication method
    let sut = HashiCorpVaultReader.Configuration.AuthenticationMethod.appRole

    // THEN: Raw value is correct
    #expect(sut.rawValue == "appRole")
  }

  @Test("AuthenticationMethod decoding from string")
  func test_authenticationMethod_decodingFromString() throws {
    // GIVEN: JSON string data
    let tokenData = "\"token\"".data(using: .utf8)!
    let appRoleData = "\"appRole\"".data(using: .utf8)!

    // WHEN: Decoding authentication methods
    let decoder = JSONDecoder()
    let tokenMethod = try decoder.decode(HashiCorpVaultReader.Configuration.AuthenticationMethod.self, from: tokenData)
    let appRoleMethod = try decoder.decode(
      HashiCorpVaultReader.Configuration.AuthenticationMethod.self,
      from: appRoleData
    )

    // THEN: Methods are decoded correctly
    #expect(tokenMethod == .token)
    #expect(appRoleMethod == .appRole)
  }

  // MARK: - Engine Configurations Tests

  @Test("EngineConfigurations initialization with all engines")
  func test_engineConfigurations_initWithAllEngines() {
    // GIVEN: KeyValue and AWS configurations
    let keyValueConfig = HashiCorpVaultReader.Engine.KeyValue.DefaultConfiguration(defaultSecretMountPath: "kv")
    let awsConfig = HashiCorpVaultReader.Engine.AWS.DefaultConfiguration(defaultEnginePath: "aws-prod")

    // WHEN: Creating engine configurations
    let sut = HashiCorpVaultReader.Configuration.EngineConfigurations(keyValue: keyValueConfig, aws: awsConfig)

    // THEN: Configurations are set correctly
    #expect(sut.keyValue?.defaultSecretMountPath == "kv")
    #expect(sut.aws?.defaultEnginePath == "aws-prod")
  }

  @Test("EngineConfigurations configuration for engine")
  func test_engineConfigurations_configurationForEngine() {
    // GIVEN: Engine configurations
    let keyValueConfig = HashiCorpVaultReader.Engine.KeyValue.DefaultConfiguration(defaultSecretMountPath: "kv")
    let awsConfig = HashiCorpVaultReader.Engine.AWS.DefaultConfiguration(defaultEnginePath: "aws-prod")
    let sut = HashiCorpVaultReader.Configuration.EngineConfigurations(keyValue: keyValueConfig, aws: awsConfig)

    // WHEN: Getting configuration for specific engines
    let keyValueResult = sut.configuration(for: .keyValue)
    let awsResult = sut.configuration(for: .aws)

    // THEN: Correct configurations are returned
    #expect(keyValueResult != nil)
    #expect(awsResult != nil)
  }

  @Test("EngineConfigurations decoding from JSON")
  func test_engineConfigurations_decodingFromJSON() throws {
    // GIVEN: JSON engine configurations data
    let jsonData = """
      {
        "keyValue": {
          "defaultSecretMountPath": "secret"
        },
        "aws": {
          "defaultEnginePath": "aws"
        }
      }
      """
      .data(using: .utf8)!

    // WHEN: Decoding engine configurations
    let decoder = JSONDecoder()
    let sut = try decoder.decode(HashiCorpVaultReader.Configuration.EngineConfigurations.self, from: jsonData)

    // THEN: Configurations are decoded correctly
    #expect(sut.keyValue?.defaultSecretMountPath == "secret")
    #expect(sut.aws?.defaultEnginePath == "aws")
  }

  // MARK: - Token Tests

  @Test("Token initialization")
  func test_token_initialization() {
    // GIVEN: Vault token string
    let tokenString = "hvs.test-token-123"

    // WHEN: Creating token
    let sut = HashiCorpVaultReader.Configuration.AuthenticationCredentials.Token(vaultToken: tokenString)

    // THEN: Token is set correctly
    #expect(sut.vaultToken == tokenString)
  }

  @Test("Token decoding from JSON")
  func test_token_decodingFromJSON() throws {
    // GIVEN: JSON token data
    let jsonData = """
      {
        "vaultToken": "hvs.test-token-123"
      }
      """
      .data(using: .utf8)!

    // WHEN: Decoding token
    let decoder = JSONDecoder()
    let sut = try decoder.decode(
      HashiCorpVaultReader.Configuration.AuthenticationCredentials.Token.self,
      from: jsonData
    )

    // THEN: Token is decoded correctly
    #expect(sut.vaultToken == "hvs.test-token-123")
  }

  // MARK: - AppRole Tests

  @Test("AppRole initialization")
  func test_appRole_initialization() {
    // GIVEN: Role ID and secret ID
    let roleId = "role-id-123"
    let secretId = "secret-id-456"

    // WHEN: Creating AppRole
    let sut = HashiCorpVaultReader.Configuration.AuthenticationCredentials.AppRole(roleId: roleId, secretId: secretId)

    // THEN: AppRole is set correctly
    #expect(sut.roleId == roleId)
    #expect(sut.secretId == secretId)
  }

  @Test("AppRole decoding from JSON")
  func test_appRole_decodingFromJSON() throws {
    // GIVEN: JSON AppRole data
    let jsonData = """
      {
        "roleId": "role-id-123",
        "secretId": "secret-id-456"
      }
      """
      .data(using: .utf8)!

    // WHEN: Decoding AppRole
    let decoder = JSONDecoder()
    let sut = try decoder.decode(
      HashiCorpVaultReader.Configuration.AuthenticationCredentials.AppRole.self,
      from: jsonData
    )

    // THEN: AppRole is decoded correctly
    #expect(sut.roleId == "role-id-123")
    #expect(sut.secretId == "secret-id-456")
  }

  // MARK: - Configuration Equality Tests

  @Test("Configuration equality comparison")
  func test_configuration_equalityComparison() {
    // GIVEN: Two identical configurations
    let config1 = createMockConfiguration()
    let config2 = createMockConfiguration()

    // WHEN: Comparing configurations
    let areEqual = config1 == config2

    // THEN: Configurations are equal
    #expect(areEqual)
  }

  @Test("Configuration inequality with different vault address")
  func test_configuration_inequalityWithDifferentVaultAddress() {
    // GIVEN: Two configurations with different vault addresses
    let config1 = createMockConfiguration()
    var config2 = createMockConfiguration()
    config2 = HashiCorpVaultReader.Configuration(
      vaultAddress: URL(string: "https://different-vault.example.com")!,
      defaultEngineConfigurations: config2.defaultEngineConfigurations,
      authenticationCredentials: config2.authenticationCredentials,
      authenticationMethod: config2.authenticationMethod
    )

    // WHEN: Comparing configurations
    let areEqual = config1 == config2

    // THEN: Configurations are not equal
    #expect(!areEqual)
  }

  // MARK: - Helper Methods

  private func createMockConfiguration() throws -> HashiCorpVaultReader.Configuration {
    HashiCorpVaultReader.Configuration(
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
