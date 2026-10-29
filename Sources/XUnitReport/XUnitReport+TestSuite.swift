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

    /// Initializes a test suite.
    ///
    /// - Parameters:
    ///   - name: The name of the test suite.
    ///   - tests: Total number of test cases.
    ///   - failures: Number of test cases that failed.
    ///   - errors: Number of test cases that errored.
    ///   - skipped: Number of test cases that were skipped.
    ///   - time: Total execution time in seconds.
    ///   - testCases: The test cases within this suite.
    public init(
      name: String,
      tests: Int = 0,
      failures: Int = 0,
      errors: Int = 0,
      skipped: Int = 0,
      time: Double = 0,
      testCases: [TestCase] = [],
    ) {
      self.name = name
      self.tests = tests
      self.failures = failures
      self.errors = errors
      self.skipped = skipped
      self.time = time
      self.testCases = testCases
    }
  }
}
