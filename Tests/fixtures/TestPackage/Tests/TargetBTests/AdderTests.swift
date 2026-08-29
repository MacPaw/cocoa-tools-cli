import TargetB
import Testing

@Suite
struct AdderTests {
  @Test("add returnsSumOfTwoIntegers")
  func test_add_returnsSumOfTwoIntegers() {
    // GIVEN
    let a = 3
    let b = 5
    // WHEN
    let sut = add(a, b)
    // THEN
    #expect(sut == 8)
  }
}
