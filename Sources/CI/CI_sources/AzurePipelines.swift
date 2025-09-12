import ENV

extension CI {
  /// Azure Pipelines CI.
  struct AzurePipelines {
    let type: CIType = CIType.azurePipelines

    private let env: ENV

    init(env: ENV) { self.env = env }
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
}

extension CIType {
  /// Azure Pipelines CI type.
  public static let azurePipelines: CIType = CIType(name: "Azure Pipelines")
}
