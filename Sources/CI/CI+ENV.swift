/// Environment variables management.
public protocol CIEnvInterface: Sendable {
  /// Set a secret in the CI.
  ///
  /// - Parameters:
  ///   - name: The name of the secret.
  ///   - value: The value of the secret.
  ///   - isOutput: Whether the secret is an output secret.
  ///
  /// - Throws: An error if the secret cannot be set.
  func setSecret(name: String, value: String, isOutput: Bool) throws
  /// Set a variable in the CI.
  ///
  /// - Parameters:
  ///   - name: The name of the variable.
  ///   - value: The value of the variable.
  ///   - isOutput: Whether the variable is an output variable.
  ///
  /// - Throws: An error if the variable cannot be set.
  func setVariable(name: String, value: String, isOutput: Bool) throws
}

extension CIEnvInterface {
  func setVariable(name: String, value: String, isSecret: Bool, isOutput: Bool) throws {
    if isSecret {
      try setSecret(name: name, value: value, isOutput: isOutput)
    }
    else {
      try setVariable(name: name, value: value, isOutput: isOutput)
    }
  }
}
