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
    /// Base URL of a Tempo endpoint to send per-test-case traces to, when it differs from ``endpoint``.
    ///
    /// Like ``endpoint``, this is a base URL: `v1/traces` is appended, so it must already carry any
    /// path prefix the backend serves OTLP under. When `nil`, traces go to ``endpoint`` like the
    /// metrics. Use ``tracesURL`` to obtain the URL actually requested.
    public var tempoEndpoint: URL?
    /// Headers sent with the traces export request, when Tempo authenticates differently.
    ///
    /// When `nil`, ``headers`` are sent. Use ``tracesHeaders`` to obtain the headers actually sent.
    public var tempoHeaders: [String: String]?
    /// Value of the `service.name` resource attribute.
    public var serviceName: String
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
    ///   - tempoEndpoint: Base URL of a separate Tempo endpoint for traces, without the signal path.
    ///   - tempoHeaders: Headers sent with the traces request instead of `headers`.
    ///   - serviceName: Value of the `service.name` resource attribute.
    ///   - timestamp: Timestamp recorded on every data point.
    ///   - isDryRun: Whether to build the payload without sending it.
    public init(
      endpoint: URL,
      headers: [String: String] = [:],
      isPerSuiteEnabled: Bool = true,
      tempoEndpoint: URL? = .none,
      tempoHeaders: [String: String]? = .none,
      serviceName: String = Configuration.defaultServiceName,
      timestamp: Date = Date(),
      isDryRun: Bool = false,
    ) {
      self.endpoint = endpoint
      self.headers = headers
      self.isPerSuiteEnabled = isPerSuiteEnabled
      self.tempoEndpoint = tempoEndpoint
      self.tempoHeaders = tempoHeaders
      self.serviceName = serviceName
      self.timestamp = timestamp
      self.isDryRun = isDryRun
    }

    /// The `service.name` used when none is configured, shared with the Playwright reporter so both
    /// sources land under one service.
    public static let defaultServiceName: String = "macpaw-test"

    /// The URL the metrics payload is sent to.
    ///
    /// Built by appending the `v1/metrics` signal path to ``endpoint``, relative to whatever path
    /// the base URL already carries, as the OTLP specification requires.
    public var metricsURL: URL {
      endpoint.appendingPathComponent("v1").appendingPathComponent("metrics")
    }

    /// The URL the traces payloads are sent to.
    ///
    /// The `v1/traces` signal path appended to ``tempoEndpoint`` when one is set, otherwise to ``endpoint``.
    public var tracesURL: URL {
      (tempoEndpoint ?? endpoint).appendingPathComponent("v1").appendingPathComponent("traces")
    }

    /// The headers sent with the traces requests: ``tempoHeaders`` when set, otherwise ``headers``.
    public var tracesHeaders: [String: String] { tempoHeaders ?? headers }
  }
}

extension TestsOTELReporter.Configuration: Sendable {}
extension TestsOTELReporter.Configuration: Equatable {}
