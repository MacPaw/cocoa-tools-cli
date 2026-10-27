/// OpenTelemetry semantic convention names used by the reporter.
///
/// Names registered by OpenTelemetry are used verbatim. Names marked as MacPaw extensions have
/// no registry entry yet and are prefixed consistently with the registered ones so that a future
/// registration is a rename rather than a re-model.
enum SemanticConventions {
  /// Metric names.
  enum Metric {
    /// Number of test cases, broken down by result status.
    static let testCaseCount: String = "cicd.test.case.count"
    /// Distribution of individual test case durations.
    static let testCaseDuration: String = "cicd.test.case.duration"
    /// Total wall-clock duration of the test run.
    static let testRunDuration: String = "cicd.test.run.duration"
  }

  /// Data point attribute names.
  enum Attribute {
    /// Outcome of a test case — registered as `test.case.result.status`.
    static let testCaseResultStatus: String = "test.case.result.status"
    /// Name of the suite a test case belongs to — registered as `test.suite.name`.
    static let testSuiteName: String = "test.suite.name"
  }

  /// Resource attribute names.
  enum Resource {
    /// Version control provider hosting the repository.
    static let vcsProviderName: String = "vcs.provider.name"
    /// Organization, owner, or user the repository belongs to.
    static let vcsOwnerName: String = "vcs.owner.name"
    /// Repository name, without its organization component.
    static let vcsRepositoryName: String = "vcs.repository.name"
    /// Name of the pipeline definition.
    static let cicdPipelineName: String = "cicd.pipeline.name"
    /// Name of the task or job within the run.
    static let cicdPipelineTaskName: String = "cicd.pipeline.task.name"
    /// Identifier of the pipeline run.
    static let cicdPipelineRunID: String = "cicd.pipeline.run.id"
    /// Web URL of the pipeline run.
    static let cicdPipelineRunURL: String = "cicd.pipeline.run.url.full"
    /// Name of the stage within the run — a MacPaw extension, matching the CAS metrics labels.
    static let cicdPipelineStageName: String = "cicd.pipeline.stage.name"
    /// Human-facing sequence number of the pipeline run — a MacPaw extension.
    static let cicdPipelineRunNumber: String = "cicd.pipeline.run.number"
    /// Name of the CI provider the run executed on — a MacPaw extension.
    ///
    /// Derived from the detected CI rather than from a dedicated variable, so that it can never
    /// disagree with the CI the other attributes were read from.
    static let cicdProviderName: String = "cicd.provider.name"
  }

  /// Unit codes, using UCUM case-sensitive symbols.
  enum Unit {
    /// Milliseconds.
    static let milliseconds: String = "ms"
    /// A dimensionless count.
    static let count: String = "1"
  }

  /// Name reported as the instrumentation scope for every metric.
  static let scopeName: String = "mpct"
}
