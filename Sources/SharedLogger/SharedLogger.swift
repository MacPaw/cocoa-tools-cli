@_exported public import Logging

extension Logger {
  /// Shared instance of the Logger.
  @usableFromInline
  nonisolated(unsafe) internal private(set) static var shared: Self = {
    var logger = Logger(label: "")
    logger.logLevel = .info
    return logger
  }()

  /// Sets the log level of the shared `log` instance.
  ///
  /// - Parameter logLevel: A new log level.
  @MainActor
  public static func setLogLevel(_ logLevel: Logger.Level) { shared.logLevel = logLevel }
}

/// Shared logger instance.
@inlinable
@inline(__always)
public var log: Logger { .shared }
