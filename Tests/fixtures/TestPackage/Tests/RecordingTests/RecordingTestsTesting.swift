import Foundation
import Testing

// Run only when MPCT_TESTS_RECORD_FAILURES=1.
// These tests intentionally produce failures, errors, and skips so that
// `mise tasks run fixtures:generate` can capture a real xUnit fixture
// containing all element types for XUnitReportTests.
//
// Note: withKnownIssue { ... } does NOT produce a <failure> element in xUnit output —
// Swift Testing marks the test as passed because the issue was expected. Only unexpected
// failures (bare #expect / throw) appear as <failure> in the xUnit XML.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["MPCT_TESTS_RECORD_FAILURES"] == "1"))
struct RecordingTestsTesting {
  struct RecordingError: Error {}

  @Test("expectFalse")
  func test_expectFalse() {
    #expect(Bool(false))
  }

  @Test("throwError")
  func test_throwError() throws {
    throw RecordingError()
  }

  @Test("intentionalSkip", .disabled("intentional skip for xUnit fixture generation"))
  func test_intentionalSkip() {
  }
}
