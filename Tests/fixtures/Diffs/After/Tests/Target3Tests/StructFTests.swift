import Testing

@testable import Target3

struct StructFTests {
  @Test
  func increment() {
    let sut = StructF(a: 5)
    #expect(sut.increment() == 6)
    // decrement() intentionally not tested — partial coverage for Target3
  }
}
