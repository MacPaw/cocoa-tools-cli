#if canImport(CryptoKit)
  package import EnvSubst
  package import Foundation

  extension ObfuscateSecrets {
    /// Substitutes environment variables in a swift-confidential configuration and writes Swift source that decrypts
    /// its secrets with CryptoKit, with no package dependency.
    ///
    /// - Parameters:
    ///   - inputFileURL: The swift-confidential YAML configuration.
    ///   - outputFileURL: The Swift source file to write.
    ///   - environment: Variables to substitute into the configuration.
    ///   - options: Substitution options.
    ///   - encoding: The encoding of the configuration and of the output.
    ///   - fileManager: The file manager used to read the configuration.
    /// - Throws: An error if the configuration can't be read, substituted or decoded, or the output can't be written.
    package static func substituteEnvAndGenerateWithCryptoKit(
      inputFileURL: URL,
      outputFileURL: URL,
      environment: [String: String] = ProcessInfo.processInfo.environment,
      options: EnvSubst.Options = .strict,
      encoding: String.Encoding = .utf8,
      fileManager: FileManager = .default,
    ) throws {
      let configurationData = try substituteEnv(
        inputFileURL: inputFileURL,
        environment: environment,
        options: options,
        encoding: encoding,
        fileManager: fileManager,
      )
      let text = try CryptoKitSecretsGenerator.generate(configurationData: configurationData)
      // An unchanged file keeps its modification date, so builds don't recompile it.
      if let existing = try? String(contentsOf: outputFileURL, encoding: encoding), existing == text { return }
      try text.write(to: outputFileURL, atomically: true, encoding: encoding)
    }
  }
#endif
