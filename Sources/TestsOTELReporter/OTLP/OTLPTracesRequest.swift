/// An OTLP `ExportTraceServiceRequest`, encoded using the Protobuf JSON mapping.
///
/// Resource, scope and attribute types are shared with ``OTLPMetricsRequest``: the schemas are
/// identical across signals, and Tempo must see the same resource as the metrics.
///
/// Per the Protobuf JSON mapping, trace and span IDs are lowercase hex strings and 64-bit
/// integers are encoded as strings.
struct OTLPTracesRequest: Encodable {
  /// Spans grouped by the resource that produced them.
  var resourceSpans: [ResourceSpans]
}

extension OTLPTracesRequest {
  /// Spans produced by a single resource.
  struct ResourceSpans: Encodable {
    /// The resource that produced the spans.
    var resource: OTLPMetricsRequest.Resource
    /// Spans grouped by the instrumentation scope that recorded them.
    var scopeSpans: [ScopeSpans]
  }

  /// Spans recorded by a single instrumentation scope.
  struct ScopeSpans: Encodable {
    /// The instrumentation scope that recorded the spans.
    var scope: OTLPMetricsRequest.Scope
    /// The recorded spans.
    var spans: [Span]
  }

  /// A single span.
  struct Span: Encodable {
    /// The trace the span belongs to, as 32 lowercase hex characters.
    var traceId: String
    /// The span's own ID, as 16 lowercase hex characters.
    var spanId: String
    /// ID of the parent span, omitted for the root span.
    var parentSpanId: String?
    /// Name of the span.
    var name: String
    /// The span kind, as a `SpanKind` raw value.
    var kind: Int
    /// Start of the span, in nanoseconds since the Unix epoch, encoded as a string.
    var startTimeUnixNano: String
    /// End of the span, in nanoseconds since the Unix epoch, encoded as a string.
    var endTimeUnixNano: String
    /// Attributes qualifying this span.
    var attributes: [OTLPMetricsRequest.KeyValue]
    /// Outcome of the span.
    var status: Status
  }

  /// Outcome of a span.
  struct Status: Encodable {
    /// The status code, as a `StatusCode` raw value.
    var code: Int
    /// Human-readable detail, omitted unless the span failed.
    var message: String?
  }
}

extension OTLPTracesRequest {
  /// The span kind; every span the reporter emits is internal to the run.
  static let internalSpanKind: Int = 1

  /// Status codes from the OpenTelemetry trace data model.
  enum StatusCode {
    /// No status was set.
    static let unset: Int = 0
    /// The span failed.
    static let error: Int = 2
  }
}
