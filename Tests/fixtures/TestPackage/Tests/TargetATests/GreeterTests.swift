import TargetA
import Testing

@Suite
struct GreeterTests {
  @Test("greet returnsFormattedGreeting")
  func test_greet_returnsFormattedGreeting() {
    // GIVEN
    let name = "World"
    // WHEN
    let sut = greet(name)
    // THEN
    #expect(sut == "Hello, World!")
  }
}
