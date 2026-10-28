import Foundation
import Testing

/// Read-only navigation over a decoded OTLP logs payload, so tests assert on the wire format that
/// is actually sent rather than on the structs used to build it.
struct OTLPLogsPayload {
  /// The decoded payload.
  private let json: [String: Any]

  /// Decodes a payload.
  ///
  /// - Parameter data: The JSON-encoded OTLP logs export request.
  /// - Throws: An error if the data is not a JSON object.
  init(data: Data) throws {
    json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
  }

  /// Resource attributes, keyed by attribute name, with their string values.
  var resourceAttributes: [String: String] {
    let resourceLogs = json["resourceLogs"] as? [[String: Any]] ?? []
    let attributes = resourceLogs.flatMap { resourceLog in
      (resourceLog["resource"] as? [String: Any]).flatMap { $0["attributes"] as? [[String: Any]] } ?? []
    }

    return OTLPPayload.attributes(of: ["attributes": attributes])
  }

  /// Every log record in the payload.
  var logRecords: [[String: Any]] {
    let resourceLogs = json["resourceLogs"] as? [[String: Any]] ?? []
    let scopeLogs = resourceLogs.flatMap { $0["scopeLogs"] as? [[String: Any]] ?? [] }
    return scopeLogs.flatMap { $0["logRecords"] as? [[String: Any]] ?? [] }
  }

  /// The message of a log record.
  ///
  /// - Parameter record: The log record.
  /// - Returns: The body's string value.
  static func body(of record: [String: Any]) -> String? {
    (record["body"] as? [String: Any])?["stringValue"] as? String
  }

  /// A floating-point attribute of a log record.
  ///
  /// - Parameters:
  ///   - name: Attribute name.
  ///   - record: The log record.
  /// - Returns: The attribute's value, or `nil` when absent.
  static func doubleAttribute(_ name: String, of record: [String: Any]) -> Double? {
    let attributes = record["attributes"] as? [[String: Any]] ?? []
    let attribute = attributes.first { $0["key"] as? String == name }
    return (attribute?["value"] as? [String: Any])?["doubleValue"] as? Double
  }
}
