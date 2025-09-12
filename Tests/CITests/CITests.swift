import Foundation
import Testing

@testable import CI
@testable import ENV

@Suite("CI tests")
final class CITests {
  init() { CI.reset() }

  deinit { CI.reset() }

  @Test("#current returns Local CI when no supported CI is detected")
  func test_current_sync() async throws {
    // CI.current is designed as singleton.
    // Testing synchronously since parallel testing introduces race conditions in tests.
    try await test_register_allowsAddingNewCITypes()

    try await test_current_returnsLocalCIWhenNoSupportedCIIsDetected()
  }

  // swift-format-ignore: AlwaysUseLowerCamelCase
  func test_current_returnsLocalCIWhenNoSupportedCIIsDetected() async throws {
    // GIVEN
    // WHEN
    CI.reset()
    // Get the current CI type
    let sut = CI.current

    // THEN
    // Check that it returns Local CI type
    if ENV.GITHUB_ACTIONS {
      #expect(sut.type.name == "GitHub Actions")
    }
    else {
      #expect(sut.type.name == "Local")
    }

    CI.reset()
  }

  // swift-format-ignore: AlwaysUseLowerCamelCase
  func test_register_allowsAddingNewCITypes() async throws {
    // GIVEN
    // WHEN
    CI.reset()

    // Register a new CI type and get current CI
    CI.register(MockCI.self)
    let sut = CI.current

    // THEN
    // Check that it can detect the new CI type
    #expect(sut.type.name == "Mock")

    CI.reset()
  }
}

// Mock CI for testing
struct MockCI: CIInterface {
  var type: CIType { CIType(name: "Mock") }

  static func validateAsCurrentCI(_ environment: ENV) -> Bool {
    // Always validate as current for testing
    true
  }

  init(env: ENV) {
    // Mock implementation
  }
}
