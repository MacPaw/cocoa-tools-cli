public import Foundation

/// Continuous integration pipeline metadata, as reported by the current CI.
extension CI {
  /// Metadata about the pipeline the current run belongs to.
  ///
  /// All properties are optional: a CI that cannot report a value leaves it `nil`,
  /// and consumers are expected to omit it rather than substitute a placeholder.
  ///
  /// The CI provider itself is intentionally not represented here — it is already
  /// available as ``CIInterface/type``.
  public struct CICD {
    /// Name of the pipeline definition, such as an Azure Pipelines definition or a GitHub Actions workflow.
    public var pipelineName: String?
    /// Metadata about the individual pipeline run.
    public var run: Run

    /// Initializes pipeline metadata.
    ///
    /// - Parameters:
    ///   - pipelineName: Name of the pipeline definition.
    ///   - run: Metadata about the individual pipeline run.
    public init(pipelineName: String? = .none, run: Run = Run()) {
      self.pipelineName = pipelineName
      self.run = run
    }
  }
}

extension CI.CICD {
  /// Metadata about a single run of a pipeline.
  public struct Run {
    /// Identifier of the pipeline run, unique within the pipeline.
    public var id: String?
    /// Human-facing sequence number or version of the pipeline run.
    public var number: String?
    /// Name of the task or job within the run that is currently executing.
    public var taskName: String?
    /// Name of the stage within the run that is currently executing.
    public var stageName: String?
    /// Web URL at which the pipeline run can be viewed.
    public var url: URL?

    /// Initializes pipeline run metadata.
    ///
    /// - Parameters:
    ///   - id: Identifier of the pipeline run, unique within the pipeline.
    ///   - number: Human-facing sequence number or version of the pipeline run.
    ///   - taskName: Name of the task or job within the run that is currently executing.
    ///   - stageName: Name of the stage within the run that is currently executing.
    ///   - url: Web URL at which the pipeline run can be viewed.
    public init(
      id: String? = .none,
      number: String? = .none,
      taskName: String? = .none,
      stageName: String? = .none,
      url: URL? = .none,
    ) {
      self.id = id
      self.number = number
      self.taskName = taskName
      self.stageName = stageName
      self.url = url
    }
  }
}

extension CI.CICD: Sendable {}
extension CI.CICD: Equatable {}
extension CI.CICD.Run: Sendable {}
extension CI.CICD.Run: Equatable {}
