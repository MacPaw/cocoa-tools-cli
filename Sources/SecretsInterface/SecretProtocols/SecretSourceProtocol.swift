/// Protocol that describes a secret source type (e.g., `1Password`, `Vault`).
///
/// A secret source represents a specific location or reference to a secret within a provider,
/// such as a specific item in 1Password or a path in HashiCorp Vault.
public protocol SecretSourceProtocol: Sendable {
  /// The configuration type associated with this secret source.
  /// This defines the parameters needed to configure the source provider.
  associatedtype Configuration: SecretConfigurationProtocol

  /// A unique Secret Source item in the source provider.
  ///
  /// The Secret Source type itself can be extended with extra info (e.g. labels, fields, paths),
  /// but the `Item` represents one item in the provider and that can contain several secret values.
  associatedtype Item: SecretSourceItemProtocol

  /// A unique Secret Source item in the source provider.
  var item: Item { get }

  /// A list of keys to fetch from the secret source item.
  var keys: [String] { get }

  /// Validates the secret source configuration.
  /// - Throws: An error if the source configuration is invalid or incomplete.
  mutating func validate(with configuration: Configuration?) throws
}

extension SecretSourceProtocol {
  /// Default implementation of validate that performs no validation.
  ///
  /// - Parameter configuration: Optional configuration to validate against.
  /// - Throws: Validation errors if the configuration is invalid.
  public mutating func validate(with configuration: Configuration?) throws {}
}

extension SecretSourceProtocol {
  /// The configuration key used in YAML to identify this secret source.
  @inlinable
  @inline(__always)
  package static var configurationKey: String { Configuration.configurationKey }
}
