public import ArgumentParser
import Foundation

/// Options shared by the `tests report otel` command.
struct Options: ParsableArguments {
  #if os(macOS)
    @Option(name: .long, help: "Path to the .xcresult bundle to report on")
    var xcresult: String?
  #endif

  @Option(name: .long, help: "Path to the xUnit XML report to report on")
  var xunit: String?

  @Option(
    name: .long,
    help: """
      Path to an `llvm-cov export` JSON file to report line coverage from. \
      Combine with --xunit; --xcresult already carries line coverage.
      """,
  )
  var llvmLineCoverage: String?

  @Flag(
    inversion: .prefixedNo,
    help: "Report per-target line coverage, when the input carries it",
  )
  var lineCoverage: Bool = true

  @Flag(
    name: .long,
    help: "Include test bundle targets (`*.xctest`) in the line coverage report",
  )
  var includeTestTargets: Bool = false

  @Option(
    name: .long,
    help: """
      Base URL of the OTLP endpoint, without the signal path — `v1/metrics` is appended. \
      Defaults to $OTEL_EXPORTER_OTLP_ENDPOINT.
      """,
  )
  var endpoint: String?

  @Option(
    name: .long,
    parsing: .upToNextOption,
    help: """
      Header to send with the export, as `key=value`. Repeatable. \
      Merged over headers parsed from $OTEL_EXPORTER_OTLP_HEADERS.
      """,
  )
  var header: [String] = []

  @Flag(
    inversion: .prefixedNo,
    help: "Break metrics down by test suite with the `test.suite.name` attribute",
  )
  var perSuite: Bool = true

  @Flag(
    inversion: .prefixedNo,
    help: """
      Break metrics down by test case with the `test.case.name` attribute. \
      Every test case becomes its own series, so pass `--no-per-test` where that volume is not acceptable.
      """,
  )
  var perTest: Bool = true

  @Option(name: .long, help: "Sample timestamp in milliseconds since the Unix epoch")
  var timestamp: Int?

  @Flag(inversion: .prefixedNo, help: "Exit with a non-zero status when the export fails")
  var failOnError: Bool = true

  @Flag(name: .long, help: "Build the payload and print it without sending it")
  var dryRun: Bool = false
}
