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
