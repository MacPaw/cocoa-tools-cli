import ArgumentParser
import Foundation
import ImportSecretsCommand

extension ObfuscateSecretsCommand {
  /// The path to a Confidential configuration file.
  public struct ImportSecretsOptions: ParsableArguments, Decodable {
    @Option(
      name: [.customLong("import-secrets-config")],
      help: "The path to a secrets import configuration file",
      transform: URL.init(fileURLWithPath:),
    )
    var configurationURL: URL?

    @Option(
      name: .customLong("secrets-source"),
      help: .init("Source to import secrets from.", argumentType: ImportSecretsCommand.Options.Source.self),
    )
    var sources: [ImportSecretsCommand.Options.Source] = []

    @Flag(name: [.customLong("overwrite-existing")], help: "Overwriting existing ENV values with fetched secrets")
    var overwriteExistingEnv: Bool = false

    /// Creates a new ImportSecretsOptions instance with default values.
    public init() {}
  }
}
