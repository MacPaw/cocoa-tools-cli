import ArgumentParser
import EnvSubstCommand
@_exported public import ExportSecrets
import Foundation
@_exported public import ImportSecrets
import Shell

/// Command-line interface for exporting secrets from various providers to specified destination.
///
/// This command provides a CLI wrapper around the ImportSecrets module, allowing users to
/// fetch secrets from different sources (like 1Password) and export them to various destinations
/// such as environment files, mise configurations, or standard output.
public struct ExportSecretsCommand {
  /// Configuration for the ArgumentParser command.
  public static let configuration = CommandConfiguration(
    commandName: "import",
    abstract: "Import secrets",
    discussion: """
      Imports secrets from various sources, such as 1Password.
      """,
  )

  /// Command-line options for configuring secret import and export behavior.
  @OptionGroup
  var options: Options

  /// The loaded and validated ImportSecrets configuration.
  ///
  /// Set during the validate() phase and used during run().
  var configuration: ImportSecrets.Configuration? = .none

  /// Creates a new ExportSecretsCommand instance.
  public init() {}
}

extension ExportSecretsCommand {
  /// Creates an export destination based on the provided options.
  ///
  /// - Parameter options: Command options containing destination configuration.
  /// - Returns: An export destination that can write secrets to the specified target.
  /// - Throws: Configuration errors if the destination cannot be created.
  private func exportDestination(options: Options) throws -> any ExportSecretsDestinationProtocol {
    switch options.destinationArguments.destination.type {
    case .stdout: ExportSecrets.Destinations.Stdout()
    case .mise: try ExportSecrets.Destinations.Mise(file: options.destinationArguments.destination.file)
    case .dotenv: ExportSecrets.Destinations.DotEnv(file: options.destinationArguments.destination.file)
    case .ci: ExportSecrets.Destinations.CI()
    }
  }
}

extension ExportSecretsCommand {
  /// Creates source providers based on the specified source options.
  ///
  /// - Parameter options: Command options containing source provider configuration.
  /// - Returns: Array of configured secret providers that can fetch secrets.
  /// - Throws: Configuration errors if providers cannot be created.
  private func sourceProviders(options: ExportSecretsCommand.Options) throws -> [any SecretProviderProtocol] {
    try ExportSecretsCommand.Options.sourceProviders(sources: options.sources)
  }
}

extension ExportSecretsCommand.Options {
  /// Creates source providers from the specified source types.
  ///
  /// - Parameter sources: Array of source types to create providers for.
  /// - Returns: Array of configured secret providers.
  /// - Throws: Configuration errors if providers cannot be created.
  public static func sourceProviders(sources: [ExportSecretsCommand.Options.Source]) throws
    -> [any SecretProviderProtocol]
  {
    sources.map {
      switch $0 {
      case .op: return ImportSecrets.Providers.OnePassword(fetcher: .init())
      case .vault: return ImportSecrets.Providers.HashiCorpVault(fetcher: .init())
      }
    }
  }
}

extension ExportSecretsCommand: AsyncParsableCommand {
  /// Validates the command configuration and loads the secrets configuration file.
  ///
  /// This method is called by ArgumentParser before run() to ensure all options are valid
  /// and the configuration file can be loaded and parsed successfully.
  ///
  /// - Throws: Validation errors if configuration is invalid or cannot be loaded.
  public mutating func validate() throws {
    let sourceProviders = try sourceProviders(options: options)

    var configuration = try ImportSecrets.configuration(
      configurationURL: options.configurationURL,
      sourceProviders: sourceProviders,
      envSubstOptions: options.envSubstOptions.options,
    )

    try configuration.validate()

    self.configuration = configuration
  }

  /// Executes the secret import and export process.
  ///
  /// Fetches secrets from the configured providers according to the loaded configuration,
  /// then exports them to the specified destination. This method requires that validate()
  /// has been called successfully first.
  ///
  /// - Throws: Import or export errors if the process fails.
  public mutating func run() async throws {
    guard let configuration else { throw ValidationError.configurationNotValidated }

    // Set up providers
    let secrets: [String: String] = try await ImportSecrets.getSecrets(configuration: configuration)

    let destination: any ExportSecretsDestinationProtocol = try exportDestination(options: options)

    if let destination = destination as? any ExportSecretsAsyncDestinationProtocol {
      try await ExportSecrets.export(secrets: secrets, destination: destination)
    }
    else {
      try ExportSecrets.export(secrets: secrets, destination: destination)
    }
  }
}

extension ExportSecretsCommand {
  /// Validation errors specific to the ExportSecretsCommand.
  enum ValidationError: Error {
    /// Thrown when run() is called before validate() has been successfully executed.
    case configurationNotValidated
    /// Thrown when attempting to use an async-only destination in synchronous mode.
    case asyncDestinationNotSupportedInSyncMode
  }
}
