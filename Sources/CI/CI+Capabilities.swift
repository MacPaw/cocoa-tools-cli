extension CI {
  /// CI capabilities.
  public struct Capabilities {
    /// Whether the CI can securely export secrets.
    public var canExportSecrets: Bool

    /// Initialize CI capabilities.
    ///
    /// - Parameter canExportSecrets: Whether the CI can securely export secrets.
    public init(canExportSecrets: Bool) { self.canExportSecrets = canExportSecrets }
  }
}

extension CI.Capabilities: Sendable {}
extension CI.Capabilities: Equatable {}
