import Foundation

/// Parsing of the `OTEL_EXPORTER_OTLP_HEADERS` environment variable.
public enum OTLPHeaders {
  /// Parses a comma-separated list of `key=value` pairs.
  ///
  /// Keys and values are trimmed of surrounding whitespace. Entries without a `=`, or with an
  /// empty key, are ignored rather than treated as an error, since a malformed header should not
  /// prevent otherwise-valid headers from being sent. Values may themselves contain `=`.
  ///
  /// - Parameter rawValue: The raw environment variable value.
  /// - Returns: The parsed headers, keyed by header name.
  public static func parse(_ rawValue: String) -> [String: String] {
    rawValue.split(separator: ",")
      .reduce(into: [String: String]()) { headers, entry in
        guard let separatorIndex = entry.firstIndex(of: "=") else { return }

        let key = entry[..<separatorIndex].trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return }

        headers[key] = entry[entry.index(after: separatorIndex)...].trimmingCharacters(in: .whitespaces)
      }
  }
}
