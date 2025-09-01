/// Protocol for CI logging functionality.
public protocol CILogger {
  /// Log a debug message.
  ///
  /// - Parameter message: The debug message.
  func debug(_ message: @autoclosure () -> String)

  /// Log a warning message.
  ///
  /// - Parameter message: The warning message.
  func warning(_ message: @autoclosure () -> String)

  /// Log an error message.
  ///
  /// - Parameter message: The error message.
  func error(_ message: @autoclosure () -> String)

  /// Start a log group.
  ///
  /// - Parameter title: The group title.
  func startGroup(_ title: String)

  /// End the current log group.
  func endGroup()
}
