# new-module

Scaffold a new SPM module in the `mpct` package following existing conventions.

## Steps

### 1. Add the target in ALL Package manifests

This repo has multiple Package manifests for different Swift toolchain versions:
- `Package.swift` — baseline swift-tools-version
- `Package@swift-6.3.swift` — active manifest when building with Swift 6.3+

**You MUST update every `Package@swift-X.Y.swift` file in the repo root, not just `Package.swift`.**
Check with `ls Package*.swift` before editing.

Use the `targetBundle` helper — it auto-adds `SharedLogger`. Pass extra dependencies as needed:

```swift
static var myModule: [PackageDescription.Target] {
  targetBundle(
    name: "MyModule",
    dependencies: [.target(name: "SomeOtherModule")],
  )
}
```

Then append `Targets.myModule` to the `targets` array in every manifest.

If the module exposes a public API, add it to `products` in every manifest:

```swift
.library(name: "MyModule", targets: ["MyModule"]),
```

### 2. Create the source file

```
Sources/MyModule/MyModule.swift
```

Follow the one-main-type-per-file rule. **Add `///` doc comments on ALL public declarations** — types, properties, methods, and initializers.

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
- Use `#require` for non-optional assertions that gate subsequent `#expect` calls

### 4. Verify

```bash
mise tasks run build
mise tasks run test
```
