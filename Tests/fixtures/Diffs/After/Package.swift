// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "After",
  products: [
    .library(name: "Target2", targets: ["Target2"]),
    .library(name: "Target3", targets: ["Target3"]),
  ],
  targets: [
    .target(name: "Target2"),
    .testTarget(name: "Target2Tests", dependencies: [.target(name: "Target2")]),
    .target(name: "Target3"),
    .testTarget(name: "Target3Tests", dependencies: [.target(name: "Target3")]),
  ],
)
