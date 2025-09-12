import ENV
import Foundation

/// CI interface.
public protocol CIInterface: Sendable {
  /// Type of the CI.
  var type: CIType { get }

  /// Capabilities of the CI.
  var capabilities: CI.Capabilities { get }

  /// Validate if the current CI is supported.
  ///
  /// - Parameter environment: Environment variables.
  /// - Returns: `true` if the current CI is supported, `false` otherwise.
  static func validateAsCurrentCI(_ environment: ENV) -> Bool

  /// Initialize with environment variables.
  ///
  /// - Parameter env: Environment variables.
  init(env: ENV)

  /// Environment variables management.
  var env: any CIEnvInterface { get }
}
