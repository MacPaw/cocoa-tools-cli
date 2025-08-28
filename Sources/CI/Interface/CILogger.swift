public protocol CILogger {
  func debug(_ message: @autoclosure () -> String, )

  func warning(_ message: @autoclosure () -> String, )

  func error(_ message: @autoclosure () -> String, )

  func startGroup(_ title: String)

  func endGroup()
}
