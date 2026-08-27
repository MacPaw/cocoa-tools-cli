// swift-tools-version: 6.3
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
    case .upstream: .package(url: "https://github.com/securevale/swift-confidential.git", from: "0.5.2")
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
    case .upstream: .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.2")
    case .fork: .package(url: "https://github.com/nekrich/Yams.git", branch: "main")
    }
  }
}

let swiftConfidentialSource: SwiftConfidentialSource = .fork
let yamsSource: YamsSource = .upstream

enum Targets {
  static func targetBundle(
    name: String,
    dependencies: [PackageDescription.Target.Dependency] = [],
    plugins: [PackageDescription.Target.PluginUsage] = [],
    tests: Bool = true,
    testsDependencies: [PackageDescription.Target.Dependency] = [],
  ) -> [PackageDescription.Target] {
    var dependencies = dependencies
    if name != "SharedLogger" { dependencies.append(.target(name: "SharedLogger")) }
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
    commandTestsDependencies: [PackageDescription.Target.Dependency] = [],
  ) -> [PackageDescription.Target] {
    targetBundle(name: name, dependencies: dependencies, tests: tests, testsDependencies: testsDependencies)
      + targetBundle(
        name: "\(name)Command",
        dependencies: [.target(name: name), .product(name: "ArgumentParser", package: "swift-argument-parser")]
          + commandDependencies,
        tests: commandTests,
        testsDependencies: commandTestsDependencies,
      )
  }

  static var env: [PackageDescription.Target] { targetBundle(name: "ENV") }
  static var ci: [PackageDescription.Target] { targetBundle(name: "CI", dependencies: [.target(name: "ENV")]) }

  static var shell: [PackageDescription.Target] { targetBundle(name: "Shell", tests: false) }

  static var envSubst: [PackageDescription.Target] {
    commandBundle(name: "EnvSubst", testsDependencies: [.target(name: "Shell")])
  }

  static var importSecrets: [PackageDescription.Target] {
    targetBundle(
      name: "ImportSecrets",
      dependencies: [
        .target(name: "EnvSubst"), .target(name: "Shell"), .target(name: "HashiCorpVaultReader"),
        .target(name: "SecretsInterface"), .product(name: "Yams", package: "Yams"),
      ],
      testsDependencies: [.target(name: "SecretsInterfaceTesting")],
    )
  }

  static var exportSecrets: [PackageDescription.Target] {
    commandBundle(
      name: "ExportSecrets",
      dependencies: [.target(name: "Shell"), .target(name: "CI")],
      commandDependencies: [
        .target(name: "EnvSubstCommand"), .target(name: "HashiCorpVaultReader"), .target(name: "CI"),
        .target(name: "ImportSecrets"),
      ],
    )
  }

  static var obfuscateSecrets: [PackageDescription.Target] {
    commandBundle(
      name: "ObfuscateSecrets",
      dependencies: [.target(name: "EnvSubst"), .target(name: "Shell"), swiftConfidentialSource.targetDependency],
      testsDependencies: [swiftConfidentialSource.targetDependency],
      commandDependencies: [.target(name: "EnvSubstCommand"), .target(name: "ExportSecretsCommand")],
    )
  }

  static var semanticVersion: [PackageDescription.Target] {
    targetBundle(name: "SemanticVersion")
      + targetBundle(
        name: "SemanticVersionMacro",
        dependencies: [.target(name: "SemanticVersion"), .target(name: "SemanticVersionMacroPlugin")],
        tests: false,
      ) + [
        .macro(
          name: "SemanticVersionMacroPlugin",
          dependencies: [
            .target(name: "SemanticVersion"), .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
          ],
        ),
        .plugin(
          name: "SemanticVersionBuildToolPlugin",
          capability: .buildTool(),
          dependencies: [.target(name: "SemanticVersionGenerator")],
        ),
        .executableTarget(
          name: "SemanticVersionGenerator",
          dependencies: [
            .product(name: "ArgumentParser", package: "swift-argument-parser"), .target(name: "SemanticVersion"),
          ],
        ),
      ]
  }

  static var sharedLogger: [PackageDescription.Target] {
    targetBundle(name: "SharedLogger", dependencies: [.product(name: "Logging", package: "swift-log")], tests: false)
  }

  static var secretsInterface: [PackageDescription.Target] {
    targetBundle(name: "SecretsInterface", tests: false)
      + targetBundle(name: "SecretsInterfaceTesting", dependencies: [.target(name: "SecretsInterface")], tests: false)
  }

  static var hashicorpVaultReader: [PackageDescription.Target] {
    targetBundle(name: "HashiCorpVaultReader", dependencies: [.target(name: "SecretsInterface")], tests: true)
  }
}

let package = Package(
  name: "cocoa-tools",
  platforms: [.macOS(.v15)],
  products: [
    .executable(name: "mpct", targets: ["mpct"]), .library(name: "EnvSubst", targets: ["EnvSubst"]),
    .library(name: "Shell", targets: ["Shell"]), .library(name: "ImportSecrets", targets: ["ImportSecrets"]),
    .library(name: "ExportSecrets", targets: ["ExportSecrets"]),
    .library(name: "ObfuscateSecrets", targets: ["ObfuscateSecrets"]),
    .library(name: "HashiCorpVaultReader", targets: ["HashiCorpVaultReader"]),
    .plugin(name: "SemanticVersionBuildToolPlugin", targets: ["SemanticVersionBuildToolPlugin"]),
    .library(name: "ENV", targets: ["ENV"]), .library(name: "CI", targets: ["CI"]),
    .library(name: "SecretsInterfaceTesting", targets: ["SecretsInterfaceTesting"]),
    .library(name: "SecretsInterface", targets: ["SecretsInterface"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser.git", .upToNextMajor(from: "1.8.2")),
    .package(url: "https://github.com/swiftlang/swift-format.git", .upToNextMajor(from: "603.0.0")),
    .package(url: "https://github.com/swiftlang/swift-syntax.git", .upToNextMajor(from: "603.0.2")),
    .package(url: "https://github.com/apple/swift-log.git", .upToNextMajor(from: "1.15.0")),
    swiftConfidentialSource.packageDependency, yamsSource.packageDependency,
  ],
  targets: [
    .executableTarget(
      name: "mpct",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"), .target(name: "EnvSubstCommand"),
        .target(name: "ObfuscateSecretsCommand", condition: .when(platforms: [.macOS])),
        .target(name: "ExportSecretsCommand"), .target(name: "SemanticVersion"), .target(name: "SemanticVersionMacro"),
      ],
      plugins: [.plugin(name: "SemanticVersionBuildToolPlugin")],
    ),

    // Dummy target to avoid optional compact map on dependencies for swift-confidential upstream w/o ConfidentialObfuscator
    .target(name: "Dummy"),

  ] + Targets.shell + Targets.envSubst + Targets.exportSecrets + Targets.importSecrets + Targets.obfuscateSecrets
    + Targets.semanticVersion + Targets.env + Targets.ci + Targets.hashicorpVaultReader + Targets.sharedLogger
    + Targets.secretsInterface,

  swiftLanguageModes: [.version(swiftLanguageVersion)],
)

for target in package.targets where target.type != .plugin && target.type != .test {
  var swiftSettings: [SwiftSetting] = target.swiftSettings ?? []
  // xcrun swift -print-supported-features

  // Swift 7 upcoming features
  swiftSettings.append(.enableUpcomingFeature("ExistentialAny"))
  swiftSettings.append(.enableUpcomingFeature("InternalImportsByDefault"))
  swiftSettings.append(.enableUpcomingFeature("MemberImportVisibility"))
  swiftSettings.append(.enableUpcomingFeature("InferIsolatedConformances"))
  swiftSettings.append(.enableUpcomingFeature("NonisolatedNonsendingByDefault"))
  swiftSettings.append(.enableUpcomingFeature("ImmutableWeakCaptures"))

  // Swift 6 optional features
  swiftSettings.append(.strictMemorySafety())
  swiftSettings.append(.enableExperimentalFeature("CheckImplementationOnly"))
  swiftSettings.append(.enableExperimentalFeature("AccessLevelOnImport"))

  target.swiftSettings = swiftSettings
}
