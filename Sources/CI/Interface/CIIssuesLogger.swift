public protocol CIIssuesLogger {
  func warning(
    _ message: @autoclosure () -> String,
    sourcePath: String?,
    lineNumber: Int?,
    columnNumber: Int?,
    code: Int?
  )

  func error(
    _ message: @autoclosure () -> String,
    sourcePath: String?,
    lineNumber: Int?,
    columnNumber: Int?,
    code: Int?
  )
}
