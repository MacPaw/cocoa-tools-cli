private typealias Stdout = ExportSecrets.Destinations.Stdout

extension ExportSecrets.Destinations {
  /// Export destination that writes secrets to standard output.
  /// This is useful for debugging, scripting, or piping secrets to other commands.
  public struct Stdout {
    /// Creates a new stdout export destination.
    public init() {}
  }
}

extension Stdout: ExportSecretsDestinationProtocol {
  public func export(secrets: [String: String]) throws {
    let stdout: String = secrets.toEnv().sorted().joined(separator: "\n")
    print(stdout)
  }
}

extension Stdout: Sendable {}
