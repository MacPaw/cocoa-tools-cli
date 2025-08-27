#if canImport(ConfidentialKit)
  import ConfidentialKit
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
        directoryHint: .isDirectory
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

    /// The resolved values of the obfuscated secret variables.
    static let obfuscatedSecretValues: [String: String] = ["variable_name1": "bar", "variable_name2": "baz"]

    /// Expected output w/o data and nonce.
    static let expectedString: String = """
      import ConfidentialKit
      import Foundation

      extension ConfidentialKit.Obfuscation.Secret {

          @ConfidentialKit.Obfuscated<Swift.String>(deobfuscateData)
          public static var variable_name1: ConfidentialKit.Obfuscation.Secret = .init(data: [], nonce: 0)

          @ConfidentialKit.Obfuscated<Swift.String>(deobfuscateData)
          public static var variable_name2: ConfidentialKit.Obfuscation.Secret = .init(data: [], nonce: 0)

          @inline(__always)
          private static func deobfuscateData(_ data: Foundation.Data, nonce: Swift.UInt64) throws -> Foundation.Data {
              try ConfidentialKit.Obfuscation.Encryption.DataCrypter(algorithm: .aes128GCM)
                  .deobfuscate(data, nonce: nonce)
          }
      }
      """

    // MARK: Regexes

    /// Bytes regex.
    ///
    /// Matches `0xFF`. First group is the string byte representation: `FF`.
    let byteRegex: Regex = /0x([0-9a-fA-F]{1,2}),?\s?+/
    /// Data init regex.
    ///
    /// Matches `(data: [0xFF, 0xFF...], nonce: 000)`.
    let dataReplacementRegex: Regex = #/\(data:\s?+\[((0x([0-9a-fA-F]{1,2}),?\s?+)+)\],\s?+nonce:\s?+(\d+)\)/#
    /// Secret variable regex.
    ///
    /// Matches: `var variableName: Type = .init(data: [0xFF, 0xFF...], nonce: 000)`.
    /// First group is the variable name (`variableName`).
    /// Third group is the bytes list (`0xFF, 0xFF...`). We match it with the `byteRegex` to get the byte string.
    /// Sixth group is the nonce value (`value`).
    let secretVariableRegex: Regex =
      #/var\s+(.*)\s?+:\s?+.*=\s+.*(\(data:\s?+\[((0x([0-9a-fA-F]{1,2}),?\s?+)+)\],\s?+nonce:\s?+(\d+)\))/#

    // MARK: Validators

    private func validateContentsWithoutDataAndNonce(
      obfuscatedString: String,
      _ sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
      let obfuscatedString = obfuscatedString.replacing(dataReplacementRegex, with: "(data: [], nonce: 0)")

      #expect(obfuscatedString == Self.expectedString, sourceLocation: sourceLocation)
    }

    private func validateSecretValues(
      _ secretValues: [String: String],
      in obfuscatedString: String,
      _ sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
      let crypter = Obfuscation.Encryption.DataCrypter(algorithm: .aes128GCM)

      let deobfuscationResult = try obfuscatedString.matches(of: secretVariableRegex)
        .reduce(into: [String: String]()) { (accum, globalMatch) in
          let variableName = String(globalMatch.output.1)

          let obfuscatedBytes = try globalMatch.output.3  // Get matches for all `0xFF`
            .matches(of: byteRegex)  // Convert to a byte
            .map { byteMatch in try #require(UInt8(byteMatch.output.1, radix: 16), sourceLocation: sourceLocation) }

          let nonceValue: UInt64 = try #require(UInt64(globalMatch.output.6), sourceLocation: sourceLocation)

          let secret = ConfidentialKit.Obfuscation.Secret(data: obfuscatedBytes, nonce: nonceValue)
          let obfuscated = ConfidentialKit.Obfuscated<Swift.String>(wrappedValue: secret, crypter.deobfuscate)

          accum[variableName] = obfuscated.projectedValue
        }

      #expect(deobfuscationResult == secretValues, sourceLocation: sourceLocation)
    }

    func validate(
      outputFileURL: URL,
      secretValues: [String: String],
      _ sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
      let obfuscatedString = try String(contentsOf: outputFileURL, encoding: .utf8)

      try validateContentsWithoutDataAndNonce(obfuscatedString: obfuscatedString, sourceLocation)
      try validateSecretValues(secretValues, in: obfuscatedString, sourceLocation)
    }
  }

  extension ObfuscateSecretsTests {
    @Test("#obfuscate with CLI")
    func test_obfuscate_withCLI() throws {
      // SET UP
      // When running in Xcode: tests run in a temp dir, and mise fails to recognize tool, because is not currently active.
      // If swift-confidential is not found by /usr/bin/which - install it with mise.
      if (try? Shell.which(cliToolName: "swift-confidential")) == nil {
        try Shell.Mise().use(cliToolName: "ubi:securevale/swift-confidential", version: "0.4.1")
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
          environment: environment
        )
      }
      catch { #expect(Bool(false), "Got error: \(error)") }

      // THEN
      try validate(outputFileURL: self.outputFileURL, secretValues: Self.obfuscatedSecretValues)
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
            environment: Self.environment
          )
        )

        // THEN
        try validate(outputFileURL: self.outputFileURL, secretValues: Self.obfuscatedSecretValues)
      }
    }
  #endif

#endif
