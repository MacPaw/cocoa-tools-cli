extension ENV {
  /// Get an environment variable by key.
  ///
  /// - Parameters:
  ///   - member: An environment variable name.
  public subscript(dynamicMember member: String) -> Bool { variables[member].toBool }

  /// Get an environment variable by key.
  ///
  /// - Parameters:
  ///   - member: An environment variable name.
  public subscript(_ member: String) -> Bool { variables[member].toBool }

  /// Get an environment variable by key.
  ///
  /// - Parameters:
  ///   - member: An environment variable name.
  ///   - defaultValue: A default value if the environment variable is not set.
  public subscript(_ member: String, default defaultValue: Bool) -> Bool { variables[member]?.toBool ?? defaultValue }

  /// Get an environment variable by key.
  ///
  /// - Parameters:
  ///   - member: An environment variable name.
  @inlinable
  public static subscript(dynamicMember member: String) -> Bool { current.variables[member].toBool }

  /// Get an environment variable by key.
  ///
  /// - Parameters:
  ///   - member: An environment variable name.
  @inlinable
  public static subscript(_ member: String) -> Bool { current.variables[member].toBool }

  /// Get an environment variable by key.
  ///
  /// - Parameters:
  ///   - member: An environment variable name.
  ///   - defaultValue: A default value if the environment variable is not set.
  @inlinable
  public static subscript(_ member: String, default defaultValue: Bool) -> Bool {
    current.variables[member]?.toBool ?? defaultValue
  }
}

extension String {
  private static let trueValues: [String] = ["true", "yes", "on", "1", "y"]

  @inline(__always)
  @usableFromInline
  var toBool: Bool { Self.trueValues.contains(lowercased()) }
}

extension Optional where Wrapped == String {
  @inline(__always)
  @usableFromInline
  var toBool: Bool {
    switch self {
    case .none: false
    case .some(let wrapped): wrapped.toBool
    }
  }
}
