extension ENV {
  /// Get an environment variable by key.
  ///
  /// - Parameters:
  ///   - member: An environment variable name.
  public subscript<T: LosslessStringConvertible>(dynamicMember member: String) -> T? {
    variables[member].flatMap(T.init)
  }

  /// Get an environment variable by key.
  ///
  /// - Parameters:
  ///   - member: An environment variable name.
  public subscript<T: LosslessStringConvertible>(_ member: String) -> T? { variables[member].flatMap(T.init) }

  /// Get an environment variable by key.
  ///
  /// - Parameters:
  ///   - member: An environment variable name.
  ///   - defaultValue: A default value if the environment variable is not set.
  public subscript<T: LosslessStringConvertible>(_ member: String, default defaultValue: T) -> T {
    variables[member].flatMap(T.init) ?? defaultValue
  }

  /// Get an environment variable by key.
  ///
  /// - Parameters:
  ///   - member: An environment variable name.
  public static subscript<T: LosslessStringConvertible>(dynamicMember member: String) -> T? {
    current.variables[member].flatMap(T.init)
  }

  /// Get an environment variable by key.
  ///
  /// - Parameters:
  ///   - member: An environment variable name.
  public static subscript<T: LosslessStringConvertible>(_ member: String) -> T? {
    current.variables[member].flatMap(T.init)
  }

  /// Get an environment variable by key.
  ///
  /// - Parameters:
  ///   - member: An environment variable name.
  ///   - defaultValue: A default value if the environment variable is not set.
  public static subscript<T: LosslessStringConvertible>(_ member: String, default defaultValue: T) -> T {
    current.variables[member].flatMap(T.init) ?? defaultValue
  }
}
