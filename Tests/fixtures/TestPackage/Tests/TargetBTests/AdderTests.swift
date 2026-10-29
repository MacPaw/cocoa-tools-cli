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

  @Test("isNegative returnsTrueForNegativeInteger")
  func test_isNegative_returnsTrueForNegativeInteger() {
    // GIVEN
    let value = -1
    // WHEN
    let sut = isNegative(value)
    // THEN
    #expect(sut)
  }
}
