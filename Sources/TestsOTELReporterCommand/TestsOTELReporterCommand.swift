public import ArgumentParser

/// Top-level `tests report otel` command.
public struct TestsOTELReporterCommand: AsyncParsableCommand {
  /// ArgumentParser command configuration.
  public static let configuration: CommandConfiguration = CommandConfiguration(
    commandName: "otel",
    abstract: "Push test result metrics to an OpenTelemetry collector",
  )

  @OptionGroup
  var options: Options

  /// Creates a default instance.
  public init() {}
}
