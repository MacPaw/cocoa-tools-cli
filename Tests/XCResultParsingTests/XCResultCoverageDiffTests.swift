import Foundation
import Testing

@testable import XCResultParsing

#if os(macOS)
  @Suite
  struct XCResultCoverageDiffTests {
    private func diffJSONURL() throws -> URL {
      try #require(Bundle.module.resourceURL).appendingPathComponent("coverage-diff.json")
    }

    @Test("diffJSON addedTargets hasTarget3Tests")
    func test_diffJSON_addedTargets_hasTarget3Tests() throws {
      // GIVEN — pre-computed diff fixture generated with --path-equivalence
      // WHEN — decoding directly from JSON
      let data = try Data(contentsOf: diffJSONURL())
      let sut = try JSONDecoder().decode(XCResultCoverageDiff.self, from: data)

      // THEN — Target3Tests is in addedTargets with full coverage data
      let target3 = try #require(sut.addedTargets.first { $0.name == "Target3Tests" })
      #expect(target3.executableLines > 0)
    }

    @Test("diffJSON removedTargets hasTarget1Tests")
    func test_diffJSON_removedTargets_hasTarget1Tests() throws {
      // GIVEN — pre-computed diff fixture
      // WHEN — decoding from JSON
      let data = try Data(contentsOf: diffJSONURL())
      let sut = try JSONDecoder().decode(XCResultCoverageDiff.self, from: data)

      // THEN — Target1Tests is in removedTargets (name only)
      #expect(sut.removedTargets.contains { $0.name == "Target1Tests" })
    }

    @Test("diffJSON fileDeltas hasStructDPositiveDelta")
    func test_diffJSON_fileDeltas_hasStructDPositiveDelta() throws {
      // GIVEN — pre-computed diff fixture (StructD.lowercased() added in After)
      // WHEN — locating the StructD.swift file delta in Target2Tests
      let data = try Data(contentsOf: diffJSONURL())
      let sut = try JSONDecoder().decode(XCResultCoverageDiff.self, from: data)
      let target2Delta = try #require(sut.targetDeltas.first { $0.name == "Target2Tests" })
      let structDDelta = try #require(target2Delta.fileDeltas.first { $0.documentLocation.hasSuffix("StructD.swift") })

      // THEN — StructD coverage improved (positive delta) because lowercased() is now tested
      #expect(structDDelta.lineCoverageDelta.lineCoverageDelta > 0)
      #expect(
        structDDelta.functionDeltas.contains {
          $0.name.contains("lowercased") && $0.lineCoverageDelta.lineCoverageDelta > 0
        }
      )
    }

    @Test("diffJSON fileDeltas hasStructENegativeDelta")
    func test_diffJSON_fileDeltas_hasStructENegativeDelta() throws {
      // GIVEN — pre-computed diff fixture (StructE.isNegative() dropped in After)
      // WHEN — locating the StructE.swift file delta in Target2Tests
      let data = try Data(contentsOf: diffJSONURL())
      let sut = try JSONDecoder().decode(XCResultCoverageDiff.self, from: data)
      let target2Delta = try #require(sut.targetDeltas.first { $0.name == "Target2Tests" })
      let structEDelta = try #require(target2Delta.fileDeltas.first { $0.documentLocation.hasSuffix("StructE.swift") })

      // THEN — StructE coverage regressed (negative delta) because isNegative() is no longer tested
      #expect(structEDelta.lineCoverageDelta.lineCoverageDelta < 0)
      #expect(
        structEDelta.functionDeltas.contains {
          $0.name.contains("isNegative") && $0.lineCoverageDelta.lineCoverageDelta < 0
        }
      )
    }
  }
#endif
