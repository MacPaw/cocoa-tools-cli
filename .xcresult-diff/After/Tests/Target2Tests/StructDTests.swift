import Testing

@testable import Target2

struct StructDTests {
  @Test
  func uppercased() {
    let sut = StructD(name: "hello")
    #expect(sut.uppercased() == "HELLO")
  }

  @Test
  func lowercased() {
    let sut = StructD(name: "WORLD")
    #expect(sut.lowercased() == "world")
    // lowercased() now tested — produces + delta vs Before
  }
}
