import ArgumentParser
import Foundation
import TestsOTELReporter

extension Options {
  /// Names of the OpenTelemetry environment variables the command falls back to.
  enum EnvironmentKey {
    /// Base URL of the OTLP endpoint.
    static let endpoint: String = "OTEL_EXPORTER_OTLP_ENDPOINT"
    /// Comma-separated `key=value` headers sent with the export.
    static let headers: String = "OTEL_EXPORTER_OTLP_HEADERS"
    /// Base URL of a Loki endpoint for logs.
    static let lokiEndpoint: String = "LOKI_OTLP_ENDPOINT"
    /// Comma-separated `key=value` headers sent with the logs export.
    static let lokiHeaders: String = "LOKI_OTLP_HEADERS"
    /// Value of the `service.name` resource attribute.
    static let serviceName: String = "OTEL_SERVICE_NAME"
    /// Run finish time, reused from the Azure Pipelines CAS metrics for a shared sample instant.
    static let buildFinishTime: String = "BUILD_FINISHTIME"
  }

  /// A test report the command was asked to read.
  enum Input: Equatable {
    /// An `.xcresult` bundle.
    case xcresult(URL)
    /// An xUnit XML report.
    case xunit(URL)
  }

  /// What the command was asked to read.
  struct Inputs: Equatable {
    /// The test report to read, if any.
    var report: Input?
    /// The `llvm-cov export` JSON file to read line coverage from, if any.
    var llvmLineCoverage: URL?
  }

  /// Resolves what to read.
  ///
  /// `--xcresult` is a complete input on its own, so it excludes the others; `--xunit` and
  /// `--llvm-line-coverage` may be combined, and either may be given alone.
  ///
  /// - Returns: The selected inputs.
  /// - Throws: `ValidationError` when no input is given, the combination is ambiguous or
  ///   contradicts `--no-line-coverage`, or a file is missing.
  func resolvedInputs() throws -> Inputs {
    #if os(macOS)
      let xcresultPath: String? = xcresult
    #else
      let xcresultPath: String? = .none
    #endif

    if xcresultPath != nil, xunit != nil {
      throw ValidationError("Pass only one of --xcresult or --xunit")
    }
    if xcresultPath != nil, llvmLineCoverage != nil {
      throw ValidationError(
        "--llvm-line-coverage cannot be combined with --xcresult, which already carries line coverage"
      )
    }
    if llvmLineCoverage != nil, !lineCoverage {
      throw ValidationError("--llvm-line-coverage contradicts --no-line-coverage")
    }

    let report: Input? =
      if let xcresultPath { Input.xcresult(try Self.existingFileURL(atPath: xcresultPath, option: "--xcresult")) }
      else if let xunit { Input.xunit(try Self.existingFileURL(atPath: xunit, option: "--xunit")) }
      else { .none }
    let llvmLineCoverageURL: URL? = try llvmLineCoverage.map {
      try Self.existingFileURL(atPath: $0, option: "--llvm-line-coverage")
    }

    guard report != nil || llvmLineCoverageURL != nil else {
      #if os(macOS)
        throw ValidationError("One of --xcresult, --xunit or --llvm-line-coverage is required")
      #else
        throw ValidationError("One of --xunit or --llvm-line-coverage is required")
      #endif
    }

    return Inputs(report: report, llvmLineCoverage: llvmLineCoverageURL)
  }

  /// Resolves the OTLP base URL from the flag, falling back to the environment.
  ///
  /// - Parameter environment: Environment variables to fall back to.
  /// - Returns: The base URL of the OTLP endpoint.
  /// - Throws: `ValidationError` when no endpoint is configured, or it is not a valid URL.
  func resolvedEndpoint(environment: [String: String]) throws -> URL {
    let rawValue: String? = endpoint ?? Self.nonEmpty(environment[EnvironmentKey.endpoint])

    guard let rawValue else {
      throw ValidationError("--endpoint is required, or set $\(EnvironmentKey.endpoint)")
    }
    return try Self.validatedURL(rawValue, description: "OTLP endpoint")
  }

  /// Resolves the Loki base URL from the flag, falling back to the environment.
  ///
  /// - Parameter environment: Environment variables to fall back to.
  /// - Returns: The base URL of the Loki endpoint, or `nil` when logs should go to the OTLP endpoint.
  /// - Throws: `ValidationError` when the configured value is not a valid URL.
  func resolvedLokiEndpoint(environment: [String: String]) throws -> URL? {
    let rawValue: String? = lokiOtlpEndpoint ?? Self.nonEmpty(environment[EnvironmentKey.lokiEndpoint])

    return try rawValue.map { try Self.validatedURL($0, description: "Loki endpoint") }
  }

  /// Resolves the headers sent with the export.
  ///
  /// Headers parsed from the environment form the base set, and `--header` values are merged over
  /// them, so a flag can override one header without restating the rest.
  ///
  /// - Parameter environment: Environment variables to read headers from.
  /// - Returns: The headers to send, keyed by header name.
  /// - Throws: `ValidationError` when a `--header` value is not in `key=value` form.
  func resolvedHeaders(environment: [String: String]) throws -> [String: String] {
    try Self.mergedHeaders(
      environment: environment[EnvironmentKey.headers] ?? "",
      flags: header,
      option: "--header",
    )
  }

  /// Resolves the headers sent with the logs export.
  ///
  /// Merged like ``resolvedHeaders(environment:)``, but from the Loki-specific sources only,
  /// since Loki often authenticates differently from the metrics backend.
  ///
  /// - Parameter environment: Environment variables to read headers from.
  /// - Returns: The headers to send, or `nil` when none are configured and the metrics headers
  ///   should be used.
  /// - Throws: `ValidationError` when a `--loki-otlp-header` value is not in `key=value` form.
  func resolvedLokiHeaders(environment: [String: String]) throws -> [String: String]? {
    let rawEnvironment: String? = Self.nonEmpty(environment[EnvironmentKey.lokiHeaders])
    guard rawEnvironment != nil || !lokiOtlpHeader.isEmpty else { return .none }

    return try Self.mergedHeaders(
      environment: rawEnvironment ?? "",
      flags: lokiOtlpHeader,
      option: "--loki-otlp-header",
    )
  }

  /// Resolves the `service.name` resource attribute.
  ///
  /// - Parameter environment: Environment variables to read the name from.
  /// - Returns: `$OTEL_SERVICE_NAME`, or the shared default when it is unset or empty.
  func resolvedServiceName(environment: [String: String]) -> String {
    Self.nonEmpty(environment[EnvironmentKey.serviceName]) ?? TestsOTELReporter.Configuration.defaultServiceName
  }

  /// Resolves the timestamp recorded on every data point.
  ///
  /// Resolution order matches the Azure Pipelines CAS metrics action, so metrics from both land
  /// on the same instant in a dashboard: the `--timestamp` flag, then `BUILD_FINISHTIME`, then
  /// the current time.
  ///
  /// - Parameters:
  ///   - environment: Environment variables to fall back to.
  ///   - now: The current time, used when nothing else is configured.
  /// - Returns: The timestamp to record.
  func resolvedTimestamp(environment: [String: String], now: Date = Date()) -> Date {
    if let timestamp { return Date(timeIntervalSince1970: Double(timestamp) / 1000) }

    if let rawValue = environment[EnvironmentKey.buildFinishTime], !rawValue.isEmpty,
      let finishTime = Self.parseBuildFinishTime(rawValue)
    {
      return finishTime
    }

    return now
  }

  /// Treats an empty string like an unset value.
  ///
  /// - Parameter value: The raw value.
  /// - Returns: The value, or `nil` when it is absent or empty.
  private static func nonEmpty(_ value: String?) -> String? {
    value.flatMap { $0.isEmpty ? .none : $0 }
  }

  /// Parses an http(s) URL, or reports a validation error.
  ///
  /// - Parameters:
  ///   - rawValue: The raw URL.
  ///   - description: What the URL is, used in the error message.
  /// - Returns: The parsed URL.
  /// - Throws: `ValidationError` when the value is not an http(s) URL.
  private static func validatedURL(_ rawValue: String, description: String) throws -> URL {
    guard let url = URL(string: rawValue), let scheme = url.scheme?.lowercased(), url.host != nil,
      scheme == "http" || scheme == "https"
    else {
      throw ValidationError("Invalid \(description) URL, expected an http(s) URL: \(rawValue)")
    }

    return url
  }

  /// Merges `key=value` flag entries over headers parsed from an environment variable.
  ///
  /// - Parameters:
  ///   - environment: The raw environment variable value.
  ///   - flags: The `key=value` entries given on the command line.
  ///   - option: Name of the option the entries came from, used in the error message.
  /// - Returns: The merged headers, keyed by header name.
  /// - Throws: `ValidationError` when an entry is not in `key=value` form.
  private static func mergedHeaders(environment: String, flags: [String], option: String) throws -> [String: String] {
    var headers: [String: String] = OTLPHeaders.parse(environment)

    for entry in flags {
      guard let separatorIndex = entry.firstIndex(of: "=") else {
        throw ValidationError("Invalid \(option) value, expected key=value: \(entry)")
      }

      let key = entry[..<separatorIndex].trimmingCharacters(in: .whitespaces)
      guard !key.isEmpty else {
        throw ValidationError("Invalid \(option) value, key is empty: \(entry)")
      }

      headers[key] = entry[entry.index(after: separatorIndex)...].trimmingCharacters(in: .whitespaces)
    }

    return headers
  }

  /// Builds a URL for an existing file, or reports a validation error.
  ///
  /// - Parameters:
  ///   - path: Path given on the command line.
  ///   - option: Name of the option the path came from, used in the error message.
  /// - Returns: A file URL for the path.
  /// - Throws: `ValidationError` when nothing exists at the path.
  private static func existingFileURL(atPath path: String, option: String) throws -> URL {
    guard FileManager.default.fileExists(atPath: path) else {
      throw ValidationError("\(option) not found: \(path)")
    }
    return URL(fileURLWithPath: path)
  }
}

extension Options {
  /// Parses an Azure Pipelines `BUILD_FINISHTIME` value.
  ///
  /// Azure emits ISO 8601 with seven fractional digits, which `ISO8601DateFormatter` rejects
  /// even with fractional seconds enabled, so the fraction is truncated to the three digits the
  /// formatter accepts before falling back to a whole-second parse.
  ///
  /// - Parameter rawValue: The raw variable value.
  /// - Returns: The parsed date, or `nil` when the value is not ISO 8601.
  static func parseBuildFinishTime(_ rawValue: String) -> Date? {
    let milliseconds = rawValue.replacing(/\.(\d{3})\d+/) { ".\($0.output.1)" }
    if let date = ISO8601DateFormatter.make(formatOptions: [.withInternetDateTime, .withFractionalSeconds])
      .date(from: milliseconds)
    {
      return date
    }

    let wholeSeconds = rawValue.replacing(/\.\d+/, with: "")
    return ISO8601DateFormatter.make(formatOptions: [.withInternetDateTime]).date(from: wholeSeconds)
  }
}

extension ISO8601DateFormatter {
  /// Creates a formatter for ISO 8601 dates.
  ///
  /// Instantiated per call rather than shared: `ISO8601DateFormatter` is not `Sendable`, and a
  /// one-shot CLI parses at most one date per run.
  ///
  /// - Parameter formatOptions: Options the formatter accepts.
  /// - Returns: The configured formatter.
  fileprivate static func make(formatOptions: ISO8601DateFormatter.Options) -> ISO8601DateFormatter {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = formatOptions
    return formatter
  }
}
