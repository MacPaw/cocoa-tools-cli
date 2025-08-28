import ENV
import Foundation

/// CI.
public struct CI {
  /// CI interface.
  let ci: CIInterface

  /// CI type.
  public var type: CIType { ci.type }

  private init(env: ENV = ENV.current, supportedCIs: [CIInterface.Type] = Self.supportedCIs) {
    let currentCI: CIInterface =
      if let currentCIType: any CIInterface.Type = supportedCIs.first(where: { $0.validateAsCurrentCI(env) }) {
        currentCIType.init(env: env)
      }
      else { CI.Local(env: env) }
    self.ci = currentCI
  }
}

extension CI: CIInterface {
  public init(env: ENV) { self.init(env: env, supportedCIs: Self.supportedCIs) }

  /// Validate if the current CI is supported.
  ///
  /// - Parameter environment: Environment variables.
  public static func validateAsCurrentCI(_ environment: ENV = ENV.current) -> Bool {
    Swift.type(of: current).validateAsCurrentCI(environment)
  }
}

extension CI: Sendable {}

// MARK: - Singleton thread-safe accessors

extension CI {
  private static let lock: NSRecursiveLock = .init()

  private static let defaultSupportedCIs: [CIInterface.Type] = [CI.AzurePipelines.self, CI.GitHubActions.self]

  private nonisolated(unsafe) static var supportedCIs: [CIInterface.Type] = defaultSupportedCIs
  private nonisolated(unsafe) static var _current: CIInterface?

  /// Get the current CI.
  ///
  /// - Returns: The current CI.
  public static var current: CIInterface {
    lock.withLock {
      if let cached: any CIInterface = _current { return cached }
      _current = detectCurrent()
      return _current!
    }
  }

  /// Register a new CI type.
  ///
  /// - Parameter ciType: The CI type to register.
  public static func register(_ ciType: CIInterface.Type) {
    lock.withLock {
      supportedCIs.insert(ciType, at: 0)
      _current = nil  // Reset cache
    }
  }

  /// Reset the current CI cache.
  public static func reset() {
    lock.withLock {
      supportedCIs = defaultSupportedCIs
      _current = nil
    }
  }

  /// Detect the current CI based on environment.
  private static func detectCurrent() -> CIInterface { CI() }
}
