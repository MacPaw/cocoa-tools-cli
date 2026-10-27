/// An OTLP `ExportMetricsServiceRequest`, encoded using the Protobuf JSON mapping.
///
/// These types mirror the OTLP metrics schema directly rather than depending on the
/// OpenTelemetry SDK: the SDK's OTLP serialization lives in a package that also pulls in gRPC,
/// and its metric types are not `Codable`, so conforming them here would cost more code than
/// the schema itself.
///
/// Per the Protobuf JSON mapping, 64-bit integers are encoded as strings.
struct OTLPMetricsRequest: Encodable {
  /// Metrics grouped by the resource that produced them.
  var resourceMetrics: [ResourceMetrics]
}

extension OTLPMetricsRequest {
  /// Metrics produced by a single resource.
  struct ResourceMetrics: Encodable {
    /// The resource that produced the metrics.
    var resource: Resource
    /// Metrics grouped by the instrumentation scope that recorded them.
    var scopeMetrics: [ScopeMetrics]
  }

  /// The entity that produced the metrics.
  struct Resource: Encodable {
    /// Attributes describing the resource.
    var attributes: [KeyValue]
  }

  /// Metrics recorded by a single instrumentation scope.
  struct ScopeMetrics: Encodable {
    /// The instrumentation scope that recorded the metrics.
    var scope: Scope
    /// The recorded metrics.
    var metrics: [Metric]
  }

  /// An instrumentation scope.
  struct Scope: Encodable {
    /// Name of the instrumentation scope.
    var name: String
  }

  /// A single metric and its data points.
  struct Metric: Encodable {
    /// Name of the metric.
    var name: String
    /// Human-readable description of what the metric measures.
    var description: String
    /// Unit of the metric values, using UCUM case-sensitive codes.
    var unit: String
    /// Gauge data, when the metric is a gauge.
    var gauge: Gauge?
    /// Histogram data, when the metric is a histogram.
    var histogram: Histogram?
  }

  /// A gauge metric's data.
  struct Gauge: Encodable {
    /// The recorded data points.
    var dataPoints: [NumberDataPoint]
  }

  /// A histogram metric's data.
  struct Histogram: Encodable {
    /// The recorded data points.
    var dataPoints: [HistogramDataPoint]
    /// How the values relate to time, as an `AggregationTemporality` raw value.
    var aggregationTemporality: Int
  }

  /// A single scalar measurement.
  struct NumberDataPoint: Encodable {
    /// Attributes qualifying this data point.
    var attributes: [KeyValue]
    /// Time of the measurement, in nanoseconds since the Unix epoch, encoded as a string.
    var timeUnixNano: String
    /// The value, when it is an integer, encoded as a string.
    var asInt: String?
    /// The value, when it is a floating-point number.
    var asDouble: Double?
  }

  /// A single histogram measurement.
  struct HistogramDataPoint: Encodable {
    /// Attributes qualifying this data point.
    var attributes: [KeyValue]
    /// Start of the period the histogram covers, in nanoseconds since the Unix epoch.
    var startTimeUnixNano: String
    /// End of the period the histogram covers, in nanoseconds since the Unix epoch.
    var timeUnixNano: String
    /// Number of values recorded, encoded as a string.
    var count: String
    /// Sum of all recorded values.
    var sum: Double
    /// Number of values falling into each bucket, encoded as strings.
    ///
    /// Contains one more element than ``explicitBounds``: the final element counts values
    /// above the last boundary.
    var bucketCounts: [String]
    /// Upper boundaries of the histogram buckets, exclusive of the implicit final bucket.
    var explicitBounds: [Double]
    /// Smallest recorded value, omitted when no values were recorded.
    var min: Double?
    /// Largest recorded value, omitted when no values were recorded.
    var max: Double?
  }

  /// A single attribute.
  struct KeyValue: Encodable {
    /// Attribute name.
    var key: String
    /// Attribute value.
    var value: AnyValue
  }

  /// An attribute value.
  struct AnyValue: Encodable {
    /// The value, when it is a string.
    var stringValue: String?
  }
}

extension OTLPMetricsRequest {
  /// How a metric's values relate to the time interval they cover.
  enum AggregationTemporality: Int {
    /// Values cover only the reported interval.
    ///
    /// A CI run is a one-shot process whose counts start at zero and end with the run, so its
    /// measurements describe that run alone rather than a running total.
    case delta = 1
    /// Values accumulate since the start of a longer-lived process.
    case cumulative = 2
  }
}

extension OTLPMetricsRequest.KeyValue {
  /// Creates a string attribute.
  ///
  /// - Parameters:
  ///   - key: Attribute name.
  ///   - value: Attribute value.
  init(key: String, stringValue value: String) {
    self.init(key: key, value: OTLPMetricsRequest.AnyValue(stringValue: value))
  }
}
