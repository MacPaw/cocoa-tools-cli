import ArgumentParser
import EnvSubstCommand
import ExportSecretsCommand
import Foundation
import SemanticVersion

#if canImport(ObfuscateSecretsCommand)
  import ObfuscateSecretsCommand
#endif

struct MPCT: AsyncParsableCommand {
  static let configuration: CommandConfiguration = CommandConfiguration(
    abstract: "A wrapper command-line tool for various scripts and tools we use every day",
    version: TargetVersions.current.description,
    subcommands: [EnvSubstCommand.self, SecretsCommand.self],
  )

  @OptionGroup(visibility: .default)
  var commonOptions: CommonOptions
}

struct CommonOptions: ParsableArguments, Decodable {
  @Flag(name: .shortAndLong, help: "Verbose output")
  var verbose: Bool = false
}

struct SecretsCommand: ParsableCommand {
  #if canImport(ObfuscateSecretsCommand)
    private static let obfuscate: [any ParsableCommand.Type] = [ObfuscateSecretsCommand.self]
  #else
    private static let obfuscate: [any ParsableCommand.Type] = []
  #endif
  static let configuration: CommandConfiguration = CommandConfiguration(
    commandName: "secrets",
    abstract: "Secrets manipulation",
    subcommands: obfuscate + [ExportSecretsCommand.self],
  )
}
