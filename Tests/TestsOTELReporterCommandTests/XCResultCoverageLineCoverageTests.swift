#if os(macOS)
  import Foundation
  import Testing
  import TestsOTELReporter
  import XCResultParsing

  @testable import TestsOTELReporterCommand

  @Suite
  struct XCResultCoverageLineCoverageTests {
    /// Decodes `xccov` coverage holding an app target and a test bundle.
    ///
    /// - Returns: The decoded coverage.
    /// - Throws: An error if the JSON cannot be decoded.
    private func makeCoverage() throws -> XCResultCoverage {
      let json = """
        {"coveredLines":12,"executableLines":20,"lineCoverage":0.6,"targets":[
        {"name":"Core","buildProductPath":"/D/Products/Debug/Core.framework/Core","coveredLines":2,"executableLines":10,"lineCoverage":0.2,"files":[]},
        {"name":"CoreTests","buildProductPath":"/D/Products/Debug/CoreTests.xctest/Contents/MacOS/CoreTests","coveredLines":10,"executableLines":10,"lineCoverage":1,"files":[]}
        ]}
        """
      return try JSONDecoder().decode(XCResultCoverage.self, from: Data(json.utf8))
    }

    @Test("init dropsTestBundlesByDefault")
    func test_init_dropsTestBundlesByDefault() throws {
      // GIVEN
      let xcresultCoverage = try makeCoverage()

      // WHEN
      let sut = LineCoverage(xcresultCoverage: xcresultCoverage, includeTestTargets: false)

      // THEN
      #expect(sut.targets == [LineCoverage.Target(name: "Core", coveredLines: 2, executableLines: 10)])
    }

    @Test("init keepsTestBundlesWhenIncluded")
    func test_init_keepsTestBundlesWhenIncluded() throws {
      // GIVEN
      let xcresultCoverage = try makeCoverage()

      // WHEN
      let sut = LineCoverage(xcresultCoverage: xcresultCoverage, includeTestTargets: true)

      // THEN
      #expect(sut.targets.map(\.name) == ["Core", "CoreTests"])
    }
  }
#endif
