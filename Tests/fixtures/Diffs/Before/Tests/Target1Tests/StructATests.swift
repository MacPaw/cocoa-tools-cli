import Testing

@testable import Target1

struct StructATests {
  @Test
  func doubled() {
    let sut = StructA(x: 5)
    #expect(sut.doubled() == 10)
  }
}
