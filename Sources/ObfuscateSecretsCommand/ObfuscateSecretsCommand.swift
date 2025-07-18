import ArgumentParser
@_exported public import EnvSubst
@_exported public import EnvSubstCommand
import Foundation
@_exported public import ImportSecrets
@_exported public import ImportSecretsCommand

#if canImport(ObfuscateSecrets)
  import ObfuscateSecrets

  public struct ObfuscateSecretsCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
      commandName: "obfuscate",
      abstract: "Obfuscate secret literals with swift-confidential.",
      discussion: """
        The generated Swift code provides accessors for each secret literal, \
        grouped into namespaces as defined in configuration file. \
        The accessor allows for retrieving a deobfuscated literal at \
        runtime.
        """
    )

    @OptionGroup(title: "swift-confidential options")
    var confidentialOptions: SwiftConfidentialOptions

    @OptionGroup(title: "envsubst options")
    var envSusbstOptions: EnvSubstCommand.Options

    @OptionGroup(title: "Secrets import options")
    var importSecretsOptions: ImportSecretsOptions

    /// The path to an output source file where the generated Swift code is to be written.
    @Option(
      name: [.short, .customLong("output")],
      help: "The path to an output source file where the generated Swift code is to be written",
      transform: URL.init(fileURLWithPath:)
    )
    var outputURL: URL

    public init() {}

    public mutating func validate() throws {
      try confidentialOptions.validate()
      try importSecretsOptions.validate()
      try envSusbstOptions.validate()
    }

    public mutating func run() async throws {
      var environment: [String: String] = ProcessInfo.processInfo.environment

      if let importSecretsConfigurationURL = importSecretsOptions.configurationURL,
        !importSecretsOptions.sources.isEmpty
      {
        let secrets = try await ImportSecrets.getSecrets(
          configurationURL: importSecretsConfigurationURL,
          sourceProviders: ImportSecretsCommand.Options.sourceProviders(sources: importSecretsOptions.sources),
          envSubstOptions: envSusbstOptions.options
        )
        environment.merge(secrets) { old, new in importSecretsOptions.overwriteExistingEnv ? new : old }
      }

      #if canImport(ConfidentialObfuscator)
        try ObfuscateSecrets.substituteEnvAndObfuscateWithLibrary(
          inputFileURL: confidentialOptions.configurationURL,
          outputFileURL: outputURL,
          environment: environment,
          options: envSusbstOptions.options
        )
      #else
        try ObfuscateSecrets.substituteEnvAndObfuscateWithCLI(
          inputFileURL: confidentialOptions.configurationURL,
          outputFileURL: outputURL,
          environment: environment,
          options: envSusbstOptions.options
        )
      #endif
    }
  }
#else
  public enum ObfuscateSecretsCommand {}
#endif
