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

extension ENV {
  /// Get the first non-empty value among the given keys.
  ///
  /// Keys are probed in order, and values that are present but empty are skipped, since CI
  /// providers routinely export defined-but-empty variables for metadata they do not have.
  ///
  /// - Parameter keys: Keys to probe, in order of preference.
  /// - Returns: The first non-empty value, or `nil` when no key holds one.
  func firstNonEmpty(of keys: String...) -> String? {
    for key in keys {
      let value: String? = self[key]
      guard let value, !value.isEmpty else { continue }
      return value
    }
    return .none
  }
}
