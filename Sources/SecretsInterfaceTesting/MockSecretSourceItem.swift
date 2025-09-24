import Foundation
import SecretsInterface

/// Mock implementation of `SecretSourceItemProtocol` for testing purposes.
///
/// This mock provides a simple, configurable implementation for testing secret source item scenarios.
public struct MockSecretSourceItem: SecretSourceItemProtocol {
  /// Unique identifier for this source item.
  public let id: String

  /// Optional name for better test readability.
  public let name: String?

  /// Creates a new mock source item.
  ///
  /// - Parameters:
  ///   - id: Unique identifier for the item. Defaults to a UUID string.
  ///   - name: Optional name for the item. Defaults to `nil`.
  public init(id: String = UUID().uuidString, name: String? = nil) {
    self.id = id
    self.name = name
  }

  /// Creates a mock source item with a specific name and auto-generated ID.
  ///
  /// - Parameter name: The name for the item.
  /// - Returns: A new mock source item with the given name.
  public static func named(_ name: String) -> MockSecretSourceItem { MockSecretSourceItem(name: name) }
}

extension MockSecretSourceItem {
  /// Predefined mock items for common testing scenarios.
  public enum Predefined {
    /// A mock item representing a database configuration.
    public static let database = MockSecretSourceItem(id: "db-config", name: "Database Configuration")
    /// A mock item representing API credentials.
    public static let apiCredentials = MockSecretSourceItem(id: "api-creds", name: "API Credentials")
    /// A mock item representing SSL certificates.
    public static let sslCertificates = MockSecretSourceItem(id: "ssl-certs", name: "SSL Certificates")
  }
}
