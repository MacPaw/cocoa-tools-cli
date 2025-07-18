import ArgumentParser
import EnvSubstCommand
import Foundation
import ImportSecretsCommand
import SemanticVersion
import SemanticVersionMacro

#if canImport(ObfuscateSecretsCommand)
  import ObfuscateSecretsCommand
#endif

struct MPCT: AsyncParsableCommand {
  static let version: SemanticVersion = #semanticVersion("1.0.0-beta.1+build.24")
  static let configuration: CommandConfiguration = CommandConfiguration(
    abstract: "A wrapper command-line tool for various scripts and tools we use every day",
    version: TargetVersions.mpct.description,
    subcommands: [EnvSubstCommand.self, SecretsCommand.self],
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
    private static let obfuscate: [any ParsableCommand.Type] = [ObfuscateSecretsCommand.self]
  #else
    private static let obfuscate: [any ParsableCommand.Type] = []
  #endif
  static let configuration: CommandConfiguration = CommandConfiguration(
    commandName: "secrets",
    abstract: "Secrets manipulation",
    subcommands: obfuscate + [ImportSecretsCommand.self],
  )
}
