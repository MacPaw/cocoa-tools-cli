import Foundation
import Testing
@testable import HashiCorpVaultReader

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

@Suite("Engine Tests")
struct EngineTests {

  // MARK: - Engine Enum Tests

  @Test("Engine enum cases have correct raw values")
  func test_engine_enumCases() {
    // GIVEN: Engine enum cases

    // WHEN: Checking raw values
    let keyValueRaw = HashiCorpVaultReader.Engine.keyValue.rawValue
    let awsRaw = HashiCorpVaultReader.Engine.aws.rawValue

    // THEN: Raw values are correct
    #expect(keyValueRaw == "keyValue")
    #expect(awsRaw == "aws")
  }

  // MARK: - KeyValue Engine Tests

  @Suite("KeyValue Engine Tests")
  struct KeyValueEngineTests {

    @Test("KeyValue DefaultConfiguration initialization with default path")
    func test_keyValue_defaultConfiguration_initWithDefaultPath() {
      // GIVEN: Default secret mount path

      // WHEN: Creating default configuration
      let sut = HashiCorpVaultReader.Engine.KeyValue.DefaultConfiguration()

      // THEN: Default path is set
      #expect(sut.defaultSecretMountPath == "secret")
    }

    @Test("KeyValue DefaultConfiguration initialization with custom path")
    func test_keyValue_defaultConfiguration_initWithCustomPath() {
      // GIVEN: Custom secret mount path
      let customPath = "kv-store"

      // WHEN: Creating default configuration
      let sut = HashiCorpVaultReader.Engine.KeyValue.DefaultConfiguration(
        defaultSecretMountPath: customPath
      )

      // THEN: Custom path is set
      #expect(sut.defaultSecretMountPath == customPath)
    }

    @Test("KeyValue DefaultConfiguration decoding from JSON")
    func test_keyValue_defaultConfiguration_decodingFromJSON() throws {
      // GIVEN: JSON configuration data
      let jsonData = """
      {
        "defaultSecretMountPath": "kv-v2"
      }
      """.data(using: .utf8)!

      // WHEN: Decoding configuration
      let decoder = JSONDecoder()
      let sut = try decoder.decode(
        HashiCorpVaultReader.Engine.KeyValue.DefaultConfiguration.self,
        from: jsonData
      )

      // THEN: Configuration is decoded correctly
      #expect(sut.defaultSecretMountPath == "kv-v2")
    }

    @Test("KeyValue DefaultConfiguration decoding with missing path uses default")
    func test_keyValue_defaultConfiguration_decodingWithMissingPath_usesDefault() throws {
      // GIVEN: Empty JSON configuration data
      let jsonData = "{}".data(using: .utf8)!

      // WHEN: Decoding configuration
      let decoder = JSONDecoder()
      let sut = try decoder.decode(
        HashiCorpVaultReader.Engine.KeyValue.DefaultConfiguration.self,
        from: jsonData
      )

      // THEN: Default path is used
      #expect(sut.defaultSecretMountPath == "secret")
    }

    @Test("KeyValue Element initialization")
    func test_keyValue_element_initialization() {
      // GIVEN: Element parameters
      let secretMountPath = "secret"
      let path = "myapp/database"
      let version = 2
      let key = "password"

      // WHEN: Creating element (direct initialization not available, testing through configuration)
      let element = HashiCorpVaultReader.Engine.KeyValue.Element(
        secretMountPath: secretMountPath,
        path: path,
        version: version,
        key: key
      )

      // THEN: Element properties are set correctly
      #expect(element.secretMountPath == secretMountPath)
      #expect(element.path == path)
      #expect(element.version == version)
      #expect(element.key == key)
    }

    @Test("KeyValue Element decoding from JSON with configuration")
    func test_keyValue_element_decodingFromJSON() throws {
      // GIVEN: JSON element data and configuration
      let jsonData = """
      {
        "secretMountPath": "kv",
        "path": "myapp/database",
        "version": 3,
        "key": "password"
      }
      """.data(using: .utf8)!

      let configuration = EngineTests.createMockConfiguration()

      // WHEN: Decoding element
      let decoder = JSONDecoder()
      let sut = try decoder.decode(
        HashiCorpVaultReader.Engine.KeyValue.Element.self,
        from: jsonData,
        configuration: configuration
      )

      // THEN: Element is decoded correctly
      #expect(sut.secretMountPath == "kv")
      #expect(sut.path == "myapp/database")
      #expect(sut.version == 3)
      #expect(sut.key == "password")
    }

    @Test("KeyValue Element decoding uses default secret mount path")
    func test_keyValue_element_decodingUsesDefaultSecretMountPath() throws {
      // GIVEN: JSON element data without secretMountPath and configuration with default
      let jsonData = """
      {
        "path": "myapp/database",
        "key": "password"
      }
      """.data(using: .utf8)!

      let configuration = EngineTests.createMockConfiguration()

      // WHEN: Decoding element
      let decoder = JSONDecoder()
      let sut = try decoder.decode(
        HashiCorpVaultReader.Engine.KeyValue.Element.self,
        from: jsonData,
        configuration: configuration
      )

      // THEN: Default secret mount path is used
      #expect(sut.secretMountPath == "secret")
      #expect(sut.version == 0) // Default version
    }

    @Test("KeyValue Element decoding without secretMountPath or default throws error")
    func test_keyValue_element_decodingWithoutSecretMountPath_throwsError() throws {
      // GIVEN: JSON element data without secretMountPath and configuration without default
      let jsonData = """
      {
        "path": "myapp/database",
        "key": "password"
      }
      """.data(using: .utf8)!

      let configuration = HashiCorpVaultReader.Configuration(
        vaultAddress: URL(string: "https://vault.example.com")!,
        defaultEngineConfigurations: .init(), // No KeyValue default configuration
        authenticationCredentials: .init(),
        authenticationMethod: .token
      )

      // WHEN/THEN: Decoding should throw error
      let decoder = JSONDecoder()
      #expect(throws: DecodingError.self) {
        try decoder.decode(
          HashiCorpVaultReader.Engine.KeyValue.Element.self,
          from: jsonData,
          configuration: configuration
        )
      }
    }

    @Test("KeyValue API adaptURLRequest for element")
    func test_keyValue_api_adaptURLRequest() throws {
      // GIVEN: API instance, URL request, and element
      let sut = HashiCorpVaultReader.Engine.KeyValue.API()
      let baseURL = URL(string: "https://vault.example.com/v1")!
      let urlRequest = URLRequest(url: baseURL)

      let element = HashiCorpVaultReader.Engine.KeyValue.Element(
        secretMountPath: "secret",
        path: "myapp/database",
        version: 2,
        key: "password"
      )
      let uniqueElement = HashiCorpVaultReader.UniqueItem.KeyValue(source: element)

      // WHEN: Adapting URL request
      let result = try sut.adaptURLRequest(urlRequest: urlRequest, for: uniqueElement)

      // THEN: URL is adapted correctly
      #expect(result.url?.absoluteString == "https://vault.example.com/v1/secret/data/myapp/database?version=2")
    }

    @Test("KeyValue API adaptURLRequest without version")
    func test_keyValue_api_adaptURLRequest_withoutVersion() throws {
      // GIVEN: API instance, URL request, and element without version
      let sut = HashiCorpVaultReader.Engine.KeyValue.API()
      let baseURL = URL(string: "https://vault.example.com/v1")!
      let urlRequest = URLRequest(url: baseURL)

      let element = HashiCorpVaultReader.Engine.KeyValue.Element(
        secretMountPath: "secret",
        path: "myapp/database",
        version: 0, // No specific version
        key: "password"
      )
      let uniqueElement = HashiCorpVaultReader.UniqueItem.KeyValue(source: element)

      // WHEN: Adapting URL request
      let result = try sut.adaptURLRequest(urlRequest: urlRequest, for: uniqueElement)

      // THEN: URL is adapted without version parameter
      #expect(result.url?.absoluteString == "https://vault.example.com/v1/secret/data/myapp/database")
    }

    @Test("KeyValue API decodeGetSecretsResult")
    func test_keyValue_api_decodeGetSecretsResult() throws {
      // GIVEN: API instance and mock response data
      let sut = HashiCorpVaultReader.Engine.KeyValue.API()
      let responseData = """
      {
        "data": {
          "data": {
            "password": "secret123",
            "username": "admin"
          }
        }
      }
      """.data(using: .utf8)!

      // WHEN: Decoding get secrets result
      let result = try sut.decodeGetSecretsResult(data: responseData)

      // THEN: Secrets are decoded correctly
      #expect(result["password"] == "secret123")
      #expect(result["username"] == "admin")
      #expect(result.count == 2)
    }

    @Test("KeyValue GetSecretsResult secrets property")
    func test_keyValue_getSecretsResult_secretsProperty() {
      // GIVEN: GetSecretsResult with data
      let data = ["password": "secret123", "username": "admin"]
      let sut = HashiCorpVaultReader.Engine.KeyValue.API.GetSecretsResult(data: data)

      // WHEN: Accessing secrets property
      let secrets = sut.secrets

      // THEN: Secrets match the data
      #expect(secrets == data)
    }
  }

  // MARK: - AWS Engine Tests

  @Suite("AWS Engine Tests")
  struct AWSEngineTests {

    @Test("AWS DefaultConfiguration initialization with default path")
    func test_aws_defaultConfiguration_initWithDefaultPath() {
      // GIVEN: Default engine path

      // WHEN: Creating default configuration
      let sut = HashiCorpVaultReader.Engine.AWS.DefaultConfiguration()

      // THEN: Default path is set
      #expect(sut.defaultEnginePath == "aws")
    }

    @Test("AWS DefaultConfiguration initialization with custom path")
    func test_aws_defaultConfiguration_initWithCustomPath() {
      // GIVEN: Custom engine path
      let customPath = "aws-prod"

      // WHEN: Creating default configuration
      let sut = HashiCorpVaultReader.Engine.AWS.DefaultConfiguration(
        defaultEnginePath: customPath
      )

      // THEN: Custom path is set
      #expect(sut.defaultEnginePath == customPath)
    }

    @Test("AWS DefaultConfiguration decoding from JSON")
    func test_aws_defaultConfiguration_decodingFromJSON() throws {
      // GIVEN: JSON configuration data
      let jsonData = """
      {
        "defaultEnginePath": "aws-production"
      }
      """.data(using: .utf8)!

      // WHEN: Decoding configuration
      let decoder = JSONDecoder()
      let sut = try decoder.decode(
        HashiCorpVaultReader.Engine.AWS.DefaultConfiguration.self,
        from: jsonData
      )

      // THEN: Configuration is decoded correctly
      #expect(sut.defaultEnginePath == "aws-production")
    }

    @Test("AWS DefaultConfiguration decoding with missing path uses default")
    func test_aws_defaultConfiguration_decodingWithMissingPath_usesDefault() throws {
      // GIVEN: Empty JSON configuration data
      let jsonData = "{}".data(using: .utf8)!

      // WHEN: Decoding configuration
      let decoder = JSONDecoder()
      let sut = try decoder.decode(
        HashiCorpVaultReader.Engine.AWS.DefaultConfiguration.self,
        from: jsonData
      )

      // THEN: Default path is used
      #expect(sut.defaultEnginePath == "aws")
    }

    @Test("AWS Element initialization")
    func test_aws_element_initialization() {
      // GIVEN: Element parameters
      let enginePath = "aws"
      let role = "my-role"
      let key = "accessKey"

      // WHEN: Creating element
      let sut = HashiCorpVaultReader.Engine.AWS.Element(
        enginePath: enginePath,
        role: role,
        key: key
      )

      // THEN: Element properties are set correctly
      #expect(sut.enginePath == enginePath)
      #expect(sut.role == role)
      #expect(sut.key == key)
    }

    @Test("AWS Element decoding from JSON with configuration")
    func test_aws_element_decodingFromJSON() throws {
      // GIVEN: JSON element data and configuration
      let jsonData = """
      {
        "enginePath": "aws-prod",
        "role": "my-role",
        "key": "secretKey"
      }
      """.data(using: .utf8)!

      let configuration = EngineTests.createMockConfiguration()

      // WHEN: Decoding element
      let decoder = JSONDecoder()
      let sut = try decoder.decode(
        HashiCorpVaultReader.Engine.AWS.Element.self,
        from: jsonData,
        configuration: configuration
      )

      // THEN: Element is decoded correctly
      #expect(sut.enginePath == "aws-prod")
      #expect(sut.role == "my-role")
      #expect(sut.key == "secretKey")
    }

    @Test("AWS Element decoding uses default engine path")
    func test_aws_element_decodingUsesDefaultEnginePath() throws {
      // GIVEN: JSON element data without enginePath and configuration with default
      let jsonData = """
      {
        "role": "my-role",
        "key": "accessKey"
      }
      """.data(using: .utf8)!

      let configuration = EngineTests.createMockConfiguration()

      // WHEN: Decoding element
      let decoder = JSONDecoder()
      let sut = try decoder.decode(
        HashiCorpVaultReader.Engine.AWS.Element.self,
        from: jsonData,
        configuration: configuration
      )

      // THEN: Default engine path is used
      #expect(sut.enginePath == "aws")
      #expect(sut.role == "my-role")
      #expect(sut.key == "accessKey")
    }

    @Test("AWS Element decoding without enginePath or default throws error")
    func test_aws_element_decodingWithoutEnginePath_throwsError() throws {
      // GIVEN: JSON element data without enginePath and configuration without default
      let jsonData = """
      {
        "role": "my-role",
        "key": "accessKey"
      }
      """.data(using: .utf8)!

      let configuration = HashiCorpVaultReader.Configuration(
        vaultAddress: URL(string: "https://vault.example.com")!,
        defaultEngineConfigurations: .init(), // No AWS default configuration
        authenticationCredentials: .init(),
        authenticationMethod: .token
      )

      // WHEN/THEN: Decoding should throw error
      let decoder = JSONDecoder()
      #expect(throws: DecodingError.self) {
        try decoder.decode(
          HashiCorpVaultReader.Engine.AWS.Element.self,
          from: jsonData,
          configuration: configuration
        )
      }
    }

    @Test("AWS API adaptURLRequest for element")
    func test_aws_api_adaptURLRequest() throws {
      // GIVEN: API instance, URL request, and element
      let sut = HashiCorpVaultReader.Engine.AWS.API()
      let baseURL = URL(string: "https://vault.example.com/v1")!
      let urlRequest = URLRequest(url: baseURL)

      let element = HashiCorpVaultReader.Engine.AWS.Element(
        enginePath: "aws",
        role: "my-role",
        key: "accessKey"
      )
      let uniqueElement = HashiCorpVaultReader.UniqueItem.AWS(source: element)

      // WHEN: Adapting URL request
      let result = try sut.adaptURLRequest(urlRequest: urlRequest, for: uniqueElement)

      // THEN: URL is adapted correctly
      #expect(result.url?.absoluteString == "https://vault.example.com/v1/aws/creds/my-role")
    }

    @Test("AWS API decodeGetSecretsResult")
    func test_aws_api_decodeGetSecretsResult() throws {
      // GIVEN: API instance and mock response data
      let sut = HashiCorpVaultReader.Engine.AWS.API()
      let responseData = """
      {
        "data": {
          "accessKey": "AKIA123456789",
          "secretKey": "secret123456789"
        }
      }
      """.data(using: .utf8)!

      // WHEN: Decoding get secrets result
      let result = try sut.decodeGetSecretsResult(data: responseData)

      // THEN: Secrets are decoded correctly
      #expect(result["accessKey"] == "AKIA123456789")
      #expect(result["secretKey"] == "secret123456789")
      #expect(result.count == 2)
    }

    @Test("AWS GetSecretsResult initialization")
    func test_aws_getSecretsResult_initialization() {
      // GIVEN: Access key and secret key
      let accessKey = "AKIA123456789"
      let secretKey = "secret123456789"

      // WHEN: Creating GetSecretsResult
      let sut = HashiCorpVaultReader.Engine.AWS.API.GetSecretsResult(
        accessKey: accessKey,
        secretKey: secretKey
      )

      // THEN: Properties are set correctly
      #expect(sut.accessKey == accessKey)
      #expect(sut.secretKey == secretKey)
    }

    @Test("AWS GetSecretsResult secrets property")
    func test_aws_getSecretsResult_secretsProperty() {
      // GIVEN: GetSecretsResult with keys
      let accessKey = "AKIA123456789"
      let secretKey = "secret123456789"
      let sut = HashiCorpVaultReader.Engine.AWS.API.GetSecretsResult(
        accessKey: accessKey,
        secretKey: secretKey
      )

      // WHEN: Accessing secrets property
      let secrets = sut.secrets

      // THEN: Secrets contain both keys
      #expect(secrets["accessKey"] == accessKey)
      #expect(secrets["secretKey"] == secretKey)
      #expect(secrets.count == 2)
    }

    @Test("AWS GetSecretsResult decoding from JSON")
    func test_aws_getSecretsResult_decodingFromJSON() throws {
      // GIVEN: JSON result data
      let jsonData = """
      {
        "accessKey": "AKIA123456789",
        "secretKey": "secret123456789"
      }
      """.data(using: .utf8)!

      // WHEN: Decoding result
      let decoder = JSONDecoder()
      let sut = try decoder.decode(
        HashiCorpVaultReader.Engine.AWS.API.GetSecretsResult.self,
        from: jsonData
      )

      // THEN: Result is decoded correctly
      #expect(sut.accessKey == "AKIA123456789")
      #expect(sut.secretKey == "secret123456789")
    }
  }

  // MARK: - Helper Methods

  private static func createMockConfiguration() -> HashiCorpVaultReader.Configuration {
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
