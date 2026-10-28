/// An OTLP `ExportLogsServiceRequest`, encoded using the Protobuf JSON mapping.
///
/// Resource, scope and attribute types are shared with ``OTLPMetricsRequest``: the schemas are
/// identical across signals, and Loki must see the same resource as the metrics.
struct OTLPLogsRequest: Encodable {
  /// Log records grouped by the resource that produced them.
  var resourceLogs: [ResourceLogs]
}

extension OTLPLogsRequest {
  /// Log records produced by a single resource.
  struct ResourceLogs: Encodable {
    /// The resource that produced the log records.
    var resource: OTLPMetricsRequest.Resource
    /// Log records grouped by the instrumentation scope that recorded them.
    var scopeLogs: [ScopeLogs]
  }

  /// Log records recorded by a single instrumentation scope.
  struct ScopeLogs: Encodable {
    /// The instrumentation scope that recorded the log records.
    var scope: OTLPMetricsRequest.Scope
    /// The recorded log records.
    var logRecords: [LogRecord]
  }

  /// A single log record.
  struct LogRecord: Encodable {
    /// Time the event happened, in nanoseconds since the Unix epoch, encoded as a string.
    var timeUnixNano: String
    /// Numeric severity, as defined by the OpenTelemetry log data model.
    var severityNumber: Int
    /// Severity as a label.
    var severityText: String
    /// The record's message.
    var body: OTLPMetricsRequest.AnyValue
    /// Attributes qualifying this record.
    var attributes: [OTLPMetricsRequest.KeyValue]
  }
}

extension OTLPLogsRequest {
  /// Severity numbers from the OpenTelemetry log data model.
  enum Severity {
    /// An informational event.
    static let info: (number: Int, text: String) = (9, "INFO")
    /// A warning.
    static let warn: (number: Int, text: String) = (13, "WARN")
    /// An error.
    static let error: (number: Int, text: String) = (17, "ERROR")
  }
}
