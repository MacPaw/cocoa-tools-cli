import Foundation
import HashiCorpVaultReader
import SecretsInterface
import Testing

@testable import ImportSecrets
@testable import Shell

final class MockHashiCorpVaultReaderProtocol: HashiCorpVaultReaderProtocol {
  func initialize(configuration: HashiCorpVaultReader.Configuration) async throws {}

  func fetchItem(
    _ item: HashiCorpVaultReader.Element.Item,
    keys: Set<String>,
    configuration: HashiCorpVaultReader.Configuration
  ) async throws -> [String: String] { [:] }
}

@Suite("ImportSecrets Decoding Tests")
struct ImportSecretsDecodingTests {
  // MARK: - Helper Methods

  private static func buildProviders() -> [any SecretProviderProtocol] {
    [
      ImportSecrets.Providers.FakeProvider(fetcher: .init()),
      ImportSecrets.Providers.OnePassword(fetcher: .init(onePasswordCLI: MockOnePasswordCLI())),
    ]
  }

  private static func buildConfiguration() throws -> ImportSecrets.Configuration {
    guard let data = YamlMocks.yamlContent.data(using: .utf8) else { throw TestError.dataConversionFailed }
    do { return try ImportSecrets.configuration(configurationData: data, sourceProviders: buildProviders()) }
    catch {
      #expect(Bool(false), "Got error: \(error)")
      throw error
    }
  }

  private enum TestError: Error { case dataConversionFailed }

  // MARK: - Tests

  @Test("Configuration decoding from YAML succeeds")
  func test_configuration_decodingFromYAMLSucceeds() throws {
    // GIVEN: Valid YAML configuration data and source providers
    let data = YamlMocks.yamlContent.data(using: .utf8)!
    let sourceProviders = Self.buildProviders()

    // WHEN: Decoding configuration from YAML data
    let sut = try ImportSecrets.configuration(configurationData: data, sourceProviders: sourceProviders)

    // THEN: Configuration is successfully decoded with correct properties
    #expect(sut.version == 1)

    // THEN: Secrets have correct environment variable names
    let prefixes = sut.secrets.map(\.prefix)
    #expect(prefixes.contains("TEST_MPCT_SECRET1_OP_ONLY_"))
    #expect(prefixes.contains("TEST_MPCT_SECRET2_MULTILINE_"))
    #expect(prefixes.contains("TEST_MPCT_SECRET3_OP_AND_FAKE_"))
    #expect(prefixes.contains("TEST_MPCT_SECRET4_FAKE_ONLY_"))
    #expect(prefixes.contains("TEST_MPCT_SECRET5_OP_MISSING_FAKE_EXISTS_"))
  }

  @Test("Secret decoding with multiple sources succeeds")
  func test_secret_decodingWithMultipleSourcesSucceeds() throws {
    // GIVEN: Configuration with secrets having multiple sources
    let sut = try Self.buildConfiguration()

    // WHEN: Getting a secret with multiple sources
    let multilineSecret = try #require(sut.secrets.first { $0.prefix == "TEST_MPCT_SECRET2_MULTILINE_" })

    // THEN: Secret has multiple available source keys
    #expect(multilineSecret.availableSourceKeys.count == 2)

    // THEN: Secret has both fake-source and op sources
    let sourceKeys = multilineSecret.availableSourceKeys
    #expect(sourceKeys.contains("fake-source"))
    #expect(sourceKeys.contains("op"))
  }

  @Test("SourceConfigurations decoding succeeds")
  func test_sourceConfigurations_decodingSucceeds() throws {
    // GIVEN: Configuration with source configurations
    let sut = try Self.buildConfiguration()

    // WHEN: Accessing source configurations
    let sourceConfigurations = sut.sourceConfigurations

    // THEN: Source configurations are properly decoded
    let fakeConfig: ImportSecrets.Providers.FakeProvider.Source.Configuration? =
      try sourceConfigurations.getConfiguration(for: "fake-source")
    #expect(fakeConfig != nil, "FakeProvider configuration should be decoded")
    #expect(fakeConfig?.url?.absoluteString == "https://macpaw.com")

    let opConfig: ImportSecrets.Providers.OnePassword.Source.Configuration? = try sourceConfigurations.getConfiguration(
      for: "op"
    )
    #expect(opConfig != nil, "OnePassword configuration should be decoded")
    #expect(opConfig?.vault == "personal")
  }

  @Test("Configuration validation with duplicate env vars throws error")
  func test_configuration_validationWithDuplicateEnvVarsThrowsError() throws {
    // GIVEN: YAML configuration with duplicate environment variable names
    let duplicateYaml = """
      version: 1
      sourceConfigurations:
        fake-source:
          url: https://macpaw.com
      secrets:
        DUPLICATE_VAR:
          sources:
            fake-source:
              path: /test/path1
              key: key1
        DUPLICATE_VAR:
          sources:
            fake-source:
              path: /test/path2
              key: key2
      """
    let data = duplicateYaml.data(using: .utf8)!

    // WHEN: Creating configuration from Data
    // THEN: Decoding fails
    #expect(throws: Swift.DecodingError.self) {
      try ImportSecrets.configuration(configurationData: data, sourceProviders: Self.buildProviders())
    }
  }

  @Test("Configuration decoding with missing sourceConfigurations succeeds")
  func test_configuration_decodingWithMissingSourceConfigurationsSucceeds() throws {
    // GIVEN: YAML configuration without sourceConfigurations section
    let minimalYaml = """
      version: 1
      secrets:
        - prefix: TEST_SECRET_
          sources:
            fake-source:
              path: /test/path
              keys: 
                - key
      """
    let data = minimalYaml.data(using: .utf8)!

    // WHEN: Decoding configuration from YAML data
    let sut = try ImportSecrets.configuration(configurationData: data, sourceProviders: Self.buildProviders())

    // THEN: Configuration is successfully decoded with empty source configurations
    #expect(sut.version == 1)
    #expect(sut.secrets.count == 1)
    #expect(sut.secrets[0].prefix == "TEST_SECRET_")
  }
}
