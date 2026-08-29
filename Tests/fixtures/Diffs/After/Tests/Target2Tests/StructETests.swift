import Testing

@testable import Target2

struct StructETests {
  @Test
  func isPositive() {
    let sut = StructE(count: 1)
    #expect(sut.isPositive() == true)
    // isNegative() intentionally not tested — produces - delta vs Before
  }
}
