import ENV

/// Local CI.
extension CI {
  /// Local CI.
  struct Local {
    let type: CIType = CIType.local
    private let _env: ENV
    let env: any CIEnvInterface

    init(env: ENV) {
      self._env = env
      self.env = Environment(env: env)
    }
  }
}

extension CI.Local: CIInterface {
  static func validateAsCurrentCI(_ environment: ENV = ENV.current) -> Bool {
    // Always return true, since this is the local machine.
    true
  }

  var capabilities: CI.Capabilities { CI.Capabilities.local }
}

extension CIType {
  /// Local CI type.
  public static let local: CIType = CIType(name: "Local")
}

extension CI.Capabilities {
  /// Local capabilities.
  static let local: CI.Capabilities = CI.Capabilities(canExportSecrets: false)
}

extension CI.Local { struct Environment { let env: ENV } }

extension CI.Local.Environment: CIEnvInterface {
  func setSecret(name: String, value: String, isOutput: Bool) throws {
    // No-op
  }

  func setVariable(name: String, value: String, isOutput: Bool) throws {
    // No-op
  }
}
