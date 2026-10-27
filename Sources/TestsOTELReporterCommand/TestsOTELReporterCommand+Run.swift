import ArgumentParser
import Foundation
import LLVMCoverageParser
import SharedLogger
import TestsOTELReporter
import XUnitReport

#if os(macOS)
  import XCResultParsing
#endif

extension TestsOTELReporterCommand {
  /// Validates the options before the command runs.
  ///
  /// - Throws: `ValidationError` when the inputs or the endpoint are not usable.
  public func validate() throws {
    _ = try options.resolvedInputs()
    _ = try options.resolvedEndpoint(environment: Self.environment)
    _ = try options.resolvedHeaders(environment: Self.environment)
  }

  /// Parses the report and exports its metrics.
  ///
  /// The exit status reflects only the export: a run containing failing tests still exits zero,
  /// since the command reports results rather than gating on them.
  ///
  /// - Throws: An export error, unless `--no-fail-on-error` was passed.
  public func run() async throws {
    let environment: [String: String] = Self.environment
    let inputs: Options.Inputs = try options.resolvedInputs()
    let testRun: TestRun? = try inputs.report.map(Self.testRun(for:))
    let lineCoverage: LineCoverage? = try self.lineCoverage(for: inputs)

    let reporter = TestsOTELReporter(
      configuration: TestsOTELReporter.Configuration(
        endpoint: try options.resolvedEndpoint(environment: environment),
        headers: try options.resolvedHeaders(environment: environment),
        isPerSuiteEnabled: options.perSuite,
        timestamp: options.resolvedTimestamp(environment: environment),
        isDryRun: options.dryRun,
      )
    )

    do {
      let payload: Data = try await reporter.report(testRun: testRun, lineCoverage: lineCoverage)

      if options.dryRun {
        print(String(decoding: payload, as: UTF8.self))
      }
      else {
        log.info(
          """
          Exported metrics for \(testRun?.testCases.count ?? 0) test cases \
          in \(testRun?.suites.count ?? 0) suites \
          and \(lineCoverage?.targets.count ?? 0) line coverage targets
          """
        )
      }
    }
    catch {
      guard options.failOnError else {
        log.warning("Failed to export test metrics: \(error)")
        return
      }
      throw error
    }
  }

  /// Reads line coverage from whichever input carries it.
  ///
  /// A bundle without coverage data — coverage was not enabled for the test run — is not an
  /// error: the test metrics are still worth sending. An explicit `--llvm-line-coverage` file that
  /// cannot be read is one, since it was asked for by name.
  ///
  /// - Parameter inputs: The resolved inputs.
  /// - Returns: The per-target line coverage, or `nil` when there is none to report.
  /// - Throws: An error if an explicitly requested LLVM coverage file cannot be parsed.
  private func lineCoverage(for inputs: Options.Inputs) throws -> LineCoverage? {
    guard options.lineCoverage else { return .none }

    if let url = inputs.llvmLineCoverage {
      return LineCoverage(
        llvmCoverage: try LLVMCoverage.load(from: url),
        includeTestTargets: options.includeTestTargets,
      )
    }

    #if os(macOS)
      if case .xcresult(let url) = inputs.report {
        do {
          return LineCoverage(
            xcresultCoverage: try XCResultCoverage.load(from: url),
            includeTestTargets: options.includeTestTargets,
          )
        }
        catch {
          log.warning("Skipping line coverage, the xcresult bundle has none: \(error)")
        }
      }
    #endif

    return .none
  }

  /// Reads the selected report into the reporter's neutral model.
  ///
  /// - Parameter input: The report to read.
  /// - Returns: The normalized test run.
  /// - Throws: An error if the report cannot be read or parsed.
  private static func testRun(for input: Options.Input) throws -> TestRun {
    switch input {
    case .xunit(let url):
      return TestRun(report: try XUnitReport.load(from: url))

    case .xcresult(let url):
      #if os(macOS)
        return TestRun(testResults: try XCResultTestResults.load(from: url))
      #else
        throw ValidationError("--xcresult is only supported on macOS")
      #endif
    }
  }

  /// The process environment the command falls back to for OpenTelemetry configuration.
  private static var environment: [String: String] { ProcessInfo.processInfo.environment }
}
