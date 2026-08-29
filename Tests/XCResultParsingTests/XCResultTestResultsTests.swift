import Foundation
import Testing

@testable import XCResultParsing

#if os(macOS)
  @Suite
  struct XCResultTestResultsTests {
    private var xcresultURL: URL {
      Bundle.module.resourceURL!.appendingPathComponent("test-package.xcresult")
    }

    @Test("load returnsDecodableTestResults")
    func test_load_returnsDecodableTestResults() throws {
      // GIVEN — path to fixture xcresult
      // WHEN — loading test results via xcresulttool get test-results tests
      let sut = try XCResultTestResults.load(from: xcresultURL)

      // THEN — at least one device and one test group present
      #expect(!sut.devices.isEmpty)
      #expect(!sut.testNodes.isEmpty)
    }
  }
#endif
