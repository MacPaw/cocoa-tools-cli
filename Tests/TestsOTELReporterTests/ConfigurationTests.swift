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

  @Test("tracesURL defaultsToStandardSignalPathOnTheMetricsEndpoint")
  func test_tracesURL_defaultsToStandardSignalPathOnTheMetricsEndpoint() throws {
    // GIVEN — no Tempo endpoint
    let sut = TestsOTELReporter.Configuration(endpoint: try #require(URL(string: "https://collector.example:4318")))

    // WHEN / THEN — traces follow the collector, with the standard OTLP path
    #expect(sut.tracesURL.absoluteString == "https://collector.example:4318/v1/traces")
  }

  @Test("tracesURL appendsOnlyTheSignalPathToTheTempoEndpoint")
  func test_tracesURL_appendsOnlyTheSignalPathToTheTempoEndpoint() throws {
    // GIVEN — a Tempo base URL that already carries Tempo's OTLP prefix
    let sut = TestsOTELReporter.Configuration(
      endpoint: try #require(URL(string: "https://collector.example")),
      tempoEndpoint: try #require(URL(string: "https://tempo.example:4318/otlp")),
    )

    // WHEN / THEN — the signal path is appended exactly as for the OTLP endpoint, and the collector is not involved
    #expect(sut.tracesURL.absoluteString == "https://tempo.example:4318/otlp/v1/traces")
  }

  @Test("tracesHeaders fallsBackToTheMetricsHeaders")
  func test_tracesHeaders_fallsBackToTheMetricsHeaders() throws {
    // GIVEN — metrics headers and no Tempo headers
    let sut = TestsOTELReporter.Configuration(
      endpoint: try #require(URL(string: "https://collector.example")),
      headers: ["authorization": "metrics"],
    )

    // WHEN / THEN
    #expect(sut.tracesHeaders == ["authorization": "metrics"])
  }

  @Test("tracesHeaders prefersTempoHeaders")
  func test_tracesHeaders_prefersTempoHeaders() throws {
    // GIVEN — both sets of headers
    let sut = TestsOTELReporter.Configuration(
      endpoint: try #require(URL(string: "https://collector.example")),
      headers: ["authorization": "metrics"],
      tempoHeaders: ["authorization": "tempo"],
    )

    // WHEN / THEN — Tempo's credentials are not mixed with the metrics ones
    #expect(sut.tracesHeaders == ["authorization": "tempo"])
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

  @Test("parse percentDecodesValues")
  func test_parse_percentDecodesValues() {
    // GIVEN — the W3C Baggage form Grafana Cloud documents
    let rawValue = "authorization=Basic%20dXNlcjpwYXNz,x-bad=100%"

    // WHEN
    let sut = OTLPHeaders.parse(rawValue)

    // THEN — invalid percent-encoding is kept as written
    #expect(sut == ["authorization": "Basic dXNlcjpwYXNz", "x-bad": "100%"])
  }

  @Test("parse returnsEmptyForEmptyValue")
  func test_parse_returnsEmptyForEmptyValue() {
    // GIVEN / WHEN — an unset variable reaches the parser as an empty string
    let sut = OTLPHeaders.parse("")

    // THEN
    #expect(sut.isEmpty)
  }
}
