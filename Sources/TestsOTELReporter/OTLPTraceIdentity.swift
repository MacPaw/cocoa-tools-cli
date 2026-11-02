import CI
import Foundation

/// Derives the trace and span IDs of a test run.
///
/// IDs are deterministic whenever the CI reports a run id, so exporting the same job again lands
/// on the same trace and span IDs instead of duplicating the trace. Without a CI context — a
/// local run — the trace ID is random.
enum OTLPTraceIdentity {
  /// Separates the components hashed into an ID, so `("ab", "c")` and `("a", "bc")` differ.
  private static let separator: String = "\u{1F}"

  /// Derives the trace ID of a run.
  ///
  /// The CI abstraction does not expose a re-run attempt number, so a re-run of a job overwrites
  /// the trace of the previous attempt.
  ///
  /// - Parameters:
  ///   - repository: Repository metadata for the run.
  ///   - cicd: Pipeline metadata for the run.
  /// - Returns: 32 lowercase hex characters: a hash of the repository and job identity, or a random
  ///   value when the CI reports no run id.
  static func traceID(repository: CI.Repository, cicd: CI.CICD) -> String {
    guard let runID = cicd.run.id else { return randomTraceID() }

    return hash128(
      components: [
        repository.provider, repository.organizationName, repository.repositoryName, cicd.pipelineName, runID,
        cicd.run.number, cicd.run.stageName, cicd.run.taskName,
      ]
    )
  }

  /// Derives the ID of a span within a trace.
  ///
  /// - Parameters:
  ///   - traceID: The trace the span belongs to.
  ///   - path: Position of the span in the run, such as `suite-2/case-5`.
  /// - Returns: 16 lowercase hex characters.
  static func spanID(traceID: String, path: String) -> String {
    hex(fnv1a64(Array((traceID + separator + path).utf8), offsetBasis: 0xcbf2_9ce4_8422_2325))
  }

  /// Generates a random trace ID.
  ///
  /// - Returns: 32 lowercase hex characters.
  private static func randomTraceID() -> String {
    UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
  }

  /// Hashes optional components into 128 bits.
  ///
  /// This is an identifier, not a security boundary, so two FNV-1a passes with different offset
  /// bases are enough and avoid a crypto dependency that Linux lacks in Foundation.
  ///
  /// - Parameter components: The components; absent ones hash as empty.
  /// - Returns: 32 lowercase hex characters.
  private static func hash128(components: [String?]) -> String {
    let bytes = Array(components.map { $0 ?? "" }.joined(separator: separator).utf8)
    return hex(fnv1a64(bytes, offsetBasis: 0xcbf2_9ce4_8422_2325))
      + hex(fnv1a64(bytes, offsetBasis: 0x8422_2325_cbf2_9ce4))
  }

  /// Computes the 64-bit FNV-1a hash of some bytes.
  ///
  /// - Parameters:
  ///   - bytes: The bytes to hash.
  ///   - offsetBasis: Starting value of the hash.
  /// - Returns: The hash.
  private static func fnv1a64(_ bytes: [UInt8], offsetBasis: UInt64) -> UInt64 {
    bytes.reduce(offsetBasis) { ($0 ^ UInt64($1)) &* 0x0000_0100_0000_01b3 }
  }

  /// Formats a value as 16 zero-padded lowercase hex characters.
  ///
  /// - Parameter value: The value.
  /// - Returns: The hex string.
  private static func hex(_ value: UInt64) -> String {
    let digits = String(value, radix: 16)
    return String(repeating: "0", count: 16 - digits.count) + digits
  }
}
