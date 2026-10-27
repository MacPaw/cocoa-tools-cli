import ENV
import Foundation

extension CI {
  /// Azure Pipelines CI.
  struct GitHubActions {
    let type: CIType = CIType.gitHubActions

    private let _env: ENV
    @inline(__always)
    private var fileManager: FileManager { FileManager.default }

    let env: any CIEnvInterface

    init(env: ENV) {
      self._env = env
      self.env = CI.GitHubActions.Environment(env: env)
    }
  }
}

extension CI.GitHubActions: CIInterface {
  static func validateAsCurrentCI(_ environment: ENV = .current) -> Bool { environment.GITHUB_ACTION != .none }

  var capabilities: CI.Capabilities { CI.Capabilities.gitHubActions }
}

extension CIType {
  /// Azure Pipelines CI type.
  public static let gitHubActions: CIType = CIType(name: "GitHub Actions")
}

extension CI.Capabilities {
  /// GitHub Actions capabilities.
  static let gitHubActions: CI.Capabilities = CI.Capabilities(canExportSecrets: true)
}

extension CI.GitHubActions {
  struct Environment: CIEnvInterface {
    let env: ENV

    init(env: ENV = .current) { self.env = env }
  }
}

extension CI.GitHubActions.Environment {
  var fileManager: FileManager { FileManager.default }

  private func _appendValueToFile(name: String, value: String, isOutput: Bool) throws {
    guard let envFile = isOutput ? env.GITHUB_OUTPUT : env.GITHUB_ENV else {
      preconditionFailure("GITHUB_ENV is not set")
    }
    let envFileURL = URL(fileURLWithPath: envFile)
    let newContents =
      if value.contains("\n") { "\(name)<<EOF\n\(value)\nEOF\n" }
      else { "\(name)=\(value)\n" }
    if fileManager.isReadableFile(atPath: envFileURL.path) {
      let fileContents = try String(contentsOf: envFileURL, encoding: .utf8)
      let newContents = fileContents.appending(newContents)
      try newContents.write(to: envFileURL, atomically: true, encoding: .utf8)
    }
    else {
      try fileManager.createDirectory(at: envFileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      try newContents.write(to: envFileURL, atomically: true, encoding: .utf8)
    }
  }

  func setSecret(name: String, value: String, isOutput: Bool) throws {
    print("::add-mask::\(name)")
    try _appendValueToFile(name: name, value: value, isOutput: isOutput)
  }

  func setVariable(name: String, value: String, isOutput: Bool) throws {
    try _appendValueToFile(name: name, value: value, isOutput: isOutput)
  }
}

extension CI.GitHubActions {
  /// Source control repository metadata for the current run.
  var repository: CI.Repository {
    CI.Repository(
      organizationName: _env.firstNonEmpty(of: "ORGANIZATION_NAME", "GITHUB_REPOSITORY_OWNER"),
      repositoryName: _env.firstNonEmpty(of: "REPOSITORY_NAME")
        ?? _env.firstNonEmpty(of: "GITHUB_REPOSITORY").map(CI.repositoryName(fromSlug:)),
      provider: "github",
    )
  }

  /// Pipeline metadata for the current run.
  var cicd: CI.CICD {
    CI.CICD(
      pipelineName: _env.firstNonEmpty(of: "GITHUB_WORKFLOW"),
      run: CI.CICD.Run(
        id: _env.firstNonEmpty(of: "GITHUB_RUN_ID"),
        number: _env.firstNonEmpty(of: "GITHUB_RUN_NUMBER"),
        taskName: _env.firstNonEmpty(of: "GITHUB_JOB"),
        stageName: .none,
        url: runURL,
      ),
    )
  }

  /// Web URL of the current workflow run, assembled from the server, repository slug, and run identifier.
  private var runURL: URL? {
    guard
      let serverURL = _env.firstNonEmpty(of: "GITHUB_SERVER_URL"),
      let slug = _env.firstNonEmpty(of: "GITHUB_REPOSITORY"),
      let runID = _env.firstNonEmpty(of: "GITHUB_RUN_ID"),
      let base = URL(string: serverURL)
    else { return .none }

    return
      base
      .appendingPathComponent(slug)
      .appendingPathComponent("actions")
      .appendingPathComponent("runs")
      .appendingPathComponent(runID)
  }
}
