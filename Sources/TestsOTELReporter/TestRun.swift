public import Foundation

/// A completed test run, independent of the report format it was parsed from.
///
/// Both `.xcresult` bundles and xUnit XML reports are normalized into this model before any
/// OpenTelemetry metrics are derived, so the reporter never depends on a particular parser.
public struct TestRun {
  /// The test suites that ran.
  public var suites: [Suite]
  /// Total wall-clock duration of the run, in seconds.
  public var duration: TimeInterval

  /// Initializes a test run.
  ///
  /// - Parameters:
  ///   - suites: The test suites that ran.
  ///   - duration: Total wall-clock duration of the run, in seconds.
  public init(suites: [Suite], duration: TimeInterval) {
    self.suites = suites
    self.duration = duration
  }

  /// Every test case across every suite, in suite order.
  public var testCases: [Suite.TestCase] { suites.flatMap(\.testCases) }
}

extension TestRun {
  /// A group of test cases sharing a suite name.
  public struct Suite {
    /// Name of the suite.
    public var name: String
    /// The test cases belonging to this suite.
    public var testCases: [TestCase]

    /// Initializes a suite.
    ///
    /// - Parameters:
    ///   - name: Name of the suite.
    ///   - testCases: The test cases belonging to this suite.
    public init(name: String, testCases: [TestCase]) {
      self.name = name
      self.testCases = testCases
    }
  }
}

extension TestRun.Suite {
  /// A single executed test case.
  public struct TestCase {
    /// Name of the test case.
    public var name: String
    /// Outcome of the test case.
    public var status: Status
    /// Execution duration of the test case, in seconds.
    public var duration: TimeInterval
    /// Why the test case failed, when the report carries a reason.
    public var failureMessage: String?

    /// Initializes a test case.
    ///
    /// - Parameters:
    ///   - name: Name of the test case.
    ///   - status: Outcome of the test case.
    ///   - duration: Execution duration of the test case, in seconds.
    ///   - failureMessage: Why the test case failed, when the report carries a reason.
    public init(name: String, status: Status, duration: TimeInterval, failureMessage: String? = .none) {
      self.name = name
      self.status = status
      self.duration = duration
      self.failureMessage = failureMessage
    }
  }
}

extension TestRun.Suite.TestCase {
  /// Outcome of a test case.
  ///
  /// Mirrors the OpenTelemetry `test.case.result.status` attribute. The registry defines only
  /// `pass` and `fail`; ``skip`` is a MacPaw extension, since a skipped test is neither and
  /// collapsing it into either one misreports the suite.
  public enum Status: String, CaseIterable {
    /// The test case passed.
    case pass
    /// The test case failed or errored.
    case fail
    /// The test case was skipped.
    case skip
  }
}

extension TestRun: Sendable {}
extension TestRun: Equatable {}
extension TestRun.Suite: Sendable {}
extension TestRun.Suite: Equatable {}
extension TestRun.Suite.TestCase: Sendable {}
extension TestRun.Suite.TestCase: Equatable {}
extension TestRun.Suite.TestCase.Status: Sendable {}
