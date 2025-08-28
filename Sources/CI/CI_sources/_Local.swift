import ENV

/// Local CI.
extension CI {
  /// Local CI.
  struct Local {
    let type: CIType = CIType.local
    private let env: ENV

    init(env: ENV) { self.env = env }
  }
}

extension CI.Local: CIInterface {
  static func validateAsCurrentCI(_ environment: ENV = ENV.current) -> Bool {
    // Always return true, since this is the local machine.
    true
  }
}

extension CIType {
  /// Local CI type.
  public static let local: CIType = CIType(name: "Local")
}
