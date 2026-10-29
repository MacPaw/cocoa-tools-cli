import Foundation
import TestsOTELReporter
import XUnitReport

extension TestRun {
  /// Creates a test run from a parsed xUnit report.
  ///
  /// Test cases are grouped by their `className` rather than by the enclosing `<testsuite>`
  /// element: `swift test --xunit-output` emits every case under a single synthetic suite, so the
  /// class name is the only per-suite dimension the report actually carries.
  ///
  /// - Parameter report: The parsed xUnit report.
  init(report: XUnitReport) {
    let allCases: [XUnitReport.TestSuite.TestCase] = report.testSuites.flatMap(\.testCases)

    var suiteNames: [String] = []
    var casesBySuite: [String: [Suite.TestCase]] = [:]

    for testCase in allCases {
      if casesBySuite[testCase.className] == nil { suiteNames.append(testCase.className) }
      casesBySuite[testCase.className, default: []].append(Suite.TestCase(testCase: testCase))
    }

    self.init(
      suites: suiteNames.map { Suite(name: $0, testCases: casesBySuite[$0] ?? []) },
      duration: report.testSuites.reduce(0) { $0 + $1.time },
    )
  }
}

extension TestRun.Suite.TestCase {
  /// Creates a test case from a parsed xUnit test case.
  ///
  /// - Parameter testCase: The parsed xUnit test case.
  fileprivate init(testCase: XUnitReport.TestSuite.TestCase) {
    let status: Status =
      if testCase.isSkipped { .skip }
      else if testCase.failure != nil { .fail }
      else { .pass }

    self.init(
      name: testCase.name,
      status: status,
      duration: testCase.time,
      failureMessage: testCase.failure.flatMap(Self.failureMessage(of:)),
    )
  }

  /// Joins the message attribute and text body of a failure.
  ///
  /// Producers put the reason in either — or the summary in the attribute and the stack trace in
  /// the body — so both are kept.
  ///
  /// - Parameter failure: The parsed failure.
  /// - Returns: The non-empty parts, one per line, or `nil` when both are empty.
  private static func failureMessage(of failure: XUnitReport.TestSuite.TestCase.Failure) -> String? {
    let parts: [String] = [failure.message, failure.body ?? ""].filter { !$0.isEmpty }
    return parts.isEmpty ? .none : parts.joined(separator: "\n")
  }
}
