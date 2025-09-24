import Foundation
import SecretsInterface

/// Mock implementation of `SecretConfigurationProtocol` for testing purposes.
///
/// This mock provides configurable behavior for testing secret configuration scenarios.
public struct MockSecretConfiguration: SecretConfigurationProtocol, Decodable {
  /// The configuration key used in YAML to identify this secret source configuration.
  public static let configurationKey: String = "mock"

  /// Flag to control whether validation should throw an error.
  public var shouldFailValidation: Bool

  /// Custom validation error to throw when validation fails.
  public var validationError: String?

  /// Creates a new mock configuration.
  ///
  /// - Parameters:
  ///   - shouldFailValidation: Whether validation should fail. Defaults to `false`.
  ///   - validationError: Custom error message to throw during validation. If `nil` and `shouldFailValidation` is `true`,
  ///                      a default error will be thrown.
  public init(shouldFailValidation: Bool = false, validationError: String? = nil) {
    self.shouldFailValidation = shouldFailValidation
    self.validationError = validationError
  }

  /// Validates the configuration parameters.
  ///
  /// - Throws: The configured validation error if `shouldFailValidation` is `true`.
  public mutating func validate() throws {
    if shouldFailValidation {
      guard let validationError else { throw MockError.validationFailed }
      throw MockError.validationFailedWithMessage(validationError)
    }
  }
}

extension MockSecretConfiguration {
  /// Errors that can be thrown by the mock configuration.
  public enum MockError: Error, Equatable {
    case validationFailed
    case validationFailedWithMessage(String)
  }
}
