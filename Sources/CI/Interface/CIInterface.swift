public import ENV
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

  /// Source control repository metadata for the current run.
  ///
  /// Defaults to empty metadata for CIs that cannot report it.
  var repository: CI.Repository { get }

  /// Pipeline metadata for the current run.
  ///
  /// Defaults to empty metadata for CIs that cannot report it.
  var cicd: CI.CICD { get }
}

extension CIInterface {
  /// Source control repository metadata for the current run.
  ///
  /// - Returns: Empty metadata, unless the conforming CI overrides it.
  public var repository: CI.Repository { CI.Repository() }

  /// Pipeline metadata for the current run.
  ///
  /// - Returns: Empty metadata, unless the conforming CI overrides it.
  public var cicd: CI.CICD { CI.CICD() }
}
