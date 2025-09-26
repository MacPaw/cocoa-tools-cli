import ENV

extension CI {
  /// Azure Pipelines CI.
  struct AzurePipelines {
    let type: CIType = CIType.azurePipelines

    private let _env: ENV
    let env: any CIEnvInterface

    init(env: ENV) {
      self._env = env
      self.env = Environment(env: env)
    }
  }
}

extension CI.AzurePipelines: CIInterface {
  static func validateAsCurrentCI(_ environment: ENV = ENV.current) -> Bool {
    environment.hasAll(
      keys: "AGENT_ID",
      "BUILD_SOURCEBRANCH",
      "BUILD_REPOSITORY_URI",
      "BUILD_REASON",
      "BUILD_REPOSITORY_NAME"
    )
  }

  var capabilities: CI.Capabilities { CI.Capabilities.azurePipelines }
}

extension CIType {
  /// Azure Pipelines CI type.
  public static let azurePipelines: CIType = CIType(name: "Azure Pipelines")
}

extension CI.Capabilities {
  /// Azure Pipelines capabilities.
  static let azurePipelines: CI.Capabilities = CI.Capabilities(canExportSecrets: true)
}

extension CI.AzurePipelines {
  struct Environment {
    let env: ENV

    init(env: ENV = .current) { self.env = env }
  }
}

extension CI.AzurePipelines.Environment: CIEnvInterface {
  private func _setVariable(name: String, value: String, isSecret: Bool, isOutput: Bool) {
    print("Setting variable \(name)")
    print("##vso[task.setvariable variable=\(name);issecret=\(isSecret);isoutput=\(isOutput)]\(value)")
  }

  func setSecret(name: String, value: String, isOutput: Bool) throws {
    _setVariable(name: name, value: value, isSecret: true, isOutput: isOutput)
  }

  func setVariable(name: String, value: String, isOutput: Bool) throws {
    _setVariable(name: name, value: value, isSecret: false, isOutput: isOutput)
  }
}
