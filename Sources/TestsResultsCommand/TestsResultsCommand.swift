public import ArgumentParser

public struct TestsResultsCommand: ParsableCommand {
  public static let configuration: CommandConfiguration = CommandConfiguration(
    commandName: "results",
    abstract: "Test results tools",
    subcommands: [TestsResultsParseCommand.self],
  )

  public init() {}
}
