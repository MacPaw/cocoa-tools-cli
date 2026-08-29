extension XCResultTestResults {
  /// A node in the hierarchical test result tree (suite, test case, or assertion).
  public struct TestNode: Codable, Sendable {
    /// Display name of this node.
    public var name: String
    /// The kind of this node (e.g. `"Test Suite"`, `"Test Case"`).
    public var nodeType: String
    /// The pass/fail status (e.g. `"Passed"`, `"Failed"`).
    public var result: String
    /// Human-readable duration string.
    public var duration: String?
    /// Duration in seconds as a floating-point value.
    public var durationInSeconds: Double?
    /// Stable test identifier used to address a specific test case.
    public var nodeIdentifier: String?
    /// URL-encoded variant of `nodeIdentifier`.
    public var nodeIdentifierURL: String?
    /// Child nodes (sub-suites or individual test cases).
    public var children: [TestNode]?
  }
}
