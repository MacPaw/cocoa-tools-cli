import ENV
import Foundation

/// CI.
public struct CI {
  /// CI interface.
  let ci: any CIInterface

  /// CI type.
  public var type: CIType { ci.type }

  private init(env: ENV = ENV.current, supportedCIs: [any CIInterface.Type] = Self.supported) {
    let currentCI: any CIInterface =
      if let currentCIType: any CIInterface.Type = supportedCIs.first(where: { $0.validateAsCurrentCI(env) }) {
        currentCIType.init(env: env)
      }
      else { CI.Local(env: env) }
    self.ci = currentCI
  }
}

extension CI: CIInterface {
  /// Capabilities of the CI.
  public var capabilities: Capabilities { ci.capabilities }

  /// Environment variables management.
  public var env: any CIEnvInterface { ci.env }

  /// Initialize CI with environment variables.
  ///
  /// - Parameter env: Environment variables.
  public init(env: ENV = .current) { self.init(env: env, supportedCIs: Self.supported) }

  /// Validate if the current CI is supported.
  ///
  /// - Parameter environment: Environment variables.
  /// - Returns: `true` if the current CI is supported, `false` otherwise.
  public static func validateAsCurrentCI(_ environment: ENV = ENV.current) -> Bool {
    Swift.type(of: current).validateAsCurrentCI(environment)
  }
}

extension CI: Sendable {}

// MARK: - Singleton thread-safe accessors

extension CI {
  private static let lock: NSRecursiveLock = .init()

  private static let defaultSupported: [any CIInterface.Type] = [CI.AzurePipelines.self, CI.GitHubActions.self]

  private nonisolated(unsafe) static var supported: [any CIInterface.Type] = defaultSupported
  private nonisolated(unsafe) static var _current: (any CIInterface)?

  /// Get the current CI.
  ///
  /// - Returns: The current CI.
  public static var current: any CIInterface {
    lock.withLock {
      if let cached: any CIInterface = _current { return cached }
      _current = detectCurrent()
      guard let current = _current else { fatalError("Failed to detect current CI") }
      return current
    }
  }

  /// Register a new CI type.
  ///
  /// - Parameter ciType: The CI type to register.
  public static func register(_ ciType: any CIInterface.Type) {
    lock.withLock {
      supported.insert(ciType, at: 0)
      _current = nil  // Reset cache
    }
  }

  /// Reset the current CI cache.
  public static func reset() {
    lock.withLock {
      supported = defaultSupported
      _current = nil
    }
  }

  /// Detect the current CI based on environment.
  private static func detectCurrent() -> any CIInterface { CI() }
}
