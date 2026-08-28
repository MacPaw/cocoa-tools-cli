/// Top-level result from `xcresulttool get test-results tests`.
public struct TestResults: Codable, Sendable {
  /// The physical devices or simulators on which the tests ran.
  public var devices: [Device]
  /// The root-level test grouping nodes (suites, test cases, etc.).
  public var testNodes: [TestNode]
}

/// A device or simulator on which tests were executed.
public struct Device: Codable, Sendable {
  /// The CPU architecture (e.g. `"arm64"`).
  public var architecture: String
  /// The unique device identifier.
  public var deviceId: String
  /// The human-readable device name.
  public var deviceName: String
  /// The device model name (e.g. `"iPhone 16 Pro"`).
  public var modelName: String
  /// The OS build string (e.g. `"24A5264n"`).
  public var osBuildNumber: String
  /// The OS version string (e.g. `"18.0"`).
  public var osVersion: String
  /// The target platform (e.g. `"iOS Simulator"`).
  public var platform: String
}

/// A node in the hierarchical test result tree (suite, test case, or assertion).
public struct TestNode: Codable, Sendable {
  /// Display name of this node.
  public var name: String
  /// The kind of this node (e.g. `"Test Suite"`, `"Test Case"`).
  public var nodeType: String
  /// The pass/fail status (e.g. `"Passed"`, `"Failed"`).
  public var result: String
  /// Human-readable duration string.
  public var duration: String?
  /// Duration in seconds as a floating-point value.
  public var durationInSeconds: Double?
  /// Stable test identifier used to address a specific test case.
  public var nodeIdentifier: String?
  /// URL-encoded variant of `nodeIdentifier`.
  public var nodeIdentifierURL: String?
  /// Child nodes (sub-suites or individual test cases).
  public var children: [TestNode]?
}
