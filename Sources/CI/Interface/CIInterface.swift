import ENV

/// CI interface.
public protocol CIInterface: Sendable {
  /// Type of the CI.
  var type: CIType { get }

  /// Validate if the current CI is supported.
  ///
  /// - Parameters:
  ///   - environment: Environment variables.
  ///
  /// - Returns: `true` if the current CI is supported, `false` otherwise.
  static func validateAsCurrentCI(_ environment: ENV) -> Bool

  init(env: ENV)
}
