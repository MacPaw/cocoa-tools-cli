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

  @Test("logsURL defaultsToStandardSignalPathOnTheMetricsEndpoint")
  func test_logsURL_defaultsToStandardSignalPathOnTheMetricsEndpoint() throws {
    // GIVEN — no Loki endpoint
    let sut = TestsOTELReporter.Configuration(endpoint: try #require(URL(string: "https://collector.example:4318")))

    // WHEN / THEN — logs follow the collector, with the standard OTLP path
    #expect(sut.logsURL.absoluteString == "https://collector.example:4318/v1/logs")
  }

  @Test("logsURL appendsOnlyTheSignalPathToTheLokiEndpoint")
  func test_logsURL_appendsOnlyTheSignalPathToTheLokiEndpoint() throws {
    // GIVEN — a Loki base URL that already carries Loki's OTLP prefix
    let sut = TestsOTELReporter.Configuration(
      endpoint: try #require(URL(string: "https://collector.example")),
      lokiEndpoint: try #require(URL(string: "https://loki.example:3100/otlp")),
    )

    // WHEN / THEN — the signal path is appended exactly as for the OTLP endpoint, and the collector is not involved
    #expect(sut.logsURL.absoluteString == "https://loki.example:3100/otlp/v1/logs")
  }

  @Test("logsHeaders fallsBackToTheMetricsHeaders")
  func test_logsHeaders_fallsBackToTheMetricsHeaders() throws {
    // GIVEN — metrics headers and no Loki headers
    let sut = TestsOTELReporter.Configuration(
      endpoint: try #require(URL(string: "https://collector.example")),
      headers: ["authorization": "metrics"],
    )

    // WHEN / THEN
    #expect(sut.logsHeaders == ["authorization": "metrics"])
  }

  @Test("logsHeaders prefersLokiHeaders")
  func test_logsHeaders_prefersLokiHeaders() throws {
    // GIVEN — both sets of headers
    let sut = TestsOTELReporter.Configuration(
      endpoint: try #require(URL(string: "https://collector.example")),
      headers: ["authorization": "metrics"],
      lokiHeaders: ["authorization": "loki"],
    )

    // WHEN / THEN — Loki's credentials are not mixed with the metrics ones
    #expect(sut.logsHeaders == ["authorization": "loki"])
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
