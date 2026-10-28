#if os(macOS)
  import Foundation
  import TestsOTELReporter
  import XCResultParsing

  /// `nodeType` values emitted by `xcresulttool get test-results tests`.
  private enum NodeType {
    /// A single executed test case.
    static let testCase: String = "Test Case"
    /// A group of test cases.
    static let testSuite: String = "Test Suite"
    /// A test bundle, which encloses suites and occasionally bare test cases.
    static let unitTestBundle: String = "Unit test bundle"
    /// The reason a test case failed, nested under the failing case.
    static let failureMessage: String = "Failure Message"
  }

  extension TestRun {
    /// Creates a test run from parsed `.xcresult` test results.
    ///
    /// The result tree nests test cases under suites, bundles, and a test plan at varying depths,
    /// so cases are attributed to their nearest enclosing suite — falling back to the enclosing
    /// bundle for cases that are not inside one.
    ///
    /// - Parameter testResults: The parsed test results.
    init(testResults: XCResultTestResults) {
      var suiteNames: [String] = []
      var casesBySuite: [String: [Suite.TestCase]] = [:]

      func visit(_ node: XCResultTestResults.TestNode, suiteName: String?) {
        switch node.nodeType {
        case NodeType.testCase:
          let name = suiteName ?? node.name
          if casesBySuite[name] == nil { suiteNames.append(name) }
          casesBySuite[name, default: []].append(Suite.TestCase(node: node))

        case NodeType.testSuite, NodeType.unitTestBundle:
          for child in node.children ?? [] { visit(child, suiteName: node.name) }

        default:
          for child in node.children ?? [] { visit(child, suiteName: suiteName) }
        }
      }

      for node in testResults.testNodes { visit(node, suiteName: .none) }

      let suites: [Suite] = suiteNames.map { Suite(name: $0, testCases: casesBySuite[$0] ?? []) }

      self.init(
        suites: suites,
        duration: suites.flatMap(\.testCases).reduce(0) { $0 + $1.duration },
      )
    }
  }

  extension TestRun.Suite.TestCase {
    /// Creates a test case from a `Test Case` result node.
    ///
    /// - Parameter node: The result node.
    fileprivate init(node: XCResultTestResults.TestNode) {
      self.init(
        name: node.name,
        status: Status(result: node.result),
        duration: node.durationInSeconds ?? 0,
        failureMessage: Self.failureMessage(of: node),
      )
    }
  }

  extension TestRun.Suite.TestCase {
    /// Joins the `Failure Message` children of a `Test Case` node.
    ///
    /// - Parameter node: The result node.
    /// - Returns: The failure messages, one per line, or `nil` when the case has none.
    fileprivate static func failureMessage(of node: XCResultTestResults.TestNode) -> String? {
      let messages: [String] = (node.children ?? [])
        .filter { $0.nodeType == NodeType.failureMessage }
        .map(\.name)

      return messages.isEmpty ? .none : messages.joined(separator: "\n")
    }
  }

  extension TestRun.Suite.TestCase.Status {
    /// Maps an `xcresulttool` result string onto a test case status.
    ///
    /// An expected failure counts as a pass: the test asserted that something fails and it did.
    /// An absent result means the case never ran, which is a skip.
    ///
    /// - Parameter result: The `result` field of a `Test Case` node.
    fileprivate init(result: String?) {
      switch result {
      case "Passed", "Expected Failure": self = .pass
      case "Failed": self = .fail
      default: self = .skip
      }
    }
  }
#endif
