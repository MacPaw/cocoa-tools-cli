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
    case responseNotHTTP(URLResponse)
    /// The collector rejected the export with a non-success status code.
    case wrongStatusCode(Int, body: String?)
  }
}

extension TestsOTELReporter.Error: CustomStringConvertible {
  /// A human-readable description of the failure.
  public var description: String {
    switch self {
    case .responseNotHTTP(let response):
      "OTLP endpoint returned a non-HTTP response: \(response)"
    case .wrongStatusCode(let statusCode, let body):
      "OTLP endpoint returned status code \(statusCode)\(body.map { ": \($0)" } ?? "")"
    }
  }
}
