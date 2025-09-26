import SecretsInterface

/// Mock implementation of `SecretSourceProtocol` for testing purposes.
///
/// This mock provides configurable behavior for testing secret source scenarios.
public struct MockSecretSource: SecretSourceProtocol {
  /// The configuration type associated with this secret source.
  public typealias Configuration = MockSecretConfiguration

  /// A unique Secret Source item in the source provider.
  public typealias Item = MockSecretSourceItem

  /// A unique Secret Source item in the source provider.
  public let item: Item

  /// A list of keys to fetch from the secret source item.
  public let keys: [String]

  /// Flag to control whether validation should throw an error.
  public var shouldFailValidation: Bool

  /// Custom validation error to throw when validation fails.
  public var validationError: String?

  /// Creates a new mock secret source.
  ///
  /// - Parameters:
  ///   - item: The source item. Defaults to a new mock item.
  ///   - keys: The keys to fetch. Defaults to an empty array.
  ///   - shouldFailValidation: Whether validation should fail. Defaults to `false`.
  ///   - validationError: Custom error message to throw during validation. If `nil` and `shouldFailValidation` is `true`,
  ///                      a default error will be thrown.
  public init(
    item: Item = MockSecretSourceItem(),
    keys: [String] = [],
    shouldFailValidation: Bool = false,
    validationError: String? = nil
  ) {
    self.item = item
    self.keys = keys
    self.shouldFailValidation = shouldFailValidation
    self.validationError = validationError
  }

  /// Validates the secret source configuration.
  ///
  /// - Parameter configuration: Optional configuration to validate against.
  /// - Throws: The configured validation error if `shouldFailValidation` is `true`.
  public mutating func validate(with configuration: Configuration?) throws {
    if shouldFailValidation {
      guard let validationError else { throw MockError.validationFailed }
      throw MockError.validationFailedWithMessage(validationError)
    }
  }
}

extension MockSecretSource {
  /// Errors that can be thrown by the mock source.
  public enum MockError: Error, Equatable {
    case validationFailed
    case validationFailedWithMessage(String)
  }

  /// Factory methods for creating common test scenarios.
  public static func withKeys(_ keys: [String], item: Item = MockSecretSourceItem()) -> MockSecretSource {
    MockSecretSource(item: item, keys: keys)
  }

  /// Factory method for creating a source that will fail validation.
  public static func failingValidation(
    errorMessage: String? = nil,
    item: Item = MockSecretSourceItem(),
    keys: [String] = []
  ) -> MockSecretSource {
    MockSecretSource(item: item, keys: keys, shouldFailValidation: true, validationError: errorMessage)
  }
}
