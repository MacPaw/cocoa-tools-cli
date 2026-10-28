public import Foundation

extension TestsOTELReporter {
  /// Configuration for a single push of test metrics.
  public struct Configuration {
    /// Base URL of the OTLP endpoint.
    ///
    /// This is a base URL, not the full request URL: the OTLP specification requires clients to
    /// append the signal path, so `v1/metrics` is appended when the request is built. Use
    /// ``metricsURL`` to obtain the URL that is actually requested.
    public var endpoint: URL
    /// Headers sent with the export request, typically carrying authentication.
    public var headers: [String: String]
    /// Whether metrics carry a `test.suite.name` breakdown.
    public var isPerSuiteEnabled: Bool
    /// Whether metrics carry a `test.case.name` breakdown.
    ///
    /// Every test case becomes its own series, so disable it where that volume is not acceptable.
    public var isPerTestEnabled: Bool
    /// Timestamp recorded on every data point.
    public var timestamp: Date
    /// Whether to build the payload without sending it.
    public var isDryRun: Bool

    /// Initializes a configuration.
    ///
    /// - Parameters:
    ///   - endpoint: Base URL of the OTLP endpoint, without the signal path.
    ///   - headers: Headers sent with the export request.
    ///   - isPerSuiteEnabled: Whether metrics carry a `test.suite.name` breakdown.
    ///   - isPerTestEnabled: Whether metrics carry a `test.case.name` breakdown.
    ///   - timestamp: Timestamp recorded on every data point.
    ///   - isDryRun: Whether to build the payload without sending it.
    public init(
      endpoint: URL,
      headers: [String: String] = [:],
      isPerSuiteEnabled: Bool = true,
      isPerTestEnabled: Bool = true,
      timestamp: Date = Date(),
      isDryRun: Bool = false,
    ) {
      self.endpoint = endpoint
      self.headers = headers
      self.isPerSuiteEnabled = isPerSuiteEnabled
      self.isPerTestEnabled = isPerTestEnabled
      self.timestamp = timestamp
      self.isDryRun = isDryRun
    }

    /// The URL the metrics payload is sent to.
    ///
    /// Built by appending the `v1/metrics` signal path to ``endpoint``, relative to whatever path
    /// the base URL already carries, as the OTLP specification requires.
    public var metricsURL: URL {
      endpoint.appendingPathComponent("v1").appendingPathComponent("metrics")
    }
  }
}

extension TestsOTELReporter.Configuration: Sendable {}
extension TestsOTELReporter.Configuration: Equatable {}
