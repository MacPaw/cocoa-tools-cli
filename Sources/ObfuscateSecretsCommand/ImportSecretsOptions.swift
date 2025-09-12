import ArgumentParser
import ExportSecretsCommand
import Foundation

extension ObfuscateSecretsCommand {
  /// The path to a Confidential configuration file.
  public struct ImportSecretsOptions: ParsableArguments, Decodable {
    @Option(
      name: [.customLong("import-secrets-config")],
      help: "The path to a secrets export configuration file",
      transform: URL.init(fileURLWithPath:),
    )
    var configurationURL: URL?

    @Option(
      name: .customLong("secrets-source"),
      help: .init("Source to import secrets from.", argumentType: ExportSecretsCommand.Options.Source.self),
    )
    var sources: [ExportSecretsCommand.Options.Source] = []

    @Flag(name: [.customLong("overwrite-existing")], help: "Overwriting existing ENV values with fetched secrets")
    var overwriteExistingEnv: Bool = false

    /// Creates a new ImportSecretsOptions instance with default values.
    public init() {}
  }
}
