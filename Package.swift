// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import Foundation
import PackageDescription

let packageDirURL: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()

let swiftLanguageVersion: String =
  (try? String(contentsOf: packageDirURL.appendingPathComponent(".swift-version"), encoding: .utf8))
  .flatMap { Version($0.trimmingCharacters(in: .newlines))?.major }.map(String.init(describing:)) ?? "6"

/// swift-confidential package source.
enum SwiftConfidentialSource {
  // Waiting for the https://github.com/securevale/swift-confidential/pull/10 to be merged 🤞.

  case upstream
  case fork

  var packageDependency: PackageDescription.Package.Dependency {
    switch self {
    case .upstream: .package(url: "https://github.com/securevale/swift-confidential.git", from: "0.4.1")
    case .fork: .package(url: "https://github.com/nekrich/swift-confidential.git", branch: "master")
    }
  }

  var confidentialKitTargetDependency: PackageDescription.Target.Dependency {
    .product(name: "ConfidentialKit", package: "swift-confidential", condition: .when(platforms: [.macOS]))
  }

  var targetDependency: PackageDescription.Target.Dependency {
    switch self {
    case .upstream: .target(name: "Dummy")
    case .fork:
      #if os(macOS)
        .product(name: "ConfidentialObfuscator", package: "swift-confidential", condition: .when(platforms: [.macOS]))
      #else
        .target(name: "Dummy")
      #endif
    }
  }
}

// Yams package source.
enum YamsSource {
  // Waiting for the https://github.com/jpsim/Yams/pull/460 to be merged 🤞.

  case upstream
  case fork

  var packageDependency: PackageDescription.Package.Dependency {
    switch self {
    case .upstream: .package(url: "https://github.com/jpsim/Yams.git", from: "6.1.0")
    case .fork: .package(url: "https://github.com/nekrich/Yams.git", branch: "main")
    }
  }
}

let swiftConfidentialSource: SwiftConfidentialSource = .fork
let yamsSource: YamsSource = .fork

enum Targets {
  static func targetBundle(
    name: String,
    dependencies: [PackageDescription.Target.Dependency] = [],
    plugins: [PackageDescription.Target.PluginUsage] = [],
    tests: Bool = true,
    testsDependencies: [PackageDescription.Target.Dependency] = []
  ) -> [PackageDescription.Target] {
    var targets: [PackageDescription.Target] = [.target(name: name, dependencies: dependencies, plugins: plugins)]

    if tests {
      targets.append(.testTarget(name: "\(name)Tests", dependencies: [.target(name: name)] + testsDependencies))
    }

    return targets
  }

  static func commandBundle(
    name: String,
    dependencies: [PackageDescription.Target.Dependency] = [],
    plugins: [PackageDescription.Target.PluginUsage] = [],
    tests: Bool = true,
    testsDependencies: [PackageDescription.Target.Dependency] = [],
    commandDependencies: [PackageDescription.Target.Dependency] = [],
    commandTests: Bool = false,
    commandTestsDependencies: [PackageDescription.Target.Dependency] = []
  ) -> [PackageDescription.Target] {
    targetBundle(name: name, dependencies: dependencies, tests: tests, testsDependencies: testsDependencies)
      + targetBundle(
        name: "\(name)Command",
        dependencies: [.target(name: name), .product(name: "ArgumentParser", package: "swift-argument-parser")]
          + commandDependencies,
        tests: commandTests,
        testsDependencies: commandTestsDependencies
      )
  }

  static var env: [PackageDescription.Target] { targetBundle(name: "ENV") }
  static var ci: [PackageDescription.Target] { targetBundle(name: "CI", dependencies: [.target(name: "ENV")]) }

  static var shell: [PackageDescription.Target] { targetBundle(name: "Shell", tests: false) }

  static var envSubst: [PackageDescription.Target] {
    commandBundle(name: "EnvSubst", testsDependencies: [.target(name: "Shell")])
  }

  static var importSecrets: [PackageDescription.Target] {
    commandBundle(
      name: "ImportSecrets",
      dependencies: [
        .target(name: "EnvSubst"), .target(name: "Shell"), .target(name: "HashiCorpVaultReader"),
        .product(name: "Yams", package: "Yams"),
      ],
      commandDependencies: [
        .target(name: "EnvSubstCommand"), .target(name: "ExportSecrets"), .target(name: "HashiCorpVaultReader"),
      ]
    )
  }

  static var exportSecrets: [PackageDescription.Target] {
    targetBundle(name: "ExportSecrets", dependencies: [.target(name: "Shell")])
  }

  static var obfuscateSecrets: [PackageDescription.Target] {
    commandBundle(
      name: "ObfuscateSecrets",
      dependencies: [.target(name: "EnvSubst"), .target(name: "Shell"), swiftConfidentialSource.targetDependency],
      testsDependencies: [
        .product(name: "ConfidentialKit", package: "swift-confidential", condition: .when(platforms: [.macOS])),
        swiftConfidentialSource.targetDependency,
      ],
      commandDependencies: [.target(name: "EnvSubstCommand"), .target(name: "ImportSecretsCommand")]
    )
  }

  static var semanticVersion: [PackageDescription.Target] {
    targetBundle(name: "SemanticVersion")
      + targetBundle(
        name: "SemanticVersionMacro",
        dependencies: [.target(name: "SemanticVersion"), .target(name: "SemanticVersionMacroPlugin")],
        tests: false
      ) + [
        .macro(
          name: "SemanticVersionMacroPlugin",
          dependencies: [
            .target(name: "SemanticVersion"), .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
          ]
        ),
        .plugin(
          name: "SemanticVersionBuildToolPlugin",
          capability: .buildTool(),
          dependencies: [.target(name: "SemanticVersionGenerator")]
        ),
        .executableTarget(
          name: "SemanticVersionGenerator",
          dependencies: [
            .product(name: "ArgumentParser", package: "swift-argument-parser"), .target(name: "SemanticVersion"),
          ]
        ),
      ]
  }

  static var hashicorpVaultReader: [PackageDescription.Target] {
    targetBundle(name: "HashiCorpVaultReader", tests: false)
  }
}

let package = Package(
  name: "cocoa-tools",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "mpct", targets: ["mpct"]), .library(name: "EnvSubst", targets: ["EnvSubst"]),
    .library(name: "Shell", targets: ["Shell"]), .library(name: "ImportSecrets", targets: ["ImportSecrets"]),
    .library(name: "ExportSecrets", targets: ["ExportSecrets"]),
    .library(name: "ObfuscateSecrets", targets: ["ObfuscateSecrets"]),
    .library(name: "HashiCorpVaultReader", targets: ["HashiCorpVaultReader"]),
    .plugin(name: "SemanticVersionBuildToolPlugin", targets: ["SemanticVersionBuildToolPlugin"]),
    .library(name: "ENV", targets: ["ENV"]), .library(name: "CI", targets: ["CI"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser.git", .upToNextMajor(from: "1.6.1")),
    .package(url: "https://github.com/swiftlang/swift-format.git", .upToNextMajor(from: "601.0.0")),
    .package(url: "https://github.com/swiftlang/swift-syntax.git", "509.1.1"..<"602.0.0"),
    swiftConfidentialSource.packageDependency, yamsSource.packageDependency,
  ],
  targets: [
    .executableTarget(
      name: "mpct",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"), .target(name: "EnvSubstCommand"),
        .target(name: "ObfuscateSecretsCommand", condition: .when(platforms: [.macOS])),
        .target(name: "ImportSecretsCommand"), .target(name: "SemanticVersion"), .target(name: "SemanticVersionMacro"),
      ],
      packageAccess: true,
      plugins: [.plugin(name: "SemanticVersionBuildToolPlugin")]
    ),

    // Dummy target to avoid optional compact map on dependencies for swift-confidential upstream w/o ConfidentialObfuscator
    .target(name: "Dummy"),

  ] + Targets.shell + Targets.envSubst + Targets.exportSecrets + Targets.importSecrets + Targets.obfuscateSecrets
    + Targets.semanticVersion + Targets.env + Targets.ci + Targets.hashicorpVaultReader,

  swiftLanguageModes: [.version(swiftLanguageVersion)]
)

for target in package.targets where target.type != .plugin && target.type != .test {
  var settings: [SwiftSetting] = target.swiftSettings ?? []
  // any existential type syntax.
  settings.append(.enableUpcomingFeature("ExistentialAny"))
  // Enables errors for uses of members that cannot be accessed because their defining module is not directly imported.
  settings.append(.enableUpcomingFeature("MemberImportVisibility"))
  // Runs nonisolated async functions on the caller’s actor by default.
  settings.append(.enableUpcomingFeature("NonisolatedNonsendingByDefault"))
  // Errors and warnings related to the compiler’s CAS compilation caching.
  settings.append(.define("CompilationCaching"))
  // Warnings related to deprecated APIs that may be removed in future versions and should be replaced with more current alternatives.
  settings.append(.define("DeprecatedDeclaration"))
  // Warnings that identify import declarations with the @_implementationOnly attribute.
  settings.append(.define("ImplementationOnlyDeprecated"))
  // Warnings that diagnose @preconcurrency import declarations that don’t need @preconcurrency, experimental and disabled by default.
  settings.append(.define("PreconcurrencyImport"))
  // Notes related to information about a missing module dependency.
  settings.append(.define("MissingModuleOnKnownPaths"))
  // Warnings that indicate the compiler cannot resolve an #if canImport(<ModuleName>, _version: <version>) directive because the module found was not built with a -user-module-version flag.
  settings.append(.define("ModuleVersionMissing"))
  // Warnings for unrecognized feature names in -enable-upcoming-feature or enable-experimental-feature.
  settings.append(.define("StrictLanguageFeatures"))
  // Warnings that identify the use of language constructs and library APIs that can undermine memory safety, disabled by default.
  settings.append(.define("StrictMemorySafety"))
  // Warnings that identify unrecognized platform names in @available attributes and if #available statements.
  settings.append(.define("AvailabilityUnrecognizedName"))
  // Warnings for unrecognized warning groups specified in -Wwarning or -Werror.
  settings.append(.define("UnknownWarningGroup"))
  target.swiftSettings = settings
}
