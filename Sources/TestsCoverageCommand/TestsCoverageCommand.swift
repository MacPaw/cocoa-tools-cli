public import ArgumentParser

public struct TestsCoverageCommand: ParsableCommand {
  public static let configuration: CommandConfiguration = CommandConfiguration(
    commandName: "coverage",
    abstract: "Code coverage tools",
    subcommands: [TestsCoverageParseCommand.self],
  )

  public init() {}
}
