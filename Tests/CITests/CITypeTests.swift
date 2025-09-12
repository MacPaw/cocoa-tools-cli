import Testing

@testable import CI

@Suite("CIType tests")
struct CITypeTests {
  @Test("#init creates CIType with provided name")
  func test_init_createsCITypeWithProvidedName() async throws {
    // GIVEN
    // A name for the CI type
    let expectedName = "Azure DevOps"

    // WHEN
    // Initialize CIType with the name
    let sut = CIType(name: expectedName)

    // THEN
    // Check that the name property is set correctly
    #expect(sut.name == expectedName)
  }
}
