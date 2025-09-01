import Foundation

/// Provides easy access to environment variables.
@dynamicMemberLookup
public struct ENV: Sendable, Equatable, Hashable {
  /// Hash of environment variables.
  @usableFromInline
  var variables: [String: String]  // internal for testing

  /// Initialize with a hash of environment variables.
  @inlinable
  public init(variables: [String: String]) { self.variables = variables }

  /// Initialize with a process info.
  ///
  /// - Parameter processInfo: Process info.
  @inlinable
  public init(processInfo: ProcessInfo) { self.init(variables: processInfo.environment) }

  /// Get an environment variable by key.
  ///
  /// - Parameter member: An environment variable name.
  @inlinable
  public subscript(dynamicMember member: String) -> String? { variables[member] }

  /// Get an environment variable by key.
  ///
  /// - Parameter member: An environment variable name.
  @inlinable
  public subscript(_ member: String) -> String? { variables[member] }

  /// Get an environment variable by key.
  ///
  /// - Parameters:
  ///   - member: An environment variable name.
  ///   - defaultValue: A default value if the environment variable is not set.
  @inlinable
  public subscript(_ member: String, default defaultValue: String) -> String {
    variables[member, default: defaultValue]
  }
}

extension ENV {
  /// Get an environment variable by key.
  ///
  /// - Parameter member: An environment variable name.
  @inlinable
  public static subscript(dynamicMember member: String) -> String? { current.variables[member] }

  /// Get an environment variable by key.
  ///
  /// - Parameter member: An environment variable name.
  @inlinable
  public static subscript(_ member: String) -> String? { current.variables[member] }

  /// Get an environment variable by key.
  ///
  /// - Parameters:
  ///   - member: An environment variable name.
  ///   - defaultValue: A default value if the environment variable is not set.
  @inlinable
  public static subscript(_ member: String, default defaultValue: String) -> String {
    current.variables[member, default: defaultValue]
  }
}

extension ENV {
  /// Current environment variables from the process.
  public static let current: Self = .init(processInfo: ProcessInfo.processInfo)
}
