import ArgumentParser
import EnvSubstCommand
import Foundation
import ImportSecrets

extension ImportSecretsCommand {
  /// Command-line options for the ImportSecretsCommand.
  ///
  /// Configures the source providers, configuration file location, export destination,
  /// and environment variable substitution behavior for the secret import process.
  public struct Options: ParsableArguments, Decodable {
    /// Path to the YAML configuration file that defines secrets to import.
    ///
    /// The configuration file specifies which secrets to fetch from which providers
    /// and how they should be mapped to environment variable names.
    @Option(
      name: [.customLong("config"), .customShort("c")],
      help: #"""
        A path to the configuration YAML file.
        """#,
      transform: URL.init(fileURLWithPath:)
    )
    var configurationURL: URL

    /// Arguments for configuring the export destination.
    @OptionGroup()
    var destinationArguments: DestinationArguments

    /// Options for environment variable substitution in the configuration file.
    @OptionGroup(title: "EnvSubst options")
    var envSubstOptions: EnvSubstCommand.Options

    /// List of source providers to use for fetching secrets.
    /// Multiple sources can be specified to support different secret providers.
    @Option(name: .customLong("source"), help: .init("Source to import secrets from.", argumentType: Source.self))
    var sources: [Source]

    /// Creates a new Options instance with default values.
    public init() {}
  }
}

extension ImportSecretsCommand.Options {
  /// Available secret source providers.
  public enum Source: String {
    /// 1Password CLI integration for fetching secrets from 1Password vaults.
    case op
  }
}

extension ImportSecretsCommand.Options.Source: Decodable {}
extension ImportSecretsCommand.Options.Source: CaseIterable {}
extension ImportSecretsCommand.Options.Source: Equatable {}
extension ImportSecretsCommand.Options.Source: ExpressibleByArgument {
  /// Provides a human-readable description of each source provider.
  ///
  /// - Returns: A description string explaining what the source provider does.
  public var defaultValueDescription: String {
    switch self {
    case .op: "Import secrets from 1Password."
    }
  }
}

extension ImportSecretsCommand.Options {
  /// Command-line arguments for configuring the export destination.
  ///
  /// Determines where fetched secrets will be exported, such as to files,
  /// standard output, or in-memory for testing purposes.
  public struct DestinationArguments: ParsableArguments, Sendable {
    /// The type of destination to export secrets to.
    @Option(name: .customLong("destination"), help: "Destination to export the secrets to. Default value: in-memory.")
    var destinationType: ImportSecretsCommand.Options.Destination.DestinationType

    /// Optional file path for file-based destinations (mise, dotenv).
    /// If not specified, default file names will be used based on the destination type.
    @Option(name: .customLong("file"), help: "Destination file. Applicable for mise and dotenv destinations.")
    var destinationFile: String?

    /// Creates a new DestinationArguments instance with default values.
    public init() {}
  }
}

extension ImportSecretsCommand.Options.DestinationArguments {
  /// Converts the destination arguments to a Destination configuration object.
  ///
  /// - Returns: A Destination instance combining the destination type and file path.
  var destination: ImportSecretsCommand.Options.Destination { .init(type: destinationType, file: destinationFile) }
}
