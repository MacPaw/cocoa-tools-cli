extension XUnitReport.TestSuite.TestCase {
  /// A `<failure>` child element of a ``TestCase``.
  public struct Failure: Sendable {
    /// The failure message attribute.
    public let message: String
    /// The failure type attribute (e.g. `"Issue"`).
    public let type: String
    /// The text body of the `<failure>` element (stack trace or extended description), if any.
    public let body: String?
  }
}
