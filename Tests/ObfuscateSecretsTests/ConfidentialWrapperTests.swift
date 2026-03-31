#if !os(Linux)
  import Foundation
  import Shell
  import Testing

  @testable import ObfuscateSecrets

  @Suite("ObfuscateSecrets")
  final class ObfuscateSecretsTests {
    let fileManager: FileManager = .default
    let inputFileURL: URL
    let outputFileURL: URL
    let tempDirectoryURL: URL

    init() throws {
      // Set up
      tempDirectoryURL = fileManager.temporaryDirectory.appending(
        components: "obfuscate-secrets-tests",
        UUID().uuidString,
        directoryHint: .isDirectory,
      )
      inputFileURL = tempDirectoryURL.appending(path: "input.yaml", directoryHint: .notDirectory)
      outputFileURL = tempDirectoryURL.appending(path: "input.yaml", directoryHint: .isDirectory)

      try fileManager.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)

      try Self.inputConfigurationString.write(to: inputFileURL, atomically: true, encoding: .utf8)
    }

    deinit {
      // Tear down
      for url in [inputFileURL, outputFileURL, tempDirectoryURL] { try? fileManager.removeItem(at: url) }
    }

    /// Testing environment.
    static let environment: [String: String] = ["ENV_VARIABLE_NAME1": "bar", "ENV_VARIABLE_NAME2": "baz"]

    /// swift-confidential configuration.
    static let inputConfigurationString: String = """
      algorithm:
        - encrypt using aes-128-gcm
      defaultAccessModifier: public
      secrets:
        - name: variable_name1
          value: $ENV_VARIABLE_NAME1
        - name: variable_name2
          value: $ENV_VARIABLE_NAME2
      """

    /// Expected output w/o data and nonce.
    static let expectedString: String = """
      import ConfidentialKit

      extension ConfidentialCore.Obfuscation.Secret {

          public static #Obfuscate(algorithm: .custom([.encrypt(algorithm: .aes128GCM)])) {
              let variable_name1 = "bar"
              let variable_name2 = "baz"
          }
      }
      """

    func validate(outputFileURL: URL, _ sourceLocation: SourceLocation = #_sourceLocation, ) throws {
      let obfuscatedString = try String(contentsOf: outputFileURL, encoding: .utf8)

      #expect(obfuscatedString == Self.expectedString, sourceLocation: sourceLocation)
    }
  }

  extension ObfuscateSecretsTests {
    @Test("#obfuscate with CLI")
    func test_obfuscate_withCLI() throws {
      // SET UP
      // When running in Xcode: tests run in a temp dir, and mise fails to recognize tool, because is not currently active.
      // If swift-confidential is not found by /usr/bin/which - install it with mise.
      if (try? Shell.which(cliToolName: "swift-confidential")) == nil {
        do { try Shell.Mise().use(cliToolName: "github:securevale/swift-confidential", version: "0.5.1") }
        catch { #expect(Bool(false), "Unexpected error while installing swift-confidential: \(error)") }
      }

      // GIVEN
      let environment: [String: String] = Self.environment.merging(ProcessInfo.processInfo.environment) { old, _ in old
      }
      let sut = ObfuscateSecrets.self

      // WHEN
      do {
        try sut.substituteEnvAndObfuscateWithCLI(
          inputFileURL: inputFileURL,
          outputFileURL: outputFileURL,
          environment: environment,
        )
      }
      catch { #expect(Bool(false), "Got error: \(error)") }

      // THEN
      try validate(outputFileURL: self.outputFileURL)
    }
  }

  #if canImport(ConfidentialObfuscator)
    extension ObfuscateSecretsTests {
      @Test("#obfuscate with library")
      func test_obfuscate_withLibrary() throws {
        // GIVEN
        let sut = ObfuscateSecrets.self

        // WHEN
        try #require(
          try? sut.substituteEnvAndObfuscateWithLibrary(
            inputFileURL: inputFileURL,
            outputFileURL: outputFileURL,
            environment: Self.environment,
          )
        )

        // THEN
        try validate(outputFileURL: self.outputFileURL)
      }
    }
  #endif

#endif
