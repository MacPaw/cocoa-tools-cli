public import ArgumentParser

/// Top-level `tests results` command group.
public struct TestsResultsCommand: ParsableCommand {
  /// ArgumentParser command configuration.
  public static let configuration: CommandConfiguration = CommandConfiguration(
    commandName: "results",
    abstract: "Test results tools",
    subcommands: [TestsResultsParseCommand.self],
  )

  /// Creates a default instance.
  public init() {}
}
