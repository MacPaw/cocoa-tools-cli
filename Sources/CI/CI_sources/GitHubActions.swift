import ENV

extension CI {
  /// Azure Pipelines CI.
  struct GitHubActions {
    let type: CIType = CIType.gitHubActions

    private let env: ENV

    init(env: ENV) { self.env = env }
  }
}

extension CI.GitHubActions: CIInterface {
  static func validateAsCurrentCI(_ environment: ENV = ENV.current) -> Bool { environment.GITHUB_ACTION != .none }
}

extension CIType {
  /// Azure Pipelines CI type.
  public static let gitHubActions: CIType = CIType(name: "GitHub Actions")
}
