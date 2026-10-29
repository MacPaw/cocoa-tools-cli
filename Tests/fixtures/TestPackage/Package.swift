// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "TestPackage",
  products: [
    .library(name: "TargetA", targets: ["TargetA"]),
    .library(name: "TargetB", targets: ["TargetB"]),
  ],
  targets: [
    .target(name: "TargetA"),
    .testTarget(name: "TargetATests", dependencies: [.target(name: "TargetA")]),
    .target(name: "TargetB"),
    .testTarget(name: "TargetBTests", dependencies: [.target(name: "TargetB")]),
    .testTarget(name: "RecordingTests"),
  ],
)
