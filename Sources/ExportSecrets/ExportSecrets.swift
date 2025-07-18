import Foundation

/// Main entry point for exporting secrets to various destinations.
public enum ExportSecrets {}

extension ExportSecrets {
  /// Exports secrets to an asynchronous destination.
  /// - Parameters:
  ///   - secrets: Dictionary mapping environment variable names to their secret values.
  ///   - destination: The async export destination to write secrets to.
  /// - Throws: Error.noSecretsToExport if no secrets are provided, or export errors from the destination.
  public static func export(secrets: [String: String], destination: any ExportSecretsAsyncDestinationProtocol)
    async throws
  {
    guard !secrets.isEmpty else { throw Error.noSecretsToExport }

    try await destination.export(secrets: secrets)
  }

  /// Exports secrets to a synchronous destination.
  /// - Parameters:
  ///   - secrets: Dictionary mapping environment variable names to their secret values.
  ///   - destination: The export destination to write secrets to.
  /// - Throws: Error.noSecretsToExport if no secrets are provided, or export errors from the destination.
  public static func export(secrets: [String: String], destination: any ExportSecretsDestinationProtocol) throws {
    guard !secrets.isEmpty else { throw Error.noSecretsToExport }

    try destination.export(secrets: secrets)
  }
}
