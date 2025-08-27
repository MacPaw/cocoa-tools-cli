# SemanticVersion

A comprehensive Swift implementation of semantic versioning with compile-time macro support and build tool integration.

SemanticVersion is based on [swiftlang/swift-package-manager/Verion](https://github.com/swiftlang/swift-package-manager/blob/main/Sources/PackageDescription/Version.swift) under Apache License.

New features:  
* `Codable` support
* `ExpressibleByIntegerLiteral` and `ExpressibleByFloatLiteral` support
* `#semanticVersion` macro
* Build plugin
* Throwable `.build` method with detailed errors

## Overview

The SemanticVersion module provides three main components:

1. **SemanticVersion**: A Swift struct implementing the [Semantic Versioning 2.0.0](https://semver.org) specification
2. **SemanticVersionMacro**: A compile-time macro for creating SemanticVersion instances
3. **SemanticVersionBuildToolPlugin**: A build plugin for automatic version generation

## Components

### SemanticVersion

A value type representing a semantic version with major, minor, and patch components, plus optional prerelease and build metadata identifiers.

#### Features

- **[Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html) Compliance**: Full implementation of the specification
- **Comparison Support**: Implements `Comparable` for version ordering
- **String Conversion**: Supports parsing from and converting to strings
- **Codable Support**: JSON/Plist encoding and decoding
- **Literal Support**: Create versions from string, integer, and float literals
- **Validation**: Compile-time and runtime validation of version components

#### Basic Usage

```swift
import SemanticVersion

// Create versions
let version1 = SemanticVersion(1, 2, 3)
let version2 = SemanticVersion(1, 2, 4, prereleaseIdentifiers: ["beta", "1"])
let version3: SemanticVersion = "2.0.0"
let version4: SemanticVersion = 2
let version5: SemanticVersion = 3.14

// Compare versions
print(version1 < version2) // true
print(version2.isPrerelease) // true
print(version1.isRelease) // true
print(version4) // "2.0.0"
print(version5) // "3.14"

// Access components
print(version1.major) // 1
print(version1.minor) // 2
print(version1.patch) // 3
```

#### Advanced Features

```swift
// Build metadata (custom extension)
let buildVersion = SemanticVersion(
  1, 0, 0,
  buildMetadataIdentifiers: ["build", "123"]
)
print(buildVersion.buildVersion) // Optional("123")

// String parsing
let parsed = SemanticVersion("1.2.3-alpha.1+build.456")
print(parsed?.prereleaseIdentifiers) // ["alpha", "1"]
print(parsed?.buildMetadataIdentifiers) // ["build", "456"]
print(parsed?.buildVersion) // "456"
```

### SemanticVersionMacro

A compile-time macro that parses version strings and generates optimized SemanticVersion initialization code.

#### Features

- **Compile-Time Parsing**: Version validation at build time
- **Multiple Input Types**: Supports string, integer, and float literals
- **Error Reporting**: Clear diagnostic messages for invalid versions
- **Zero Runtime Cost**: Generates direct initialization code

#### Usage

```swift
import SemanticVersion

// String literal
let version1 = #semanticVersion("1.2.3")

// Integer literal (major version only)
let version2 = #semanticVersion(2)

// Float literal (major.minor)
let version3 = #semanticVersion(1.5)

// Complex versions
let prerelease = #semanticVersion("2.0.0-beta.1")
let withBuild = #semanticVersion("1.0.0+build.123")
```

#### Macro Expansion

The macro expands to direct SemanticVersion initialization:

```swift
// Input
#semanticVersion("1.2.3-beta.1")

// Expands to
SemanticVersion(
  1, 2, 3,
  prereleaseIdentifiers: ["beta", "1"],
  buildMetadataIdentifiers: []
)
```

### SemanticVersionBuildToolPlugin

A Swift Package Manager build plugin that automatically generates version information from a `.version` file.

#### Features

- **Automatic Generation**: Reads `.version` file and creates Swift code
- **Per-Target Support**: Generates version constants for each target
- **Build Integration**: Rebuilds when version file changes
- **Xcode Compatible**: Works with both SPM and Xcode projects

#### Setup

1. Create a `.version` file in your package root:
```
1.2.3
```

2. Add the plugin to your target in `Package.swift`:
```swift
.target(
  name: "MyTarget",
  dependencies: ["SemanticVersion"],
  plugins: ["SemanticVersionBuildToolPlugin"]
)
```

3. Use the generated version:
```swift
let version = TargetVersions.myTarget
print("Version: \(version)") // Version: 1.2.3
```

#### Generated Code

For a target named `MyTarget`, the plugin generates:

```swift
// MyTargetVersion.swift (generated)
import SemanticVersion

extension TargetVersions {
  public static let myTarget: SemanticVersion = #semanticVersion("1.2.3")
}
```

## Integration Examples

### Package.swift Configuration

```swift
let package = Package(
  name: "MyPackage",
  dependencies: [
    .package(path: "../mpct")
  ],
  targets: [
    .target(
      name: "Core",
      dependencies: [
        .product(name: "SemanticVersion", package: "mpct")
      ],
      plugins: [
        .plugin(name: "SemanticVersionBuildToolPlugin", package: "mpct")
      ]
    )
  ]
)
```

### Version Management

```swift
import SemanticVersion

struct AppVersion {
  static let current = TargetVersions.core
  
  static var displayString: String {
    var result = "\(current.major).\(current.minor).\(current.patch)"
    
    if current.isPrerelease {
      result += "-\(current.prereleaseIdentifiers.joined(separator: "."))"
    }
    
    if let buildVersion = current.buildVersion {
      result += " (build \(buildVersion))"
    }
    
    return result
  }
}
```

### CI/CD Integration

```bash
#!/bin/bash
# Update version in CI pipeline
echo "1.2.3-beta.1+build.${BUILD_NUMBER}" > .version
swift build
```

## API Reference

### SemanticVersion Properties

- `major: Int` - Major version number
- `minor: Int` - Minor version number  
- `patch: Int` - Patch version number
- `prereleaseIdentifiers: [String]` - Prerelease identifiers
- `buildMetadataIdentifiers: [String]` - Build metadata identifiers
- `isPrerelease: Bool` - Whether this is a prerelease version
- `isRelease: Bool` - Whether this is a release version
- `buildVersion: String?` - Build version from metadata (custom extension)

## Requirements

- Swift 6.1+
- macOS 15+ / iOS 18+ / tvOS 18+ / watchOS 11+
- Xcode 16+ (for macro support)

## Error Handling

### Parse Errors

```swift
do {
  let version = try SemanticVersion.build("invalid")
} catch let error as SemanticVersion.ParseError {
  print(error.errorDescription)
}
```

### Macro Errors

Compile-time errors for invalid versions:

```swift
// Error: Invalid semantic version string '1b2'
let invalid = #semanticVersion("1b2")
```
