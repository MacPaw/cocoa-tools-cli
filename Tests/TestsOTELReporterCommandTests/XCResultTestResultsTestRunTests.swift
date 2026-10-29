#if os(macOS)
  import Foundation
  import Testing
  import TestsOTELReporter
  import XCResultParsing

  @testable import TestsOTELReporterCommand

  @Suite
  struct XCResultTestResultsTestRunTests {
    /// Decodes test results from the JSON shape `xcresulttool get test-results tests` emits.
    ///
    /// Decoding rather than constructing values keeps the fixture in the wire format the parser
    /// actually consumes, including the `nodeType` and `result` spellings Xcode uses.
    ///
    /// - Parameter json: The raw JSON.
    /// - Returns: The decoded results.
    /// - Throws: An error if the JSON does not decode.
    private func testResults(json: String) throws -> XCResultTestResults {
      try JSONDecoder().decode(XCResultTestResults.self, from: Data(json.utf8))
    }

    /// A test plan containing one bundle, one suite of two cases, and a bare case in the bundle.
    private static let nestedJSON: String = """
      {
        "devices": [],
        "testNodes": [{
          "name": "TestPlan",
          "nodeType": "Test Plan",
          "result": "Failed",
          "children": [{
            "name": "TargetATests",
            "nodeType": "Unit test bundle",
            "result": "Failed",
            "children": [
              {
                "name": "GreeterTests",
                "nodeType": "Test Suite",
                "result": "Failed",
                "children": [
                  {
                    "name": "greets()",
                    "nodeType": "Test Case",
                    "result": "Passed",
                    "durationInSeconds": 0.25
                  },
                  {
                    "name": "shouts()",
                    "nodeType": "Test Case",
                    "result": "Failed",
                    "durationInSeconds": 0.5
                  }
                ]
              },
              {
                "name": "looseCase()",
                "nodeType": "Test Case",
                "result": "Skipped"
              }
            ]
          }]
        }]
      }
      """

    @Test("init attributesCasesToNearestEnclosingSuite")
    func test_init_attributesCasesToNearestEnclosingSuite() throws {
      // GIVEN — cases nested under a suite inside a bundle inside a test plan
      let testResults = try testResults(json: Self.nestedJSON)

      // WHEN
      let sut = TestRun(testResults: testResults)

      // THEN — suite-nested cases land under the suite, not the bundle or the plan
      let suite = try #require(sut.suites.first { $0.name == "GreeterTests" })
      #expect(suite.testCases.map(\.name) == ["greets()", "shouts()"])
    }

    @Test("init fallsBackToBundleForCasesOutsideASuite")
    func test_init_fallsBackToBundleForCasesOutsideASuite() throws {
      // GIVEN — a case sitting directly in the bundle, with no enclosing suite
      let testResults = try testResults(json: Self.nestedJSON)

      // WHEN
      let sut = TestRun(testResults: testResults)

      // THEN — it is attributed to the bundle rather than dropped
      let suite = try #require(sut.suites.first { $0.name == "TargetATests" })
      #expect(suite.testCases.map(\.name) == ["looseCase()"])
    }

    @Test("init mapsResultStringsToStatus")
    func test_init_mapsResultStringsToStatus() throws {
      // GIVEN — the result spellings xcresulttool emits, including an expected failure
      let testResults = try testResults(
        json: """
          {
            "devices": [],
            "testNodes": [{
              "name": "Suite",
              "nodeType": "Test Suite",
              "children": [
                {"name": "a()", "nodeType": "Test Case", "result": "Passed"},
                {"name": "b()", "nodeType": "Test Case", "result": "Failed"},
                {"name": "c()", "nodeType": "Test Case", "result": "Skipped"},
                {"name": "d()", "nodeType": "Test Case", "result": "Expected Failure"},
                {"name": "e()", "nodeType": "Test Case"}
              ]
            }]
          }
          """
      )

      // WHEN
      let sut = TestRun(testResults: testResults)

      // THEN — an expected failure passed, and a case with no result never ran
      #expect(sut.testCases.map(\.status) == [.pass, .fail, .skip, .pass, .skip])
    }

    @Test("init carriesFailureMessagesOfFailedCases")
    func test_init_carriesFailureMessagesOfFailedCases() throws {
      // GIVEN — a failing case with two failure messages, and a passing one with none
      let testResults = try testResults(
        json: """
          {
            "devices": [],
            "testNodes": [{
              "name": "Suite",
              "nodeType": "Test Suite",
              "children": [
                {"name": "a()", "nodeType": "Test Case", "result": "Passed"},
                {
                  "name": "b()",
                  "nodeType": "Test Case",
                  "result": "Failed",
                  "children": [
                    {"name": "Greeter.swift:12: XCTAssertEqual failed", "nodeType": "Failure Message", "result": "Failed"},
                    {"name": "Greeter.swift:14: XCTAssertTrue failed", "nodeType": "Failure Message", "result": "Failed"}
                  ]
                }
              ]
            }]
          }
          """
      )

      // WHEN
      let sut = TestRun(testResults: testResults)

      // THEN — the failing case lists its messages one per line, the passing one has none
      #expect(
        sut.testCases.map(\.failureMessage) == [
          nil, "Greeter.swift:12: XCTAssertEqual failed\nGreeter.swift:14: XCTAssertTrue failed",
        ]
      )
    }

    @Test("init sumsCaseDurationsForRunDuration")
    func test_init_sumsCaseDurationsForRunDuration() throws {
      // GIVEN — results carrying per-case durations but no run-level total
      let testResults = try testResults(json: Self.nestedJSON)

      // WHEN
      let sut = TestRun(testResults: testResults)

      // THEN — cases without a duration count as zero rather than dropping the run total
      #expect(sut.duration == 0.75)
      #expect(sut.testCases.count == 3)
    }

    @Test("init ignoresNonTestNodeTypes")
    func test_init_ignoresNonTestNodeTypes() throws {
      // GIVEN — a skip message child, which xcresulttool nests inside a skipped case
      let testResults = try testResults(
        json: """
          {
            "devices": [],
            "testNodes": [{
              "name": "Suite",
              "nodeType": "Test Suite",
              "children": [{
                "name": "skipped()",
                "nodeType": "Test Case",
                "result": "Skipped",
                "children": [{"name": "Test skipped", "nodeType": "Skip Message"}]
              }]
            }]
          }
          """
      )

      // WHEN
      let sut = TestRun(testResults: testResults)

      // THEN — the message does not become a test case of its own
      #expect(sut.testCases.map(\.name) == ["skipped()"])
    }
  }
#endif
