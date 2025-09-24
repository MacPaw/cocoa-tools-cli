/// Protocol that defines the configuration for a secret source.
///
/// Configurations provide the necessary parameters for secret sources to operate,
/// such as authentication details, endpoints, or other provider-specific settings.
public protocol SecretConfigurationProtocol: Sendable, Equatable {
  /// The configuration key used in YAML to identify this secret source configuration.
  static var configurationKey: String { get }

  /// Validates the configuration parameters.
  /// - Throws: An error if the configuration is invalid or incomplete.
  mutating func validate() throws
}

extension SecretConfigurationProtocol {
  /// Default implementation of validate that performs no validation.
  public mutating func validate() {}
}
