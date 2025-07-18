/// A dynamic coding key that can be created from string or integer values.
/// This is used internally for decoding YAML configurations with dynamic keys.
struct DynamicCodingKey {
  /// The string representation of the coding key.
  var stringValue: String
  /// The integer representation of the coding key, if applicable.
  var intValue: Int?
}

extension DynamicCodingKey: Swift.CodingKey {
  /// Creates a coding key from a string value.
  /// - Parameter stringValue: The string value for the key.
  init(stringValue: String) { self.init(stringValue: stringValue, intValue: .none) }

  /// Creates a coding key from an integer value.
  /// - Parameter intValue: The integer value for the key.
  init?(intValue: Int) { self.init(stringValue: "\(intValue)", intValue: intValue) }
}
