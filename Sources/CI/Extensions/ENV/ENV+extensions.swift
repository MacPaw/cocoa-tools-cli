import ENV

extension ENV {
  /// Check if all keys are present in the environment and not empty.
  ///
  /// - Parameter keys: Keys to check.
  /// - Returns: `true` if all keys are present and not empty, `false` otherwise.
  func hasAll(keys: String...) -> Bool {
    keys.allSatisfy { key in
      guard let value = self[key] else { return false }
      return !value.isEmpty
    }
  }
}
