import Foundation
import Testing

@testable import ImportSecrets
@testable import Shell

@Suite("ImportSecrets Tests")
class ImportSecretsTests {
  func buildConfiguration(mockOnePasswordCLI: MockOnePasswordCLI? = .none) throws -> ImportSecrets.Configuration {
    try MocksBuilder.configuration(
      secrets: [
        MocksBuilder.onePasswordSecret(
          prefix: "TEST_MPCT_SECRET1_OP_ONLY_",
          item: "shared-item",
          label: "item1-secret",
        ),
        MocksBuilder.onePasswordSecret(
          prefix: "TEST_MPCT_SECRET2_MULTILINE_",
          item: "shared-item",
          label: "item1-multiline",
        ),
        MocksBuilder.onePasswordSecret(
          prefix: "TEST_MPCT_SECRET3_OP_AND_FAKE_",
          item: "database-item",
          label: "item2-secret",
        ),
      ],
      onePasswordCLI: mockOnePasswordCLI ?? self.mockOnePasswordCLI,
    )
  }

  var secrets: [String: String] = [
    "TEST_MPCT_SECRET1_OP_ONLY_item1_secret": "test-item1-secret-value",
    "TEST_MPCT_SECRET2_MULTILINE_item1_multiline": "test-item1\nmultiline-value",
    "TEST_MPCT_SECRET3_OP_AND_FAKE_item2_secret": "test-item2-secret-value",
  ]

  let mockOnePasswordCLI: MockOnePasswordCLI = {
    let mock = MockOnePasswordCLI()
    mock.mockFields = [
      "shared-item": ["item1-secret": "test-item1-secret-value", "item1-multiline": "test-item1\nmultiline-value"],
      "database-item": ["item2-secret": "test-item2-secret-value"],
    ]
    return mock
  }()

  var mockFileManager: MockFileManager = .init()

  init() {
    // SET UP
  }

  deinit {
    // TEAR DOWN
  }

  // MARK: - Mock Implementations

  final class MockFileManager: FileManagerProtocol, @unchecked Sendable {
    var createdFiles: [(path: String, contents: Data?)] = []
    var shouldSucceed: Bool = true

    func createFile(atPath path: String, contents data: Data?, attributes attr: [FileAttributeKey: Any]?) -> Bool {
      createdFiles.append((path: path, contents: data))
      return shouldSucceed
    }

    func contents(atPath path: String) -> Data? { createdFiles.first { $0.path == path }?.contents }
  }

  // MARK: - getSecrets Tests

  static func require<T>(
    _ block: @autoclosure () async throws -> T,
    _ comment: @autoclosure () -> Comment? = nil,
    sourceLocation: SourceLocation = #_sourceLocation,
  ) async throws -> T {
    do { return try await block() }
    catch {
      #expect(
        Bool(false),
        "\(comment()?.rawValue ?? "")Expected no error but got: \(error)",
        sourceLocation: sourceLocation,
      )
      throw error
    }
  }

  static func require<T>(
    _ block: @autoclosure () throws -> T,
    _ comment: @autoclosure () -> Comment? = nil,
    sourceLocation: SourceLocation = #_sourceLocation,
  ) throws -> T {
    do { return try block() }
    catch {
      #expect(
        Bool(false),
        "\(comment()?.rawValue ?? "")Expected no error but got: \(error)",
        sourceLocation: sourceLocation,
      )
      throw error
    }
  }

  @Test("getSecrets retrieves multiple ENV vars with shared 1Password item")
  func test_getSecrets_multipleEnvVarsWithSharedItem() async throws {
    // GIVEN: Configuration with 3 ENV vars, 2 using same 1Password item but different labels
    let configuration = try buildConfiguration()

    // WHEN: Getting secrets from configuration
    let result = try await Self.require(await ImportSecrets.getSecrets(configuration: configuration))

    // THEN: All environment variables are populated with correct values
    #expect(result["TEST_MPCT_SECRET1_OP_ONLY_item1_secret"] == "test-item1-secret-value")
    #expect(result["TEST_MPCT_SECRET2_MULTILINE_item1_multiline"] == "test-item1\nmultiline-value")
    #expect(result["TEST_MPCT_SECRET3_OP_AND_FAKE_item2_secret"] == "test-item2-secret-value")
    #expect(result.count == 3)
    #expect(result == secrets)

    // THEN: 1Password CLI is called efficiently - only 2 calls for 2 unique items
    #expect(mockOnePasswordCLI.getItemFieldsCalls.count == 2)

    // THEN: Shared item is fetched with both required labels
    let sharedItemCall = try #require(mockOnePasswordCLI.getItemFieldsCalls.first { $0.item == "shared-item" })
    #expect(sharedItemCall.labels.sorted() == ["item1-multiline", "item1-secret"].sorted())

    // THEN: Database item is fetched with its label
    let databaseItemCall = try #require(mockOnePasswordCLI.getItemFieldsCalls.first { $0.item == "database-item" })
    #expect(databaseItemCall.labels.sorted() == ["item2-secret"].sorted())
  }

  @Test("getSecrets throws error when no secrets to fetch")
  func test_getSecrets_noSecretsToFetch() async throws {
    // GIVEN: Configuration with no secrets
    let configuration = try MocksBuilder.configuration(secrets: [])

    // WHEN/THEN: Getting secrets throws noSecretsToFetch error
    await #expect(throws: ImportSecrets.Error.self) { try await ImportSecrets.getSecrets(configuration: configuration) }

    // THEN: No 1Password CLI calls are made
    #expect(mockOnePasswordCLI.getItemFieldsCalls.isEmpty)
  }
}
