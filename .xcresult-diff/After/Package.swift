// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "After",
  targets: [
    .target(name: "Target2"),
    .testTarget(name: "Target2Tests", dependencies: [.target(name: "Target2")]),
    .target(name: "Target3"),
    .testTarget(name: "Target3Tests", dependencies: [.target(name: "Target3")]),
  ],
)
