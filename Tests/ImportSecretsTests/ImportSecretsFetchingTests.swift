import Foundation
import Testing

@testable import ImportSecrets
@testable import Shell

@Suite("ImportSecrets Fetching Tests")
struct ImportSecretsFetchingTests {
  private enum TestError: Error { case dataConversionFailed }

  // MARK: - Helper Methods
  private static func buildProviders(
    opCLIMock: MockOnePasswordCLI,
    fakeProviderFetcher: ImportSecrets.Providers.FakeProvider.Fetcher,
  ) -> [any SecretProviderProtocol] {
    [
      ImportSecrets.Providers.OnePassword(fetcher: .init(onePasswordCLI: opCLIMock)),
      ImportSecrets.Providers.FakeProvider(fetcher: fakeProviderFetcher),
    ]
  }

  var opCLIMock: MockOnePasswordCLI = .init()
  var fakeProviderFetcher: ImportSecrets.Providers.FakeProvider.Fetcher = .init()

  private func buildConfiguration(
    includeSecrets: [String]? = .none,
    removeSecrets: [String]? = .none,
    opCLIMock: MockOnePasswordCLI? = .none,
    fakeProviderFetcher: ImportSecrets.Providers.FakeProvider.Fetcher? = .none,
  ) throws -> ImportSecrets.Configuration {
    // Parse the full YAML configuration
    guard let data = YamlMocks.yamlContent.data(using: .utf8) else { throw TestError.dataConversionFailed }
    var configuration = try ImportSecrets.configuration(
      configurationData: data,
      sourceProviders: Self.buildProviders(
        opCLIMock: opCLIMock ?? self.opCLIMock,
        fakeProviderFetcher: fakeProviderFetcher ?? self.fakeProviderFetcher,
      ),
    )
    // Remove specified secrets from the configuration
    configuration.secrets = configuration.secrets.filter { secret in
      if let includeSecrets {
        includeSecrets.contains(secret.envVarName)
      }
      else if let removeSecrets {
        !removeSecrets.contains(secret.envVarName)
      }
      else {
        true
      }
    }
    return configuration
  }

  // MARK: - Full Configuration Tests

  @Test("ImportSecrets fetches secrets only from provided sources")
  func test_importSecrets_fetchesSecretsOnlyFromProvidedSources() async throws {
    // GIVEN: Full configuration from YamlMocks, excluding secrets with multiple sources and missing secret
    let configuration = try buildConfiguration(includeSecrets: [
      "TEST_MPCT_SECRET1_OP_ONLY", "TEST_MPCT_SECRET4_FAKE_ONLY",
    ])

    // WHEN: Getting secrets from configuration
    let result = try await ImportSecrets.getSecrets(configuration: configuration)

    // THEN: All available secrets are fetched successfully
    #expect(result["TEST_MPCT_SECRET1_OP_ONLY"] == "shared-item-secret-value")
    #expect(result["TEST_MPCT_SECRET4_FAKE_ONLY"] == "/test/mpct/item4/secret.key")
    #expect(result.count == 2)

    #expect(opCLIMock.getItemFieldsCalls.count == 1)
    #expect(self.fakeProviderFetcher.fetchSecretsCalls.count == 1)
  }

  @Test("ImportSecrets fallbacks to other secret fetchers")
  func test_importSecrets_fetchesFallbacksToOtherSecretFetchers() async throws {
    // GIVEN: Full configuration from YamlMocks, excluding secrets with multiple sources and missing secret
    let configuration = try buildConfiguration(includeSecrets: ["TEST_MPCT_SECRET5_OP_MISSING_FAKE_EXISTS"])

    // WHEN: Getting secrets from configuration
    let result = try await ImportSecrets.getSecrets(configuration: configuration)

    // THEN: All available secrets are fetched successfully
    #expect(result["TEST_MPCT_SECRET5_OP_MISSING_FAKE_EXISTS"] == "/test/mpct/item5/secret.key")
    #expect(result.count == 1)

    #expect(opCLIMock.getItemFieldsCalls.count == 1)
    #expect(self.fakeProviderFetcher.fetchSecretsCalls.count == 1)
  }

  // MARK: - Error Scenarios Based on YamlMocks Comments

  @Test("ImportSecrets throws error when both 1Password and fake provider fail")
  func test_importSecrets_throwsErrorWhenBoth1PasswordAndFakeProviderFail() async throws {
    // GIVEN: Configuration with TEST_MPCT_SECRET6_OP_MISSING_FAKE_MISSING that fails on both providers
    let configuration = try buildConfiguration(includeSecrets: ["TEST_MPCT_SECRET6_OP_MISSING_FAKE_MISSING"])

    // WHEN/THEN: Getting secrets throws error when both providers fail
    await #expect(
      throws: ImportSecrets.Error.failedToFetchSecrets([
        "TEST_MPCT_SECRET6_OP_MISSING_FAKE_MISSING": [
          String(
            describing: ImportSecrets.Providers.OnePassword.Fetcher.FetchError.failedToFetch(
              secret: "TEST_MPCT_SECRET6_OP_MISSING_FAKE_MISSING",
              labelMissing: "item6-secret",
            )
          ),
          String(
            describing: ImportSecrets.Providers.FakeProvider.Fetcher.FetchError.failedToFetch(
              keyMissing: "/test/mpct/item6/secret.missing"
            )
          ),
        ]
      ])
    ) { try await ImportSecrets.getSecrets(configuration: configuration) }
  }

  @Test("ImportSecrets throws error when no secrets configured")
  func test_importSecrets_throwsErrorWhenNoSecretsConfigured() async throws {
    // GIVEN: Configuration with all secrets removed
    let configuration = try buildConfiguration(includeSecrets: [])
    // WHEN/THEN: Getting secrets throws noSecretsToFetch error
    await #expect(throws: ImportSecrets.Error.self) { try await ImportSecrets.getSecrets(configuration: configuration) }
  }

  @Test("ImportSecrets throws error for unsupported provider")
  func test_importSecrets_throwsErrorForUnsupportedProvider() async throws {
    // GIVEN: YAML configuration with unsupported provider
    let yamlConfig = """
      version: 1
      sourceConfigurations:
        unsupported-provider:
          url: https://example.com
      secrets:
        TEST_SECRET:
          sources:
            unsupported-provider:
              path: /test/path
              key: key
      """
    // WHEN/THEN: Getting secrets throws unsupportedSecretSource error
    let data = yamlConfig.data(using: .utf8)!
    await #expect(throws: DecodingError.self) {
      try await ImportSecrets.getSecrets(
        configurationData: data,
        sourceProviders: Self.buildProviders(opCLIMock: opCLIMock, fakeProviderFetcher: fakeProviderFetcher),
      )
    }
  }
}
