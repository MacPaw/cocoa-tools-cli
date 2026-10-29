public import ArgumentParser

/// Top-level `tests coverage` command group.
public struct TestsCoverageCommand: ParsableCommand {
  /// ArgumentParser command configuration.
  public static let configuration: CommandConfiguration = CommandConfiguration(
    commandName: "coverage",
    abstract: "Code coverage tools",
    subcommands: [TestsCoverageParseCommand.self],
  )

  /// Creates a default instance.
  public init() {}
}
