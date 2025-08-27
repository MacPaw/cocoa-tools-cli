import ArgumentParser
@_exported public import EnvSubst
@_exported public import EnvSubstCommand
import Foundation
@_exported public import ImportSecrets
@_exported public import ImportSecretsCommand

#if canImport(ObfuscateSecrets)
  import ObfuscateSecrets

  /// Command-line interface for obfuscating secret literals using swift-confidential.
  ///
  /// This command integrates secret fetching with code obfuscation to generate Swift code
  /// that provides secure access to secrets at runtime.
  public struct ObfuscateSecretsCommand: AsyncParsableCommand {
    /// Configuration for the ArgumentParser command.
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

    /// Creates a new ObfuscateSecretsCommand instance.
    public init() {}

    /// Validates all command options before execution.
    ///
    /// - Throws: Validation errors if any options are invalid.
    public mutating func validate() throws {
      try confidentialOptions.validate()
      try importSecretsOptions.validate()
      try envSusbstOptions.validate()
    }

    /// Executes the obfuscation process.
    ///
    /// Fetches secrets from configured sources and generates obfuscated Swift code
    /// using swift-confidential for secure runtime access.
    ///
    /// - Throws: Execution errors if the obfuscation process fails.
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
  /// Placeholder for ObfuscateSecretsCommand when ObfuscateSecrets is not available.
  public enum ObfuscateSecretsCommand {}
#endif
