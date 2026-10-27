import Foundation
import Testing

@testable import TestsOTELReporter

@Suite
struct ConfigurationTests {
  @Test("metricsURL appendsSignalPathToBareHost")
  func test_metricsURL_appendsSignalPathToBareHost() throws {
    // GIVEN — a collector base URL with no path, as collector docs advertise it
    let sut = TestsOTELReporter.Configuration(endpoint: try #require(URL(string: "https://collector.example:4318")))

    // WHEN / THEN — the OTLP signal path is appended
    #expect(sut.metricsURL.absoluteString == "https://collector.example:4318/v1/metrics")
  }

  @Test("metricsURL appendsSignalPathRelativeToExistingPath")
  func test_metricsURL_appendsSignalPathRelativeToExistingPath() throws {
    // GIVEN — a base URL that already carries a path, as the OTLP spec's own example does
    let sut = TestsOTELReporter.Configuration(
      endpoint: try #require(URL(string: "https://collector.example/mycollector"))
    )

    // WHEN / THEN — the signal path is appended to it, not substituted for it
    #expect(sut.metricsURL.absoluteString == "https://collector.example/mycollector/v1/metrics")
  }
}

@Suite
struct OTLPHeadersTests {
  @Test("parse readsCommaSeparatedPairs")
  func test_parse_readsCommaSeparatedPairs() {
    // GIVEN — the documented OTEL_EXPORTER_OTLP_HEADERS form
    let rawValue = "api-key=<redacted>,x-scope-orgid=macpaw"

    // WHEN
    let sut = OTLPHeaders.parse(rawValue)

    // THEN
    #expect(sut == ["api-key": "<redacted>", "x-scope-orgid": "macpaw"])
  }

  @Test("parse trimsWhitespaceAroundKeysAndValues")
  func test_parse_trimsWhitespaceAroundKeysAndValues() {
    // GIVEN — a value formatted with spaces after the separators
    let rawValue = "api-key = secret, x-scope-orgid = macpaw"

    // WHEN
    let sut = OTLPHeaders.parse(rawValue)

    // THEN
    #expect(sut == ["api-key": "secret", "x-scope-orgid": "macpaw"])
  }

  @Test("parse keepsEqualsSignsInsideValues")
  func test_parse_keepsEqualsSignsInsideValues() {
    // GIVEN — a base64 credential, which routinely ends in padding
    let rawValue = "authorization=Basic dXNlcjpwYXNz=="

    // WHEN
    let sut = OTLPHeaders.parse(rawValue)

    // THEN — only the first separator splits the entry
    #expect(sut == ["authorization": "Basic dXNlcjpwYXNz=="])
  }

  @Test("parse skipsMalformedEntriesWithoutDiscardingValidOnes")
  func test_parse_skipsMalformedEntriesWithoutDiscardingValidOnes() {
    // GIVEN — a value containing an entry with no separator and one with an empty key
    let rawValue = "api-key=secret,garbage,=orphan"

    // WHEN
    let sut = OTLPHeaders.parse(rawValue)

    // THEN — the valid header still gets sent
    #expect(sut == ["api-key": "secret"])
  }

  @Test("parse returnsEmptyForEmptyValue")
  func test_parse_returnsEmptyForEmptyValue() {
    // GIVEN / WHEN — an unset variable reaches the parser as an empty string
    let sut = OTLPHeaders.parse("")

    // THEN
    #expect(sut.isEmpty)
  }
}
