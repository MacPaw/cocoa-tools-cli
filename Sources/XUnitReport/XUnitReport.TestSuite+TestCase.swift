extension XUnitReport.TestSuite {
  /// A single `<testcase>` element within a ``TestSuite``.
  public struct TestCase: Sendable {
    /// The fully-qualified class name in `ModuleName.SuiteName` format.
    public let className: String
    /// The test method name.
    public let name: String
    /// Execution time in seconds.
    public let time: Double
    /// Failure details, or `nil` if the test passed or was skipped.
    public let failure: Failure?
    /// `true` when a `<skipped/>` child element was present.
    public let isSkipped: Bool

    /// The module component of ``className`` (the part before the first `.`).
    public var moduleName: String {
      guard let dotIndex = className.firstIndex(of: ".") else { return className }
      return String(className[..<dotIndex])
    }

    /// The suite component of ``className`` (the part after the first `.`).
    public var suiteName: String {
      guard let dotIndex = className.firstIndex(of: ".") else { return className }
      return String(className[className.index(after: dotIndex)...])
    }
  }
}
