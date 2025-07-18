import Foundation
import Testing

@testable import ExportSecrets
@testable import Shell

@Suite("ExportSecretsTests Tests")
class ExportSecretsTests {
  var secrets: [String: String] = [
    "TEST_MPCT_SECRET1_OP_ONLY": "test-item1-secret-value",
    "TEST_MPCT_SECRET2_MULTILINE": "test-item1\nmultiline-value",
    "TEST_MPCT_SECRET3_OP_AND_FAKE": "test-item2-secret-value",
  ]

  var mockFileManager: MockFileManager = .init()
  var mockMiseCLI: MockMiseCLI = .init()

  @Test("export to mise with custom local env")
  func test_export_miseWithLocalEnv() throws {
    // GIVEN
    let destination = ExportSecrets.Destinations.Mise(miseCLI: mockMiseCLI)

    // WHEN: Exporting secrets to mise
    try ExportSecrets.export(secrets: secrets, destination: destination)

    // THEN: Mise CLI is called once with correct parameters
    #expect(mockMiseCLI.exportCalls.count == 1)
    let exportCall = try #require(mockMiseCLI.exportCalls.first)
    #expect(exportCall.secrets == secrets)
    #expect(exportCall.file == "mise.local.toml")
  }

  @Test("export to dotenv with custom local env")
  func test_export_dotenvWithLocalEnv() throws {
    // GIVEN
    let destination = ExportSecrets.Destinations.DotEnv(fileManager: mockFileManager)

    // WHEN: Exporting secrets to dotenv
    try ExportSecrets.export(secrets: secrets, destination: destination)

    // THEN: File is created with correct path and contents
    #expect(mockFileManager.createdFiles.count == 1)
    let createdFile = try #require(mockFileManager.createdFiles.first)
    #expect(createdFile.path == ".env.local")

    // THEN: File contents contain all secrets in env format
    let fileContents = try #require(createdFile.contents)
    let contentsString = try #require(String(data: fileContents, encoding: .utf8))
    let lines = contentsString.components(separatedBy: "\n")

    let expectedLines = [
      // First secret
      "TEST_MPCT_SECRET1_OP_ONLY='test-item1-secret-value'",
      // Multiline second secret
      "TEST_MPCT_SECRET2_MULTILINE='test-item1", "multiline-value'",
      // Third secret
      "TEST_MPCT_SECRET3_OP_AND_FAKE='test-item2-secret-value'",
    ]

    #expect(lines == expectedLines)
  }

  @Test("export throws error when no secrets to export")
  func test_export_noSecretsToExport() throws {
    // GIVEN: Empty secrets dictionary
    let emptySecrets: [String: String] = [:]
    let destination = ExportSecrets.Destinations.Stdout()

    // WHEN/THEN: Exporting empty secrets throws noSecretsToExport error
    #expect(throws: ExportSecrets.Error.noSecretsToExport) {
      try ExportSecrets.export(secrets: emptySecrets, destination: destination)
    }
  }
}
