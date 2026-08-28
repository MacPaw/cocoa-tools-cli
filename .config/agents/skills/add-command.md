# add-command

Add a new CLI subcommand to `mpct` following existing conventions.

## Decide where it lives

- Top-level subcommand (e.g., `mpct mycommand`) → register in `CLI.swift` under `MPCT.configuration.subcommands`
- Under `mpct secrets` → register in `CLI.swift` under `SecretsCommand.configuration.subcommands`

## Steps

### 1. Create the logic module (if needed)

If the command needs non-trivial logic, create a `MyFeature` module first (see the `new-module` skill). Command targets are thin wrappers; business logic lives in the corresponding library.

### 2. Create the command target

Directory: `Sources/MyFeatureCommand/`

Required files:
- `MyFeatureCommand.swift` — the `AsyncParsableCommand` implementation
- `Options.swift` — `@OptionGroup` or `@Option`/`@Flag` declarations (split out if there are more than a couple)

Minimal command template:

```swift
import ArgumentParser
import MyFeature

struct MyFeatureCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "my-feature",
    abstract: "One-line description."
  )

  @OptionGroup var options: Options

  func run() async throws {
    // call into MyFeature here
  }
}
```

### 3. Add to `Package.swift`

```swift
targetBundle(
  name: "MyFeatureCommand",
  dependencies: ["MyFeature"]
  // ArgumentParser is added automatically by targetBundle for *Command targets
),
```

If `targetBundle` doesn't add `ArgumentParser` automatically for your target name, add it explicitly:

```swift
.product(name: "ArgumentParser", package: "swift-argument-parser"),
```

### 4. Register the subcommand

In `Sources/mpct/CLI.swift`, add to the appropriate `subcommands` array:

```swift
static let configuration = CommandConfiguration(
  subcommands: [
    ...,
    MyFeatureCommand.self,
  ]
)
```

Also add `MyFeatureCommand` as a dependency of the `mpct` executable target in `Package.swift`.

### 5. Verify

```bash
mise tasks run build
swift run mpct my-feature --help
mise tasks run test
```
