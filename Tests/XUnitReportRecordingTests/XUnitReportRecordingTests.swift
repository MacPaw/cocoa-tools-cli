import Foundation
import Testing

// Run only when MPCT_TESTS_RECORD_FAILURES=1.
// These tests intentionally produce failures, errors, and skips so that
// `mise tasks run test:swift:record-fixtures` can capture a real xUnit fixture
// containing all element types for XUnitReportTests.
//
// Note: withKnownIssue { ... } does NOT produce a <failure> element in xUnit output —
// Swift Testing marks the test as passed because the issue was expected. Only unexpected
// failures (bare #expect / throw) appear as <failure> in the xUnit XML.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["MPCT_TESTS_RECORD_FAILURES"] == "1"))
struct RecordingTests {
  struct RecordingError: Error {}

  @Test("expectFalse")
  func test_expectFalse() {
    // GIVEN
    // WHEN — bare assertion failure
    // THEN — unexpected failure recorded in xUnit output
    #expect(Bool(false))
  }

  @Test("throwError")
  func test_throwError() throws {
    // GIVEN
    // WHEN — bare thrown error
    // THEN — unexpected thrown-error failure recorded in xUnit output
    throw RecordingError()
  }

  @Test("intentionalSkip", .disabled("intentional skip for xUnit fixture generation"))
  func test_intentionalSkip() {
    // GIVEN
    // WHEN — test is disabled
    // THEN — skipped entry recorded in xUnit output
  }
}
