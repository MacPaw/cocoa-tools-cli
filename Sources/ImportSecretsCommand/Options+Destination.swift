import ArgumentParser

extension ImportSecretsCommand.Options {
  /// Represents a configured export destination for secrets.
  ///
  /// Combines a destination type with an optional file path to define
  /// where and how secrets should be exported after being fetched.
  public struct Destination {
    /// Available destination types for exporting secrets.
    public enum DestinationType: String {
      /// Export secrets to standard output in KEY=VALUE format.
      case stdout = "stdout"
      /// Export secrets to a mise configuration file.
      case mise = "mise"
      /// Export secrets to a .env file format.
      case dotenv = "dotenv"
    }

    /// The type of destination to export to.
    public let type: DestinationType
    /// Optional file path for file-based destinations.
    public let file: String?

    /// Creates a new destination configuration.
    ///
    /// - Parameters:
    ///   - type: The destination type.
    ///   - file: Optional file path for file-based destinations.
    public init(type: DestinationType, file: String?) {
      self.type = type
      self.file = file
    }
  }
}

extension ImportSecretsCommand.Options.Destination {
  /// Predefined destination for exporting to standard output.
  public static let stdout: Self = .init(type: .stdout, file: .none)
  /// Predefined destination for exporting to a local mise configuration file.
  public static let miseLocal: Self = .init(type: .mise, file: "mise.local.toml")
  /// Predefined destination for exporting to a local .env file.
  public static let dotenvLocal: Self = .init(type: .dotenv, file: ".env.local")
}

extension ImportSecretsCommand.Options.Destination.DestinationType: Decodable {}
extension ImportSecretsCommand.Options.Destination.DestinationType: Sendable {}
extension ImportSecretsCommand.Options.Destination.DestinationType: CaseIterable {}
extension ImportSecretsCommand.Options.Destination.DestinationType: Equatable {}

extension ImportSecretsCommand.Options.Destination.DestinationType: ExpressibleByArgument {
  /// Provides a human-readable description of each destination type.
  ///
  /// - Returns: A description string explaining what the destination type does.
  public var defaultValueDescription: String {
    switch self {
    case .stdout: "Export to standard output"
    case .mise: "Export to a mise config file. Default --file option value is mise.local.toml."
    case .dotenv: "Export to a .env file. Default --file option value is .env.local."
    }
  }
}

extension ImportSecretsCommand.Options.Destination: Sendable {}
extension ImportSecretsCommand.Options.Destination: Equatable {}
