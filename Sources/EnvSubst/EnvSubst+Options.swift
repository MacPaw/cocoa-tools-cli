import Foundation

extension EnvSubst {
  /// Options for environment variable substitution.
  public struct Options: Sendable {
    /// Fail if a variable is not set.
    public let noUnset: Bool
    /// Fail if a variable is set but empty.
    public let noEmpty: Bool
    /// Fail at first occurrence of an error.
    public let failFast: Bool

    /// Initialize substitution options.
    ///
    /// - Parameters:
    ///   - noUnset: Fail if a variable is not set.
    ///   - noEmpty: Fail if a variable is set but empty.
    ///   - failFast: Fail at first occurrence of an error.
    public init(noUnset: Bool = false, noEmpty: Bool = false, failFast: Bool = false) {
      self.noUnset = noUnset
      self.noEmpty = noEmpty
      self.failFast = failFast
    }
  }
}

extension EnvSubst.Options {
  /// Default options.
  ///
  /// No checks for unset and empty variables. Equals to `.relaxed`. Similar to the `eval` command behavior.
  public static let `default`: Self = .relaxed

  /// Strict validation options.
  ///
  /// No unset and empty variables.
  public static let strict: Self = .init(noUnset: true, noEmpty: true)

  /// Relaxed validation options.
  ///
  ///  No checks for unset and empty variables. Similar to the `eval` command behavior.
  public static let relaxed: Self = .init(noUnset: false, noEmpty: false)
}
