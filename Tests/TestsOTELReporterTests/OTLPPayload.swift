import Foundation
import Testing

/// Read-only navigation over a decoded OTLP payload, so tests assert on the wire format that is
/// actually sent rather than on the structs used to build it.
struct OTLPPayload {
  /// The decoded payload.
  private let json: [String: Any]

  /// Decodes a payload.
  ///
  /// - Parameter data: The JSON-encoded OTLP export request.
  /// - Throws: An error if the data is not a JSON object.
  init(data: Data) throws {
    json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
  }

  /// Every metric in the payload, keyed by metric name.
  var metricsByName: [String: [String: Any]] {
    let resourceMetrics = json["resourceMetrics"] as? [[String: Any]] ?? []
    let scopeMetrics = resourceMetrics.flatMap { $0["scopeMetrics"] as? [[String: Any]] ?? [] }
    let metrics = scopeMetrics.flatMap { $0["metrics"] as? [[String: Any]] ?? [] }

    return Dictionary(
      uniqueKeysWithValues: metrics.compactMap { metric in
        (metric["name"] as? String).map { ($0, metric) }
      }
    )
  }

  /// Resource attributes, keyed by attribute name, with their string values.
  var resourceAttributes: [String: String] {
    let resourceMetrics = json["resourceMetrics"] as? [[String: Any]] ?? []
    let attributes = resourceMetrics.flatMap { resourceMetric in
      (resourceMetric["resource"] as? [String: Any]).flatMap { $0["attributes"] as? [[String: Any]] } ?? []
    }

    return Self.attributes(attributes)
  }

  /// The data points of a gauge metric.
  ///
  /// - Parameter name: Name of the metric.
  /// - Returns: The metric's gauge data points.
  /// - Throws: An error if the metric is absent or is not a gauge.
  func gaugeDataPoints(_ name: String) throws -> [[String: Any]] {
    let metric = try #require(metricsByName[name])
    let gauge = try #require(metric["gauge"] as? [String: Any])
    return gauge["dataPoints"] as? [[String: Any]] ?? []
  }

  /// The data points of a histogram metric.
  ///
  /// - Parameter name: Name of the metric.
  /// - Returns: The metric's histogram data points.
  /// - Throws: An error if the metric is absent or is not a histogram.
  func histogramDataPoints(_ name: String) throws -> [[String: Any]] {
    let metric = try #require(metricsByName[name])
    let histogram = try #require(metric["histogram"] as? [String: Any])
    return histogram["dataPoints"] as? [[String: Any]] ?? []
  }

  /// Extracts the string attributes of a data point.
  ///
  /// - Parameter dataPoint: The data point.
  /// - Returns: The attributes, keyed by name.
  static func attributes(of dataPoint: [String: Any]) -> [String: String] {
    attributes(dataPoint["attributes"] as? [[String: Any]] ?? [])
  }

  /// Flattens OTLP key/value attributes into a dictionary of string values.
  ///
  /// - Parameter attributes: The raw attribute list.
  /// - Returns: The attributes, keyed by name.
  private static func attributes(_ attributes: [[String: Any]]) -> [String: String] {
    attributes.reduce(into: [String: String]()) { result, attribute in
      guard
        let key = attribute["key"] as? String,
        let value = attribute["value"] as? [String: Any],
        let stringValue = value["stringValue"] as? String
      else { return }
      result[key] = stringValue
    }
  }
}
