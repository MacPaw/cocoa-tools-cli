import Foundation
import Testing

/// Read-only navigation over a decoded OTLP traces payload, so tests assert on the wire format that
/// is actually sent rather than on the structs used to build it.
struct OTLPTracesPayload {
  /// The decoded payload.
  private let json: [String: Any]

  /// Decodes a payload.
  ///
  /// - Parameter data: The JSON-encoded OTLP traces export request.
  /// - Throws: An error if the data is not a JSON object.
  init(data: Data) throws {
    json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
  }

  /// Resource attributes, keyed by attribute name, with their string values.
  var resourceAttributes: [String: String] {
    let resourceSpans = json["resourceSpans"] as? [[String: Any]] ?? []
    let attributes = resourceSpans.flatMap { resourceSpan in
      (resourceSpan["resource"] as? [String: Any]).flatMap { $0["attributes"] as? [[String: Any]] } ?? []
    }

    return OTLPPayload.attributes(of: ["attributes": attributes])
  }

  /// Every span in the payload, in the order sent.
  var spans: [[String: Any]] {
    let resourceSpans = json["resourceSpans"] as? [[String: Any]] ?? []
    let scopeSpans = resourceSpans.flatMap { $0["scopeSpans"] as? [[String: Any]] ?? [] }
    return scopeSpans.flatMap { $0["spans"] as? [[String: Any]] ?? [] }
  }

  /// A floating-point attribute of a span.
  ///
  /// - Parameters:
  ///   - name: Attribute name.
  ///   - span: The span.
  /// - Returns: The attribute's value, or `nil` when absent.
  static func doubleAttribute(_ name: String, of span: [String: Any]) -> Double? {
    let attributes = span["attributes"] as? [[String: Any]] ?? []
    let attribute = attributes.first { $0["key"] as? String == name }
    return (attribute?["value"] as? [String: Any])?["doubleValue"] as? Double
  }

  /// The status code of a span.
  ///
  /// - Parameter span: The span.
  /// - Returns: The code, where 0 is unset and 2 is error.
  static func statusCode(of span: [String: Any]) -> Int {
    (span["status"] as? [String: Any])?["code"] as? Int ?? 0
  }

  /// The status message of a span.
  ///
  /// - Parameter span: The span.
  /// - Returns: The message, or `nil` when absent.
  static func statusMessage(of span: [String: Any]) -> String? {
    (span["status"] as? [String: Any])?["message"] as? String
  }

  /// The time a span covers.
  ///
  /// - Parameter span: The span.
  /// - Returns: Start and end, in nanoseconds since the Unix epoch.
  static func interval(of span: [String: Any]) -> (start: Int, end: Int) {
    (
      Int(span["startTimeUnixNano"] as? String ?? "") ?? 0,
      Int(span["endTimeUnixNano"] as? String ?? "") ?? 0,
    )
  }
}
