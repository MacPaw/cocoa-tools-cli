// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Before",
  targets: [
    .target(name: "Target1"),
    .testTarget(name: "Target1Tests", dependencies: [.target(name: "Target1")]),
    .target(name: "Target2"),
    .testTarget(name: "Target2Tests", dependencies: [.target(name: "Target2")]),
  ],
)
