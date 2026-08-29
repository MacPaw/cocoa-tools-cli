extension XUnitReport {
  /// A single `<testsuite>` element within an xUnit report.
  public struct TestSuite: Sendable {
    /// The name of the test suite.
    public let name: String
    /// Total number of test cases.
    public let tests: Int
    /// Number of test cases that failed.
    public let failures: Int
    /// Number of test cases that errored.
    public let errors: Int
    /// Number of test cases that were skipped.
    public let skipped: Int
    /// Total execution time in seconds.
    public let time: Double
    /// The test cases within this suite.
    public let testCases: [TestCase]
  }
}
