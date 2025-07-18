import ImportSecrets

final class MockOnePasswordCLI: OnePasswordCLIProtocol, @unchecked Sendable {
  var mockFields: [String: [String: String]] = [
    "[TEST] mpct.import-secrets.shared-item": [
      "item1-secret": "shared-item-secret-value", "item1-multiline": "shared-item\nmultiline-value",
    ], "[TEST] mpct.import-secrets.database-item": ["item2-secret": "database-item-secret-value"],
  ]
  var getItemFieldsCalls: [(account: String?, vault: String?, item: String, labels: [String])] = []

  func getItemFields(account: String?, vault: String?, item: String, labels: [String]) throws -> [String: String] {
    getItemFieldsCalls.append((account: account, vault: vault, item: item, labels: labels))
    return mockFields[item] ?? [:]
  }

  static let `default`: MockOnePasswordCLI = .init()
}
