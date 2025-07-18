import Foundation

@testable import ExportSecrets

final class MockMiseCLI: SecretsDestinationMiseProtocol, @unchecked Sendable {
  var exportCalls: [(secrets: [String: String], file: String?)] = []
  var shouldThrow: Bool = false

  func export(secrets: [String: String], file: String?) throws {
    exportCalls.append((secrets: secrets, file: file))
    if shouldThrow { throw NSError(domain: "MockError", code: 1) }
  }
}
