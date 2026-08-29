import Foundation
import Testing

// Run only when MPCT_TESTS_RECORD_FAILURES=1.
// These tests intentionally produce failures, errors, and skips so that
// `mise tasks run test:swift:record-failures` can capture a real xUnit fixture
// containing all element types for XUnitParserTests.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["MPCT_TESTS_RECORD_FAILURES"] == "1"))
struct RecordingTests {
  struct RecordingError: Error {}

  @Test("withKnownIssue expectFalse")
  func test_withKnownIssue_expectFalse() {
    // GIVEN
    // WHEN — assertion failure wrapped in withKnownIssue
    // THEN — expected failure recorded in xUnit output
    withKnownIssue { #expect(Bool(false)) }
  }

  @Test("expectFalse")
  func test_expectFalse() {
    // GIVEN
    // WHEN — bare assertion failure
    // THEN — unexpected failure recorded in xUnit output
    #expect(Bool(false))
  }

  @Test("withKnownIssue throwError")
  func test_withKnownIssue_throwError() {
    // GIVEN
    // WHEN — thrown error wrapped in withKnownIssue
    // THEN — expected thrown-error failure recorded in xUnit output
    withKnownIssue { throw RecordingError() }
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
