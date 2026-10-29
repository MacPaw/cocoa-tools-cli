import ENV
import Foundation

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
      "BUILD_REPOSITORY_NAME",
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
    print("Setting variable '\(name)' (isSecret: \(isSecret), isOutput: \(isOutput))")
    print("##vso[task.setvariable variable=\(name);issecret=\(isSecret);isoutput=\(isOutput)]\(value)")
  }

  func setSecret(name: String, value: String, isOutput: Bool) throws {
    _setVariable(name: name, value: value, isSecret: true, isOutput: isOutput)
  }

  func setVariable(name: String, value: String, isOutput: Bool) throws {
    _setVariable(name: name, value: value, isSecret: false, isOutput: isOutput)
  }
}

extension CI.AzurePipelines {
  /// Source control repository metadata for the current run.
  var repository: CI.Repository {
    CI.Repository(
      organizationName: _env.firstNonEmpty(of: "ORGANIZATION_NAME")
        ?? collectionURL.flatMap(Self.organizationName(fromCollectionURL:)),
      repositoryName: _env.firstNonEmpty(of: "REPOSITORY_NAME", "BUILD_REPOSITORY_NAME")
        .map(CI.repositoryName(fromSlug:)),
      provider: _env.firstNonEmpty(of: "BUILD_REPOSITORY_PROVIDER").map { $0.lowercased() },
    )
  }

  /// Pipeline metadata for the current run.
  var cicd: CI.CICD {
    CI.CICD(
      pipelineName: _env.firstNonEmpty(of: "BUILD_DEFINITIONNAME"),
      run: CI.CICD.Run(
        id: _env.firstNonEmpty(of: "BUILD_BUILDID"),
        number: _env.firstNonEmpty(of: "BUILD_BUILDNUMBER"),
        taskName: _env.firstNonEmpty(of: "SYSTEM_JOBDISPLAYNAME"),
        stageName: _env.firstNonEmpty(of: "SYSTEM_STAGEDISPLAYNAME"),
        url: runURL,
      ),
    )
  }

  /// The Azure DevOps collection URL of the current run, if reported.
  private var collectionURL: URL? {
    _env.firstNonEmpty(of: "SYSTEM_COLLECTIONURI", "SYSTEM_TEAMFOUNDATIONCOLLECTIONURI").flatMap(URL.init(string:))
  }

  /// Web URL of the current build, assembled from the collection URL, project, and build identifier.
  private var runURL: URL? {
    guard
      let collectionURL,
      let project = _env.firstNonEmpty(of: "SYSTEM_TEAMPROJECT"),
      let buildID = _env.firstNonEmpty(of: "BUILD_BUILDID")
    else { return .none }

    var components: URLComponents? = URLComponents(
      url: collectionURL.appendingPathComponent(project).appendingPathComponent("_build")
        .appendingPathComponent(
          "results"
        ),
      resolvingAgainstBaseURL: false,
    )
    components?.queryItems = [URLQueryItem(name: "buildId", value: buildID)]

    return components?.url
  }

  /// Extracts the organization name from an Azure DevOps collection URL.
  ///
  /// Collection URLs take the form `https://dev.azure.com/{organization}/`, where the
  /// organization is the last non-empty path component, or the legacy
  /// `https://{organization}.visualstudio.com/`, where it is the first host label.
  ///
  /// - Parameter collectionURL: The collection URL reported by Azure Pipelines.
  /// - Returns: The organization name, or `nil` when the URL carries neither form.
  private static func organizationName(fromCollectionURL collectionURL: URL) -> String? {
    if let host = collectionURL.host?.lowercased(), host.hasSuffix(".visualstudio.com") {
      return host.split(separator: ".").first.map(String.init)
    }
    return collectionURL.pathComponents.last { $0 != "/" && !$0.isEmpty }
  }
}
