extension Collection where Element == TestRun.Suite.TestCase {
  /// The `test.suite.run.status` of these test cases, taken as a suite or as a whole run.
  ///
  /// A report cannot distinguish a timeout or an abort from a failure, so those collapse into
  /// `failure`. A group where nothing ran counts as `skipped`.
  var runStatus: String {
    if contains(where: { $0.status == .fail }) { return SemanticConventions.SuiteRunStatus.failure }
    if allSatisfy({ $0.status == .skip }) { return SemanticConventions.SuiteRunStatus.skipped }
    return SemanticConventions.SuiteRunStatus.success
  }
}
