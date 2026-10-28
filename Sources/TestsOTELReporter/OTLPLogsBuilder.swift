import CI
import Foundation

/// Builds the OTLP logs payloads for a completed test run: one log record per test case.
///
/// Test case names live in logs rather than metric labels, since a series per test case grows
/// without bound while a log line costs nothing to index.
struct OTLPLogsBuilder {
  /// Most log records sent in one request.
  ///
  /// A large run would otherwise produce a body that a reverse proxy in front of the collector
  /// rejects — nginx defaults to 1 MB.
  static let maxRecordsPerRequest: Int = 500

  /// Value of the `service.name` resource attribute.
  let serviceName: String
  /// Timestamp recorded on every log record.
  let timestamp: Date

  /// Builds the export requests for a test run.
  ///
  /// - Parameters:
  ///   - testRun: The completed test run.
  ///   - repository: Repository metadata for the run.
  ///   - cicd: Pipeline metadata for the run.
  ///   - ciProviderName: Name of the CI the run executed on.
  /// - Returns: The OTLP export requests, each within ``maxRecordsPerRequest``, or none when the
  ///   run has no test cases.
  func build(
    testRun: TestRun,
    repository: CI.Repository,
    cicd: CI.CICD,
    ciProviderName: String?,
  ) -> [OTLPLogsRequest] {
    let resource = OTLPMetricsRequest.Resource(
      attributes: OTLPResourceAttributes.make(
        serviceName: serviceName,
        repository: repository,
        cicd: cicd,
        ciProviderName: ciProviderName,
      )
    )
    let records: [OTLPLogsRequest.LogRecord] = testRun.suites.flatMap { suite in
      suite.testCases.map { logRecord(for: $0, suiteName: suite.name) }
    }

    return stride(from: 0, to: records.count, by: Self.maxRecordsPerRequest)
      .map { start in
        OTLPLogsRequest(
          resourceLogs: [
            OTLPLogsRequest.ResourceLogs(
              resource: resource,
              scopeLogs: [
                OTLPLogsRequest.ScopeLogs(
                  scope: OTLPMetricsRequest.Scope(name: SemanticConventions.scopeName),
                  logRecords: Array(records[start..<min(start + Self.maxRecordsPerRequest, records.count)]),
                )
              ],
            )
          ]
        )
      }
  }

  /// Builds the log record of a single test case.
  ///
  /// - Parameters:
  ///   - testCase: The test case.
  ///   - suiteName: Name of the suite it belongs to.
  /// - Returns: The log record.
  private func logRecord(for testCase: TestRun.Suite.TestCase, suiteName: String) -> OTLPLogsRequest.LogRecord {
    let severity =
      switch testCase.status {
      case .pass: OTLPLogsRequest.Severity.info
      case .fail: OTLPLogsRequest.Severity.error
      case .skip: OTLPLogsRequest.Severity.warn
      }

    return OTLPLogsRequest.LogRecord(
      timeUnixNano: OTLPMetricsBuilder.unixNano(timestamp),
      severityNumber: severity.number,
      severityText: severity.text,
      body: OTLPMetricsRequest.AnyValue(stringValue: Self.body(for: testCase), doubleValue: .none),
      attributes: [
        OTLPMetricsRequest.KeyValue(key: SemanticConventions.Attribute.testCaseName, stringValue: testCase.name),
        OTLPMetricsRequest.KeyValue(key: SemanticConventions.Attribute.testSuiteName, stringValue: suiteName),
        OTLPMetricsRequest.KeyValue(
          key: SemanticConventions.Attribute.testCaseResultStatus,
          stringValue: testCase.status.rawValue,
        ),
        OTLPMetricsRequest.KeyValue(
          key: SemanticConventions.Attribute.testCaseDuration,
          doubleValue: testCase.duration * 1000,
        ),
      ],
    )
  }

  /// Builds the message of a test case's log record.
  ///
  /// - Parameter testCase: The test case.
  /// - Returns: The test case name, followed by the failure message of a failed test case.
  private static func body(for testCase: TestRun.Suite.TestCase) -> String {
    guard testCase.status == .fail, let message = testCase.failureMessage, !message.isEmpty else {
      return testCase.name
    }
    return "\(testCase.name): \(message)"
  }
}
