import ENV

extension ENV {
  /// Check if all keys are present in the environment and not empty.
  ///
  /// - Parameters:
  ///   - keys: Keys to check.
  ///
  /// - Returns: `true` if all keys are present and not empty, `false` otherwise.
  func hasAll(keys: String...) -> Bool { keys.allSatisfy { self[$0] != nil && !self[$0]!.isEmpty } }
}
