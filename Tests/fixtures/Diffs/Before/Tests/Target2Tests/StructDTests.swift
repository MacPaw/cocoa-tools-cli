import Testing

@testable import Target2

struct StructDTests {
  @Test
  func uppercased() {
    let sut = StructD(name: "hello")
    #expect(sut.uppercased() == "HELLO")
    // lowercased() intentionally not tested — will be added in After for + delta
  }
}
