#if canImport(FoundationNetworking)
  public import FoundationNetworking
  import Foundation
#else
  public import Foundation
#endif

extension TestsOTELReporter {
  /// Errors raised while exporting test metrics.
  public enum Error: Swift.Error {
    /// The export response was not an HTTP response.
    ///
    /// The URL is redacted: user info and query are removed.
    case responseNotHTTP(URLResponse, url: URL)
    /// The collector rejected the export with a non-success status code.
    ///
    /// The URL is redacted: user info and query are removed.
    case wrongStatusCode(Int, url: URL, body: String?)
  }
}

extension TestsOTELReporter.Error {
  /// Most characters of a response body kept in an error description.
  static let maxBodyLength = 500

  /// Removes what could carry credentials from a URL, so it is safe to log or print.
  ///
  /// - Parameter url: The URL a request was sent to.
  /// - Returns: The URL with scheme, host, port and path only.
  static func redacted(_ url: URL) -> URL {
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
    components.user = nil
    components.password = nil
    components.query = nil
    components.fragment = nil
    return components.url ?? url
  }

  /// Shortens a response body so a gateway's HTML error page cannot flood the CI log.
  ///
  /// - Parameter body: The response body.
  /// - Returns: The body, cut to ``maxBodyLength`` characters and marked when it was cut.
  static func truncated(_ body: String) -> String {
    body.count > maxBodyLength ? "\(body.prefix(maxBodyLength))…(truncated)" : body
  }
}

extension TestsOTELReporter.Error: CustomStringConvertible {
  /// A human-readable description of the failure.
  public var description: String {
    switch self {
    case .responseNotHTTP(let response, let url):
      "OTLP export to \(url) got a non-HTTP response: \(response)"
    case .wrongStatusCode(let statusCode, let url, let body):
      "OTLP export to \(url) failed with status \(statusCode)\(body.map { ": \(Self.truncated($0))" } ?? "")"
    }
  }
}
