import Foundation
import Testing

@testable import TestsOTELReporter

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

struct TestsOTELReporterErrorTests {
  @Test("wrongStatusCode description names the failing URL and the status")
  func test_wrongStatusCode_descriptionNamesURL() throws {
    // GIVEN
    let url = try #require(URL(string: "http://collector:4318/v1/metrics"))
    let sut = TestsOTELReporter.Error.wrongStatusCode(404, url: url, body: "not found")

    // WHEN
    let description = sut.description

    // THEN
    #expect(description == "OTLP export to http://collector:4318/v1/metrics failed with status 404: not found")
  }

  @Test("wrongStatusCode description truncates a long body")
  func test_wrongStatusCode_descriptionTruncatesLongBody() throws {
    // GIVEN
    let url = try #require(URL(string: "http://collector:4318/v1/metrics"))
    let body = String(repeating: "x", count: TestsOTELReporter.Error.maxBodyLength + 100)
    let sut = TestsOTELReporter.Error.wrongStatusCode(502, url: url, body: body)

    // WHEN
    let description = sut.description

    // THEN
    let expectedBody = String(repeating: "x", count: TestsOTELReporter.Error.maxBodyLength) + "…(truncated)"
    #expect(description.hasSuffix(": \(expectedBody)"))
  }

  @Test("wrongStatusCode description omits a missing body")
  func test_wrongStatusCode_descriptionOmitsMissingBody() throws {
    // GIVEN
    let url = try #require(URL(string: "http://collector:4318/v1/logs"))
    let sut = TestsOTELReporter.Error.wrongStatusCode(500, url: url, body: .none)

    // WHEN
    let description = sut.description

    // THEN
    #expect(description == "OTLP export to http://collector:4318/v1/logs failed with status 500")
  }

  @Test("responseNotHTTP description names the URL")
  func test_responseNotHTTP_descriptionNamesURL() throws {
    // GIVEN
    let url = try #require(URL(string: "http://collector:4318/v1/metrics"))
    let response = URLResponse(url: url, mimeType: .none, expectedContentLength: 0, textEncodingName: .none)
    let sut = TestsOTELReporter.Error.responseNotHTTP(response, url: url)

    // WHEN
    let description = sut.description

    // THEN
    #expect(description.hasPrefix("OTLP export to http://collector:4318/v1/metrics got a non-HTTP response"))
  }

  @Test("responseNotHTTP description does not leak the response URL")
  func test_responseNotHTTP_descriptionHidesResponseURL() throws {
    // GIVEN
    let secretURL = try #require(URL(string: "http://user:secret@collector:4318/v1/metrics?token=abc"))
    let safeURL = TestsOTELReporter.Error.redacted(secretURL)
    let response = URLResponse(url: secretURL, mimeType: .none, expectedContentLength: 0, textEncodingName: .none)
    let sut = TestsOTELReporter.Error.responseNotHTTP(response, url: safeURL)

    // WHEN
    let description = sut.description

    // THEN
    #expect(!description.contains("secret"))
    #expect(!description.contains("token"))
  }

  @Test("redacted removes user info, query and fragment")
  func test_redacted_removesCredentials() throws {
    // GIVEN
    let url = try #require(URL(string: "https://user:secret@loki.example.com:3100/otlp/v1/logs?token=abc#frag"))

    // WHEN
    let sut = TestsOTELReporter.Error.redacted(url)

    // THEN
    #expect(sut.absoluteString == "https://loki.example.com:3100/otlp/v1/logs")
  }
}
