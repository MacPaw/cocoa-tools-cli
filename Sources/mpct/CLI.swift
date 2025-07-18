import ArgumentParser
import EnvSubstCommand
import Foundation
import ImportSecretsCommand
import SemanticVersion

#if canImport(ObfuscateSecretsCommand)
  import ObfuscateSecretsCommand
#endif

struct MPCT: AsyncParsableCommand {
  static let configuration: CommandConfiguration = CommandConfiguration(
    abstract: "A wrapper command-line tool for various scripts and tools we use every day",
    version: TargetVersions.mpct.description,
    subcommands: [EnvSubstCommand.self, SecretsCommand.self]
  )

  @OptionGroup(visibility: .default)
  var commonOptions: CommonOptions

  func run() async throws {}
}

struct CommonOptions: ParsableArguments, Decodable {
  @Flag(name: .shortAndLong, help: "Verbose output")
  var verbose: Bool = false
}

struct SecretsCommand: ParsableCommand {
  #if canImport(ObfuscateSecretsCommand)
    private static let obfuscateSecretsCommand: [ParsableCommand.Type] = [ObfuscateSecretsCommand.self]
  #else
    private static let obfuscateSecretsCommand: [ParsableCommand.Type] = []
  #endif
  static let configuration: CommandConfiguration = CommandConfiguration(
    commandName: "secrets",
    abstract: "Secrets manipulation",
    subcommands: obfuscateSecretsCommand + [ImportSecretsCommand.self]
  )
}
