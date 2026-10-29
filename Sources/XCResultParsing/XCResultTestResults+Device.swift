extension XCResultTestResults {
  /// A device or simulator on which tests were executed.
  public struct Device: Codable, Sendable {
    /// The CPU architecture (for example `"arm64"`).
    public var architecture: String
    /// The unique device identifier.
    public var deviceId: String
    /// The human-readable device name.
    public var deviceName: String
    /// The device model name (for example `"iPhone 16 Pro"`).
    public var modelName: String
    /// The OS build string (for example `"24A5264n"`).
    public var osBuildNumber: String
    /// The OS version string (for example `"18.0"`).
    public var osVersion: String
    /// The target platform (for example `"iOS Simulator"`).
    public var platform: String
  }
}
