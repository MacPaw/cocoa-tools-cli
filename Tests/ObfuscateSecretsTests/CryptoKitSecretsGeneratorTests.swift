#if canImport(CryptoKit)
  import CryptoKit
  import Foundation
  import Testing

  @testable import ObfuscateSecrets

  @Suite("CryptoKitSecretsGenerator")
  struct CryptoKitSecretsGeneratorTests {
    static let configuration = """
      algorithm:
        - encrypt using chacha20-poly
        - shuffle
      defaultAccessModifier: internal
      defaultNamespace: extend Constants
      secrets:
        - name: apiKey
          value: "secret-value"
        - name: hosts
          value:
            - one.example.com
            - two.example.com
        - name: token
          value: "other"
          namespace: create Tokens
      """

    @Test("generate same configuration twice gives the same source")
    func test_generate_sameConfigurationTwiceGivesTheSameSource() throws {
      // GIVEN
      let sut = CryptoKitSecretsGenerator.self
      let data = Data(Self.configuration.utf8)

      // WHEN
      let first = try sut.generate(configurationData: data)
      let second = try sut.generate(configurationData: data)

      // THEN
      #expect(first == second)
    }

    @Test("generate changed value gives different source")
    func test_generate_changedValueGivesDifferentSource() throws {
      // GIVEN
      let sut = CryptoKitSecretsGenerator.self
      let changed = Self.configuration.replacingOccurrences(of: "secret-value", with: "secret-valuf")

      // WHEN
      let original = try sut.generate(configurationData: Data(Self.configuration.utf8))
      let updated = try sut.generate(configurationData: Data(changed.utf8))

      // THEN
      #expect(original != updated)
    }

    @Test("seal box opens with its key to the original payload")
    func test_seal_boxOpensWithItsKeyToTheOriginalPayload() throws {
      // GIVEN
      let payload = Data("secret-value".utf8)

      // WHEN
      let sut = try CryptoKitSecretsGenerator.seal(payload, name: "apiKey")
      let opened = try ChaChaPoly.open(ChaChaPoly.SealedBox(combined: sut.box), using: SymmetricKey(data: sut.key))

      // THEN
      #expect(opened == payload)
      #expect(sut.box.count == 12 + payload.count + 16)
    }

    @Test("seal same secret under another name gives another box")
    func test_seal_sameSecretUnderAnotherNameGivesAnotherBox() throws {
      // GIVEN
      let payload = Data("secret-value".utf8)

      // WHEN
      let first = try CryptoKitSecretsGenerator.seal(payload, name: "apiKey")
      let second = try CryptoKitSecretsGenerator.seal(payload, name: "otherKey")

      // THEN
      #expect(first.box != second.box)
      #expect(first.key != second.key)
    }

    @Test("generate secret name that isn't an identifier throws")
    func test_generate_secretNameThatIsNotAnIdentifierThrows() {
      // GIVEN
      let configuration = "secrets:\n  - name: \"api-key\"\n    value: x\n"

      // WHEN / THEN
      #expect(throws: (any Error).self) {
        try CryptoKitSecretsGenerator.generate(configurationData: Data(configuration.utf8))
      }
    }

    @Test("generate unknown namespace form throws")
    func test_generate_unknownNamespaceFormThrows() {
      // GIVEN
      let configuration = "defaultNamespace: replace Constants\nsecrets:\n  - name: apiKey\n    value: x\n"

      // WHEN / THEN
      #expect(throws: (any Error).self) {
        try CryptoKitSecretsGenerator.generate(configurationData: Data(configuration.utf8))
      }
    }
  }
#endif
