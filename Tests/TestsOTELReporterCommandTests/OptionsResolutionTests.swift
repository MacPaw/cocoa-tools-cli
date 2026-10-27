import ArgumentParser
import Foundation
import Testing

@testable import TestsOTELReporterCommand

@Suite
struct OptionsResolutionTests {
  /// Parses options the way the CLI does, so tests exercise the real argument declarations.
  ///
  /// - Parameter arguments: Command-line arguments, without the command name.
  /// - Returns: The parsed options.
  /// - Throws: An error if the arguments do not parse.
  func makeSUT(_ arguments: [String] = []) throws -> Options {
    try Options.parse(arguments)
  }

  // MARK: - Endpoint

  @Test("resolvedEndpoint prefersFlagOverEnvironment")
  func test_resolvedEndpoint_prefersFlagOverEnvironment() throws {
    // GIVEN — both the flag and the environment variable are set
    let sut = try makeSUT(["--endpoint", "https://flag.example"])

    // WHEN
    let endpoint = try sut.resolvedEndpoint(environment: ["OTEL_EXPORTER_OTLP_ENDPOINT": "https://env.example"])

    // THEN
    #expect(endpoint.absoluteString == "https://flag.example")
  }

  @Test("resolvedEndpoint fallsBackToEnvironment")
  func test_resolvedEndpoint_fallsBackToEnvironment() throws {
    // GIVEN — only the environment variable is set
    let sut = try makeSUT()

    // WHEN
    let endpoint = try sut.resolvedEndpoint(environment: ["OTEL_EXPORTER_OTLP_ENDPOINT": "https://env.example"])

    // THEN
    #expect(endpoint.absoluteString == "https://env.example")
  }

  @Test("resolvedEndpoint throwsWhenUnset")
  func test_resolvedEndpoint_throwsWhenUnset() throws {
    // GIVEN — neither the flag nor the environment supplies an endpoint
    let sut = try makeSUT()

    // WHEN / THEN — no silent default: telemetry with nowhere to go is a configuration error
    #expect(throws: ValidationError.self) { try sut.resolvedEndpoint(environment: [:]) }
  }

  @Test("resolvedEndpoint treatsEmptyEnvironmentValueAsUnset")
  func test_resolvedEndpoint_treatsEmptyEnvironmentValueAsUnset() throws {
    // GIVEN — CI systems routinely export declared-but-empty variables
    let sut = try makeSUT()

    // WHEN / THEN
    #expect(throws: ValidationError.self) {
      try sut.resolvedEndpoint(environment: ["OTEL_EXPORTER_OTLP_ENDPOINT": ""])
    }
  }

  @Test("resolvedEndpoint throwsForValueWithoutScheme")
  func test_resolvedEndpoint_throwsForValueWithoutScheme() throws {
    // GIVEN — a host pasted without a scheme, which URL(string:) happily reads as a scheme itself
    let sut = try makeSUT(["--endpoint", "collector.example:4318"])

    // WHEN / THEN
    #expect(throws: ValidationError.self) { try sut.resolvedEndpoint(environment: [:]) }
  }

  // MARK: - Headers

  @Test("resolvedHeaders readsEnvironmentHeaders")
  func test_resolvedHeaders_readsEnvironmentHeaders() throws {
    // GIVEN — headers supplied only through the environment
    let sut = try makeSUT()

    // WHEN
    let headers = try sut.resolvedHeaders(environment: ["OTEL_EXPORTER_OTLP_HEADERS": "api-key=secret"])

    // THEN
    #expect(headers == ["api-key": "secret"])
  }

  @Test("resolvedHeaders mergesFlagsOverEnvironment")
  func test_resolvedHeaders_mergesFlagsOverEnvironment() throws {
    // GIVEN — a flag overriding one environment header while another is left alone
    let sut = try makeSUT(["--header", "api-key=from-flag"])

    // WHEN
    let headers = try sut.resolvedHeaders(
      environment: ["OTEL_EXPORTER_OTLP_HEADERS": "api-key=from-env,x-scope-orgid=macpaw"]
    )

    // THEN — overriding one header does not require restating the rest
    #expect(headers == ["api-key": "from-flag", "x-scope-orgid": "macpaw"])
  }

  @Test("resolvedHeaders acceptsRepeatedFlags")
  func test_resolvedHeaders_acceptsRepeatedFlags() throws {
    // GIVEN — the flag given twice
    let sut = try makeSUT(["--header", "a=1", "--header", "b=2"])

    // WHEN
    let headers = try sut.resolvedHeaders(environment: [:])

    // THEN
    #expect(headers == ["a": "1", "b": "2"])
  }

  @Test("resolvedHeaders throwsForFlagWithoutSeparator")
  func test_resolvedHeaders_throwsForFlagWithoutSeparator() throws {
    // GIVEN — a malformed flag value
    let sut = try makeSUT(["--header", "garbage"])

    // WHEN / THEN — unlike the environment, an explicit flag is worth failing on
    #expect(throws: ValidationError.self) { try sut.resolvedHeaders(environment: [:]) }
  }

  // MARK: - Timestamp

  @Test("resolvedTimestamp prefersFlagInMilliseconds")
  func test_resolvedTimestamp_prefersFlagInMilliseconds() throws {
    // GIVEN — an explicit millisecond timestamp
    let sut = try makeSUT(["--timestamp", "1700000000500"])

    // WHEN
    let timestamp = sut.resolvedTimestamp(
      environment: ["BUILD_FINISHTIME": "2020-01-01T00:00:00.0000000Z"],
      now: Date(timeIntervalSince1970: 0),
    )

    // THEN
    #expect(timestamp == Date(timeIntervalSince1970: 1_700_000_000.5))
  }

  @Test("resolvedTimestamp fallsBackToBuildFinishTime")
  func test_resolvedTimestamp_fallsBackToBuildFinishTime() throws {
    // GIVEN — Azure Pipelines emits seven fractional digits
    let sut = try makeSUT()

    // WHEN
    let timestamp = sut.resolvedTimestamp(
      environment: ["BUILD_FINISHTIME": "2026-09-14T12:00:00.1234567Z"],
      now: Date(timeIntervalSince1970: 0),
    )

    // THEN — the value parses despite the extra precision, sharing the CAS metrics' instant
    #expect(timestamp != Date(timeIntervalSince1970: 0))
    #expect(abs(timestamp.timeIntervalSince(Date(timeIntervalSince1970: 1_789_387_200))) < 1)
  }

  @Test("resolvedTimestamp parsesBuildFinishTimeWithoutFractionalSeconds")
  func test_resolvedTimestamp_parsesBuildFinishTimeWithoutFractionalSeconds() throws {
    // GIVEN — a whole-second ISO 8601 value
    let sut = try makeSUT()

    // WHEN
    let timestamp = sut.resolvedTimestamp(
      environment: ["BUILD_FINISHTIME": "2026-09-14T12:00:00Z"],
      now: Date(timeIntervalSince1970: 0),
    )

    // THEN
    #expect(timestamp == Date(timeIntervalSince1970: 1_789_387_200))
  }

  @Test("resolvedTimestamp fallsBackToNowForUnparsableValue")
  func test_resolvedTimestamp_fallsBackToNowForUnparsableValue() throws {
    // GIVEN — a variable set to something that is not a date
    let sut = try makeSUT()
    let now = Date(timeIntervalSince1970: 12345)

    // WHEN
    let timestamp = sut.resolvedTimestamp(environment: ["BUILD_FINISHTIME": "not a date"], now: now)

    // THEN — a bad timestamp degrades to the current time rather than failing the export
    #expect(timestamp == now)
  }

  // MARK: - Input

  @Test("resolvedInputs throwsWhenNoReportIsGiven")
  func test_resolvedInputs_throwsWhenNoReportIsGiven() throws {
    // GIVEN — neither report option
    let sut = try makeSUT()

    // WHEN / THEN
    #expect(throws: ValidationError.self) { try sut.resolvedInputs() }
  }

  @Test("resolvedInputs throwsForMissingFile")
  func test_resolvedInputs_throwsForMissingFile() throws {
    // GIVEN — a path that does not exist
    let sut = try makeSUT(["--xunit", "/nonexistent/report.xml"])

    // WHEN / THEN
    #expect(throws: ValidationError.self) { try sut.resolvedInputs() }
  }

  @Test("resolvedInputs returnsXUnitForExistingFile")
  func test_resolvedInputs_returnsXUnitForExistingFile() throws {
    // GIVEN — an existing xUnit report on disk
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).xml")
    try Data("<testsuites/>".utf8).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }

    let sut = try makeSUT(["--xunit", url.path])

    // WHEN
    let inputs = try sut.resolvedInputs()

    // THEN
    #expect(inputs == Options.Inputs(report: .xunit(URL(fileURLWithPath: url.path)), llvmLineCoverage: .none))
  }

  #if os(macOS)
    @Test("resolvedInputs throwsWhenBothReportsAreGiven")
    func test_resolvedInputs_throwsWhenBothReportsAreGiven() throws {
      // GIVEN — both report options, pointing at files that do exist
      let directory = FileManager.default.temporaryDirectory.path
      let sut = try makeSUT(["--xunit", directory, "--xcresult", directory])

      // WHEN / THEN — ambiguity is rejected rather than silently resolved by precedence
      #expect(throws: ValidationError.self) { try sut.resolvedInputs() }
    }
  #endif
}

extension OptionsResolutionTests {
  /// Creates an empty file on disk.
  ///
  /// - Returns: The URL of the file, which the caller is expected to remove.
  /// - Throws: An error if the file cannot be written.
  private func makeFile() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try Data().write(to: url)
    return url
  }

  @Test("resolvedInputs returnsLLVMLineCoverageAlone")
  func test_resolvedInputs_returnsLLVMLineCoverageAlone() throws {
    // GIVEN — only an LLVM coverage file
    let file = try makeFile()
    defer { try? FileManager.default.removeItem(at: file) }
    let sut = try Options.parse(["--llvm-line-coverage", file.path])

    // WHEN
    let inputs = try sut.resolvedInputs()

    // THEN
    #expect(inputs == Options.Inputs(report: .none, llvmLineCoverage: URL(fileURLWithPath: file.path)))
  }

  @Test("resolvedInputs combinesXUnitWithLLVMLineCoverage")
  func test_resolvedInputs_combinesXUnitWithLLVMLineCoverage() throws {
    // GIVEN — the Linux path: an xUnit report and an LLVM coverage file
    let xunit = try makeFile()
    let llvm = try makeFile()
    defer {
      try? FileManager.default.removeItem(at: xunit)
      try? FileManager.default.removeItem(at: llvm)
    }
    let sut = try Options.parse(["--xunit", xunit.path, "--llvm-line-coverage", llvm.path])

    // WHEN
    let inputs = try sut.resolvedInputs()

    // THEN
    #expect(
      inputs
        == Options.Inputs(
          report: .xunit(URL(fileURLWithPath: xunit.path)),
          llvmLineCoverage: URL(fileURLWithPath: llvm.path),
        )
    )
  }

  @Test("resolvedInputs throwsForMissingLLVMLineCoverageFile")
  func test_resolvedInputs_throwsForMissingLLVMLineCoverageFile() throws {
    // GIVEN — an explicitly requested file that does not exist
    let sut = try Options.parse(["--llvm-line-coverage", "/nonexistent/lcov.json"])

    // WHEN / THEN
    #expect(throws: ValidationError.self) { try sut.resolvedInputs() }
  }

  @Test("resolvedInputs throwsWhenLLVMLineCoverageContradictsNoCoverage")
  func test_resolvedInputs_throwsWhenLLVMLineCoverageContradictsNoCoverage() throws {
    // GIVEN
    let file = try makeFile()
    defer { try? FileManager.default.removeItem(at: file) }
    let sut = try Options.parse(["--llvm-line-coverage", file.path, "--no-line-coverage"])

    // WHEN / THEN
    #expect(throws: ValidationError.self) { try sut.resolvedInputs() }
  }

  #if os(macOS)
    @Test("resolvedInputs throwsWhenXCResultIsCombinedWithLLVMLineCoverage")
    func test_resolvedInputs_throwsWhenXCResultIsCombinedWithLLVMLineCoverage() throws {
      // GIVEN — an xcresult already carries line coverage
      let file = try makeFile()
      defer { try? FileManager.default.removeItem(at: file) }
      let sut = try Options.parse(["--xcresult", file.path, "--llvm-line-coverage", file.path])

      // WHEN / THEN
      #expect(throws: ValidationError.self) { try sut.resolvedInputs() }
    }
  #endif
}
