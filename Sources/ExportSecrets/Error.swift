extension ExportSecrets {
  /// Errors that can occur during secret import operations.
  public enum Error: Swift.Error {
    /// Thrown when no secrets are available to export.
    case noSecretsToExport
    /// Thrown when trying to use synchronous export on an async-only destination.
    case syncExportNotSupported
    /// Thrown when a file cannot be created at the specified path.
    case fileCreationFailed(String)
  }
}

private typealias Error = ExportSecrets.Error

extension Error: Equatable {}
extension Error: Sendable {}
