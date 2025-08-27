// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription
import CompilerPluginSupport

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
    tests: Bool = true,
    testsDependencies: [PackageDescription.Target.Dependency] = []
  ) -> [PackageDescription.Target] {
    var targets: [PackageDescription.Target] = [.target(name: name, dependencies: dependencies)]

    if tests {
      targets.append(
        .testTarget(
          name: "\(name)Tests",
          dependencies: [.target(name: name), .product(name: "Testing", package: "swift-testing")] + testsDependencies
        )
      )
    }

    return targets
  }

  static func commandBundle(
    name: String,
    dependencies: [PackageDescription.Target.Dependency] = [],
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

  static var shell: [PackageDescription.Target] { targetBundle(name: "Shell", tests: false) }

  static var envSubst: [PackageDescription.Target] {
    commandBundle(name: "EnvSubst", testsDependencies: [.target(name: "Shell")])
  }

  static var importSecrets: [PackageDescription.Target] {
    commandBundle(
      name: "ImportSecrets",
      dependencies: [.target(name: "EnvSubst"), .target(name: "Shell"), .product(name: "Yams", package: "Yams")],
      commandDependencies: [.target(name: "EnvSubstCommand"), .target(name: "ExportSecrets")]
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
      commandDependencies: [.target(name: "EnvSubstCommand")]
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
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
            .target(name: "SemanticVersion"),
          ]
        ),
      ]
  }
}

let package = Package(
  name: "mpct",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "mpct", targets: ["mpct"]), .library(name: "EnvSubst", targets: ["EnvSubst"]),
    .library(name: "Shell", targets: ["Shell"]), .library(name: "ImportSecrets", targets: ["ImportSecrets"]),
    .library(name: "ExportSecrets", targets: ["ExportSecrets"]),
    .library(name: "ObfuscateSecrets", targets: ["ObfuscateSecrets"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser.git", .upToNextMajor(from: "1.6.1")),
    .package(url: "https://github.com/swiftlang/swift-format.git", .upToNextMajor(from: "601.0.0")),
    .package(url: "https://github.com/swiftlang/swift-testing.git", .upToNextMajor(from: "6.1.1")),
    .package(url: "https://github.com/swiftlang/swift-syntax.git", "509.1.1"..<"602.0.0"),
    swiftConfidentialSource.packageDependency, yamsSource.packageDependency,
  ],
  targets: [
    .executableTarget(
      name: "mpct",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"), .target(name: "EnvSubstCommand"),
        .target(name: "ObfuscateSecretsCommand", condition: .when(platforms: [.macOS])),
        .target(name: "ImportSecretsCommand"), .target(name: "SemanticVersion")
      ],
      packageAccess: true,
      plugins: [.plugin(name: "SemanticVersionBuildToolPlugin")]
    ),

    // Dummy target to avoid optional compact map on dependencies for swift-confidential upstream w/o ConfidentialObfuscator
    .target(name: "Dummy"),

  ] + Targets.shell + Targets.envSubst + Targets.exportSecrets + Targets.importSecrets + Targets.obfuscateSecrets + Targets.semanticVersion,

  swiftLanguageModes: [
    .version(swiftLanguageVersion)
  ]
)

//for target in package.targets {
//  var settings = target.swiftSettings ?? []
//  settings.append(.enableExperimentalFeature("StrictConcurrency=complete"))
//  target.swiftSettings = settings
//}
