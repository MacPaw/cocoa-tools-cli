import Testing

@testable import Target2

struct StructETests {
  @Test
  func isPositive() {
    let sut = StructE(count: 1)
    #expect(sut.isPositive() == true)
  }

  @Test
  func isNegative() {
    let sut = StructE(count: -1)
    #expect(sut.isNegative() == true)
    // Both functions tested in Before — isNegative() dropped in After for - delta
  }
}
