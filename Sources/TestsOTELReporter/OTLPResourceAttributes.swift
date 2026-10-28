import CI
import Foundation

/// Builds the resource attributes shared by the metrics and logs payloads.
///
/// Both signals describe the same run, so they must carry identical resources — Loki and Mimir
/// are joined on these attributes in a dashboard.
enum OTLPResourceAttributes {
  /// Collects the resource attributes describing where the run executed.
  ///
  /// Attributes the CI cannot report are omitted rather than sent empty, so that a backend can
  /// tell "not reported" from "reported as blank".
  ///
  /// - Parameters:
  ///   - serviceName: Value of `service.name`.
  ///   - repository: Repository metadata for the run.
  ///   - cicd: Pipeline metadata for the run.
  ///   - ciProviderName: Name of the CI the run executed on.
  /// - Returns: The resource attributes to export.
  static func make(
    serviceName: String,
    repository: CI.Repository,
    cicd: CI.CICD,
    ciProviderName: String?,
  ) -> [OTLPMetricsRequest.KeyValue] {
    let attributes: [(key: String, value: String?)] = [
      (SemanticConventions.Resource.serviceName, serviceName),
      (SemanticConventions.Resource.serviceInstanceID, instanceID(serviceName: serviceName, run: cicd.run)),
      (SemanticConventions.Resource.vcsProviderName, repository.provider),
      (SemanticConventions.Resource.vcsOwnerName, repository.organizationName),
      (SemanticConventions.Resource.vcsRepositoryName, repository.repositoryName),
      (SemanticConventions.Resource.cicdPipelineName, cicd.pipelineName),
      (SemanticConventions.Resource.cicdPipelineTaskName, cicd.run.taskName),
      (SemanticConventions.Resource.cicdPipelineStageName, cicd.run.stageName),
      (SemanticConventions.Resource.cicdPipelineRunID, cicd.run.id),
      (SemanticConventions.Resource.cicdPipelineRunNumber, cicd.run.number),
      (SemanticConventions.Resource.cicdPipelineRunURL, cicd.run.url?.absoluteString),
      (SemanticConventions.Resource.cicdProviderName, ciProviderName),
    ]

    return attributes.compactMap { key, value in
      value.map { OTLPMetricsRequest.KeyValue(key: key, stringValue: $0) }
    }
  }

  /// Builds `service.instance.id`, which tells one CI run's telemetry apart from another's.
  ///
  /// The CI model carries no retry attempt, so a re-run of the same pipeline run shares an id.
  ///
  /// - Parameters:
  ///   - serviceName: Value of `service.name`.
  ///   - run: Pipeline run metadata.
  /// - Returns: `<service>-<run number>`, falling back to the run id, or `nil` when the CI
  ///   reports neither.
  private static func instanceID(serviceName: String, run: CI.CICD.Run) -> String? {
    (run.number ?? run.id).map { "\(serviceName)-\($0)" }
  }
}
