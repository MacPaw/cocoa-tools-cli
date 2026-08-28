# new-module

Scaffold a new SPM module in the `mpct` package following existing conventions.

## Steps

### 1. Add the target in `Package.swift`

Use the `targetBundle` helper — it auto-adds `SharedLogger`. Pass extra dependencies as needed:

```swift
targetBundle(
  name: "MyModule",
  dependencies: ["SomeOtherModule"]
),
targetBundle(
  name: "MyModuleTests",
  dependencies: ["MyModule"],
  type: .test
),
```

If the module exposes a public API, add it to `products`:

```swift
.library(name: "MyModule", targets: ["MyModule"]),
```

### 2. Create the source file

```
Sources/MyModule/MyModule.swift
```

Follow the one-main-type-per-file rule. Add doc comments (`///`) on all public declarations.

### 3. Create the test suite

```
Tests/MyModuleTests/MyModuleTests.swift
```

Minimal test file template:

```swift
import Testing
@testable import MyModule

@Suite
struct MyModuleTests {
  @Test("functionOrProperty testExplanation")
  func test_functionOrProperty_testExplanation() {
    // GIVEN - set up inputs and state
    let sut = MyModule(...)

    // WHEN - call the function under test
    let result = sut.doSomething()

    // THEN - assert the output
    #expect(result == expectedValue)
  }
}
```

Key conventions:
- Name the system under test `sut`
- Method name format: `test_functionOrProperty_testExplanation`
- `@Test` label format: `"functionOrProperty testExplanation"` (no `test_` prefix)
- Add brief inline comments in each GIVEN/WHEN/THEN block describing what's happening
- Test outputs, not internal behaviour

### 4. Verify

```bash
mise tasks run build
mise tasks run test
```
