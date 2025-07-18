import Testing

@testable import SemanticVersion

@Suite("SemanticVersion tests")
struct SemanticVersionTests {
  @Test
  func test_version_init() {
    let version = SemanticVersion(1, 2, 3, prereleaseIdentifiers: ["alpha", "1"], buildMetadataIdentifiers: ["4"])

    // Same init is equal
    #expect(
      version == SemanticVersion(1, 2, 3, prereleaseIdentifiers: ["alpha", "1"], buildMetadataIdentifiers: ["4"])
    )

    // Equal to ExpressibleByStringLiteral
    #expect(version == "1.2.3-alpha.1+4")

    // Stores values correctly
    #expect(version.major == 1)
    #expect(version.minor == 2)
    #expect(version.patch == 3)
    #expect(version.prereleaseIdentifiers == ["alpha", "1"])
    #expect(version.buildMetadataIdentifiers == ["4"])

    // Equal to ExpressibleByIntegerLiteral
    #expect(SemanticVersion(2) == 2)

    // Equal to ExpressibleByFloatLiteral
    #expect(SemanticVersion(3, 1415) == 3.1415)
  }

  @Test
  func test_version_compare() {
    // Metadata doesn't influence when comparing to release
    #expect(SemanticVersion(1, 2, 3, buildMetadataIdentifiers: ["4"]) == "1.2.3")

    // Release is greater than pre-release
    #expect(SemanticVersion(1, 2, 3) > "1.2.3-alpha.1+4")

    // Next versions are bigger
    #expect(SemanticVersion(1, 2, 4) > "1.2.3")
    #expect(SemanticVersion(1, 3, 3) > "1.2.3")
    #expect(SemanticVersion(2, 2, 3) > "1.2.3")
    #expect(SemanticVersion(2, 2, 3) > 2)
    #expect(SemanticVersion(2, 2, 3) > 2.1)
  }

  @Test
  func test_version_isPrerelease() {
    #expect(SemanticVersion(1, 2, 3, prereleaseIdentifiers: ["alpha", "1"]).isPrerelease == true)
    #expect(SemanticVersion(1, 2, 3, prereleaseIdentifiers: []).isPrerelease == false)
  }

  @Test
  func test_version_isRelease() {
    #expect(SemanticVersion(1, 2, 3).isRelease == true)
    #expect(SemanticVersion(1, 2, 3, prereleaseIdentifiers: ["alpha", "1"]).isRelease == false)
  }

  @Test
  func test_version_buildVersion() {
    #expect(SemanticVersion(1, 2, 3, buildMetadataIdentifiers: ["build", "1"]).buildVersion == "1")
    #expect(SemanticVersion(1, 2, 3, buildMetadataIdentifiers: ["build"]).buildVersion == .none)
    #expect(SemanticVersion(1, 2, 3, buildMetadataIdentifiers: []).buildVersion == .none)
  }

  @Test
  func test_codeExpression() {
    #expect(SemanticVersion(floatLiteral: 3.14).codeExpression == #"SemanticVersion(3, 14, 0)"#)

    #expect(SemanticVersion(1, 2, 3).codeExpression == #"SemanticVersion(1, 2, 3)"#)

    #expect(
      SemanticVersion(1, 2, 3, prereleaseIdentifiers: ["alpha", "1"]).codeExpression
        == #"SemanticVersion(1, 2, 3, prereleaseIdentifiers: ["alpha", "1"])"#
    )

    #expect(
      SemanticVersion(1, 2, 3, buildMetadataIdentifiers: ["build", "4"]).codeExpression
        == #"SemanticVersion(1, 2, 3, buildMetadataIdentifiers: ["build", "4"])"#
    )

    #expect(
      SemanticVersion(1, 2, 3, prereleaseIdentifiers: ["alpha", "1"], buildMetadataIdentifiers: ["build", "4"])
        .codeExpression
        == #"SemanticVersion(1, 2, 3, prereleaseIdentifiers: ["alpha", "1"], buildMetadataIdentifiers: ["build", "4"])"#
    )
  }
}
