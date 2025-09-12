/// Protocol for logging CI issues with warnings and errors.
public protocol CIIssuesLogger {
  /// Log a warning message.
  ///
  /// - Parameters:
  ///   - message: The warning message.
  ///   - sourcePath: Optional source file path.
  ///   - lineNumber: Optional line number.
  ///   - columnNumber: Optional column number.
  ///   - code: Optional error code.
  func warning(
    _ message: @autoclosure () -> String,
    sourcePath: String?,
    lineNumber: Int?,
    columnNumber: Int?,
    code: Int?
  )

  /// Log an error message.
  ///
  /// - Parameters:
  ///   - message: The error message.
  ///   - sourcePath: Optional source file path.
  ///   - lineNumber: Optional line number.
  ///   - columnNumber: Optional column number.
  ///   - code: Optional error code.
  func error(
    _ message: @autoclosure () -> String,
    sourcePath: String?,
    lineNumber: Int?,
    columnNumber: Int?,
    code: Int?
  )
}
