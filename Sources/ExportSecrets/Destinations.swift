/// Protocol for synchronous secret export destinations.
/// Destinations that implement this protocol can export secrets to various formats or systems.
public protocol ExportSecretsDestinationProtocol: Sendable {
  /// Exports secrets to the destination.
  /// - Parameter secrets: Dictionary mapping environment variable names to their values.
  /// - Throws: Export errors if the operation fails.
  func export(secrets: [String: String]) throws
}

/// Protocol for asynchronous secret export destinations.
/// This extends the base protocol to support destinations that require async operations.
public protocol ExportSecretsAsyncDestinationProtocol: ExportSecretsDestinationProtocol {
  /// Exports secrets to the destination asynchronously.
  /// - Parameter secrets: Dictionary mapping environment variable names to their values.
  /// - Throws: Export errors if the operation fails.
  func export(secrets: [String: String]) async throws
}

extension ExportSecretsAsyncDestinationProtocol {
  @available(*, unavailable, message: "This destination does not support sync export")
  public func export(secrets: [String: String]) throws { throw ExportSecrets.Error.syncExportNotSupported }
}

extension ExportSecrets { public enum Destinations {} }
