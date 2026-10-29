extension XUnitReport.TestSuite.TestCase {
  /// A `<failure>` child element of a ``TestCase``.
  public struct Failure: Sendable {
    /// The failure message attribute.
    public let message: String
    /// The failure type attribute (for example `"Issue"`).
    public let type: String
    /// The text body of the `<failure>` element (stack trace or extended description), if any.
    public let body: String?

    /// Initializes a test case failure.
    ///
    /// - Parameters:
    ///   - message: The failure message attribute.
    ///   - type: The failure type attribute (for example `"Issue"`).
    ///   - body: The text body of the `<failure>` element (stack trace or extended description), if any.
    public init(
      message: String = "",
      type: String = "",
      body: String? = nil,
    ) {
      self.message = message
      self.type = type
      self.body = body
    }
  }
}
