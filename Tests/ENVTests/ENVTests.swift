import Foundation
import Testing

@testable import ENV

@Suite("ENV tests")
struct ENVTests {
  let environment: [String: String] = ["CI": "true", "INT": "42", "DOUBLE": "3.14"]

  @Test("#init with environment")
  func test_init_withEnvironment() async throws {
    // GIVEN
    // WHEN
    let sut: ENV = ENV(variables: environment)

    // THEN
    #expect(sut.variables == environment)
  }

  @Test("#current must return the current process environment")
  func test_current() async throws {
    // GIVEN
    // WHEN
    let sut: ENV = ENV.current

    // THEN
    // Check that the current environment is set correctly.
    #expect(sut.variables == ProcessInfo.processInfo.environment)
  }

  @Test("#getters")
  func test_getters() async throws {
    // GIVEN
    // WHEN
    let sut: ENV = ENV(variables: environment)

    // THEN
    #expect(sut["NOT_EXISTING"] == nil)
    #expect(sut["NOT_EXISTING"] == false)
    #expect(sut.NOT_EXISTING == nil)
    #expect(sut.NOT_EXISTING == false)

    #expect(sut["NOT_EXISTING", default: true] == true)
    #expect(sut["NOT_EXISTING", default: "default"] == "default")
    #expect(sut["NOT_EXISTING", default: 42] == 42)

    // Bool
    #expect(sut["CI"] == "true")
    #expect(sut["CI"] == true)
    #expect(sut.CI == "true")
    #expect(sut.CI == true)

    // Lossless string convertible
    #expect(sut.INT == "42")
    #expect(sut.INT == 42)

    #expect(sut.DOUBLE == "3.14")
    #expect(sut.DOUBLE == 3.14)
  }

  @Test("#equatable")
  func test_equatable() async throws {
    // GIVEN
    let sut = ENV(variables: environment)

    // WHEN
    // THEN
    #expect(sut == ENV(variables: environment))
    #expect(environment == sut)
    #expect(sut == environment)
    #expect(sut != ["CI": "false"])
    #expect(sut != ENV(variables: ["CI": "false"]))

    #expect(["CI": "false"] == ENV(variables: ["CI": "false"]))
  }

  @Test("#init decode")
  func test_decode() async throws {
    // GIVEN
    let encodedDictData = try JSONEncoder().encode(environment)

    // WHEN
    let sut = try JSONDecoder().decode(ENV.self, from: encodedDictData)

    // THEN
    #expect(sut.variables == environment)
  }

  @Test("#init encode")
  func test_encode() async throws {
    // GIVEN
    let sut = ENV(variables: environment)
    let encodedENVData = try JSONEncoder().encode(sut)

    // WHEN
    let decodedDictionary: [String: String] = try JSONDecoder().decode([String: String].self, from: encodedENVData)

    // THEN
    #expect(decodedDictionary == environment)
  }
}
