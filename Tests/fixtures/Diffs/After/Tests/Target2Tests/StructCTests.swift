import Testing

@testable import Target2

struct StructCTests {
  @Test
  func doubled() {
    let sut = StructC(value: 5)
    #expect(sut.doubled() == 10)
  }

  @Test
  func negated() {
    let sut = StructC(value: 5)
    #expect(sut.negated() == -5)
  }
}
