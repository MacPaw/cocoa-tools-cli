public import CI
public import Foundation
import SharedLogger

#if canImport(FoundationNetworking)
  public import FoundationNetworking
#endif

/// Exports metrics about a completed test run to an OpenTelemetry collector.
///
/// The reporter derives three test metrics — test case counts by result status, a histogram of
/// test case durations, and the total run duration — plus per-target line coverage, and pushes
/// them to an OTLP/HTTP endpoint as JSON.
public struct TestsOTELReporter {
  /// Configuration for this push.
  public let configuration: Configuration

  /// The CI the run executed on, used to derive resource attributes.
  private let ci: any CIInterface
  /// URL session used for the export request.
  private let urlSession: URLSession

  /// Initializes a reporter.
  ///
  /// - Parameters:
  ///   - configuration: Configuration for this push.
  ///   - ci: The CI the run executed on. Defaults to the detected current CI.
  ///   - urlSession: URL session used for the export request.
  public init(
    configuration: Configuration,
    ci: any CIInterface = CI.current,
    urlSession: URLSession = URLSession.shared,
  ) {
    self.configuration = configuration
    self.ci = ci
    self.urlSession = urlSession
  }

  /// Builds the OTLP payload for a test run without sending it.
  ///
  /// - Parameter testRun: The completed test run.
  /// - Returns: The JSON-encoded OTLP `ExportMetricsServiceRequest`.
  /// - Throws: An encoding error if the payload cannot be serialized.
  public func payload(for testRun: TestRun) throws -> Data {
    try payload(testRun: testRun, lineCoverage: .none)
  }

  /// Builds the OTLP payload for a test run and its line coverage without sending it.
  ///
  /// - Parameters:
  ///   - testRun: The completed test run, if there is one to report.
  ///   - lineCoverage: Line coverage of the run, if there is any to report.
  /// - Returns: The JSON-encoded OTLP `ExportMetricsServiceRequest`.
  /// - Throws: An encoding error if the payload cannot be serialized.
  public func payload(testRun: TestRun?, lineCoverage: LineCoverage?) throws -> Data {
    let request = OTLPMetricsBuilder(
      isPerSuiteEnabled: configuration.isPerSuiteEnabled,
      timestamp: configuration.timestamp,
    )
    .build(
      testRun: testRun,
      lineCoverage: lineCoverage,
      repository: ci.repository,
      cicd: ci.cicd,
      ciProviderName: ci.type.name,
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    return try encoder.encode(request)
  }

  /// Exports the metrics for a test run.
  ///
  /// When the configuration requests a dry run, the payload is built and returned without any
  /// network request being made.
  ///
  /// - Parameter testRun: The completed test run.
  /// - Returns: The JSON-encoded payload that was sent, or would have been sent.
  /// - Throws: ``Error`` if the collector rejects the export, or a `URLSession` error.
  @discardableResult
  public func report(_ testRun: TestRun) async throws -> Data {
    try await report(testRun: testRun, lineCoverage: .none)
  }

  /// Exports the metrics for a test run and its line coverage.
  ///
  /// When the configuration requests a dry run, the payload is built and returned without any
  /// network request being made.
  ///
  /// - Parameters:
  ///   - testRun: The completed test run, if there is one to report.
  ///   - lineCoverage: Line coverage of the run, if there is any to report.
  /// - Returns: The JSON-encoded payload that was sent, or would have been sent.
  /// - Throws: ``Error`` if the collector rejects the export, or a `URLSession` error.
  @discardableResult
  public func report(testRun: TestRun?, lineCoverage: LineCoverage?) async throws -> Data {
    logCIContext()
    let payload = try payload(testRun: testRun, lineCoverage: lineCoverage)

    guard !configuration.isDryRun else {
      log.debug("Dry run: skipping OTLP export of \(payload.count) bytes")
      return payload
    }

    var request = URLRequest(url: configuration.metricsURL)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    for (name, value) in configuration.headers { request.setValue(value, forHTTPHeaderField: name) }
    request.httpBody = payload

    log.debug("Exporting test metrics to \(configuration.metricsURL)")

    let (data, response) = try await urlSession.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else { throw Error.responseNotHTTP(response) }
    guard (200..<300).contains(httpResponse.statusCode) else {
      throw Error.wrongStatusCode(httpResponse.statusCode, body: String(data: data, encoding: .utf8))
    }

    return payload
  }
}

extension TestsOTELReporter {
  /// Logs the CI metadata that is attached to the export as resource attributes.
  ///
  /// Attributes the CI cannot report are omitted from the payload, so they are logged as a
  /// warning: the matching dashboard variables stay empty.
  private func logCIContext() {
    let repository = ci.repository
    let run = ci.cicd.run
    let values: [(name: String, value: String?)] = [
      (SemanticConventions.Resource.cicdProviderName, ci.type.name),
      (SemanticConventions.Resource.vcsProviderName, repository.provider),
      (SemanticConventions.Resource.vcsOwnerName, repository.organizationName),
      (SemanticConventions.Resource.vcsRepositoryName, repository.repositoryName),
      (SemanticConventions.Resource.cicdPipelineName, ci.cicd.pipelineName),
      (SemanticConventions.Resource.cicdPipelineStageName, run.stageName),
      (SemanticConventions.Resource.cicdPipelineTaskName, run.taskName),
      (SemanticConventions.Resource.cicdPipelineRunID, run.id),
      (SemanticConventions.Resource.cicdPipelineRunNumber, run.number),
      (SemanticConventions.Resource.cicdPipelineRunURL, run.url?.absoluteString),
    ]

    log.info("CI context attached to the export:")
    for (name, value) in values {
      if let value {
        log.info("  \(name) = \(value)")
      }
      else {
        log.warning("  \(name) is not reported by \(ci.type.name); omitted from the export")
      }
    }
  }
}

extension TestsOTELReporter: Sendable {}
