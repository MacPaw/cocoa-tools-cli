import CI
import Foundation

/// Builds the OTLP metrics payload for a completed test run.
struct OTLPMetricsBuilder {
  /// Upper bucket boundaries, in milliseconds, for the test case duration histogram.
  ///
  /// These are the OpenTelemetry default explicit boundaries, which are tuned for millisecond
  /// latencies — hence the millisecond unit on the duration metrics.
  static let durationBucketBoundaries: [Double] = [
    0, 5, 10, 25, 50, 75, 100, 250, 500, 750, 1000, 2500, 5000, 7500, 10000,
  ]

  /// Whether metrics carry a `test.suite.name` breakdown.
  let isPerSuiteEnabled: Bool
  /// Timestamp recorded on every data point.
  let timestamp: Date

  /// Builds the export request for a test run.
  ///
  /// - Parameters:
  ///   - testRun: The completed test run.
  ///   - repository: Repository metadata for the run.
  ///   - cicd: Pipeline metadata for the run.
  ///   - ciProviderName: Name of the CI the run executed on.
  /// - Returns: The OTLP export request, ready to be encoded.
  func build(
    testRun: TestRun,
    repository: CI.Repository,
    cicd: CI.CICD,
    ciProviderName: String?,
  ) -> OTLPMetricsRequest {
    OTLPMetricsRequest(
      resourceMetrics: [
        OTLPMetricsRequest.ResourceMetrics(
          resource: OTLPMetricsRequest.Resource(
            attributes: resourceAttributes(repository: repository, cicd: cicd, ciProviderName: ciProviderName)
          ),
          scopeMetrics: [
            OTLPMetricsRequest.ScopeMetrics(
              scope: OTLPMetricsRequest.Scope(name: SemanticConventions.scopeName),
              metrics: metrics(for: testRun),
            )
          ],
        )
      ]
    )
  }

  // MARK: - Metrics

  /// Builds every metric derived from a test run.
  ///
  /// - Parameter testRun: The completed test run.
  /// - Returns: The metrics to export.
  private func metrics(for testRun: TestRun) -> [OTLPMetricsRequest.Metric] {
    [caseCountMetric(for: testRun), caseDurationMetric(for: testRun), runDurationMetric(for: testRun)]
  }

  /// Builds the test case count gauge, broken down by result status.
  ///
  /// A gauge rather than a counter: each CI run is a separate one-shot process whose counts
  /// restart at zero, which is precisely the pattern monotonic counter semantics forbid.
  ///
  /// - Parameter testRun: The completed test run.
  /// - Returns: The `cicd.test.case.count` metric.
  private func caseCountMetric(for testRun: TestRun) -> OTLPMetricsRequest.Metric {
    let dataPoints: [OTLPMetricsRequest.NumberDataPoint] = groups(for: testRun)
      .flatMap { group in
        TestRun.Suite.TestCase.Status.allCases.map { status in
          OTLPMetricsRequest.NumberDataPoint(
            attributes: group.attributes
              + [
                OTLPMetricsRequest.KeyValue(
                  key: SemanticConventions.Attribute.testCaseResultStatus,
                  stringValue: status.rawValue,
                )
              ],
            timeUnixNano: Self.unixNano(timestamp),
            asInt: String(group.testCases.count { $0.status == status }),
            asDouble: .none,
          )
        }
      }

    return OTLPMetricsRequest.Metric(
      name: SemanticConventions.Metric.testCaseCount,
      description: "Number of test cases executed, by result status.",
      unit: SemanticConventions.Unit.count,
      gauge: OTLPMetricsRequest.Gauge(dataPoints: dataPoints),
      histogram: .none,
    )
  }

  /// Builds the test case duration histogram.
  ///
  /// - Parameter testRun: The completed test run.
  /// - Returns: The `cicd.test.case.duration` metric.
  private func caseDurationMetric(for testRun: TestRun) -> OTLPMetricsRequest.Metric {
    let dataPoints: [OTLPMetricsRequest.HistogramDataPoint] = groups(for: testRun)
      .map { group in
        Self.histogramDataPoint(
          durations: group.testCases.map { $0.duration * 1000 },
          attributes: group.attributes,
          timestamp: timestamp,
        )
      }

    return OTLPMetricsRequest.Metric(
      name: SemanticConventions.Metric.testCaseDuration,
      description: "Distribution of individual test case durations.",
      unit: SemanticConventions.Unit.milliseconds,
      gauge: .none,
      histogram: OTLPMetricsRequest.Histogram(
        dataPoints: dataPoints,
        aggregationTemporality: OTLPMetricsRequest.AggregationTemporality.delta.rawValue,
      ),
    )
  }

  /// Builds the total run duration gauge.
  ///
  /// Always run-level: a per-suite breakdown of a single total would report the same number
  /// under several names.
  ///
  /// - Parameter testRun: The completed test run.
  /// - Returns: The `cicd.test.run.duration` metric.
  private func runDurationMetric(for testRun: TestRun) -> OTLPMetricsRequest.Metric {
    OTLPMetricsRequest.Metric(
      name: SemanticConventions.Metric.testRunDuration,
      description: "Total wall-clock duration of the test run.",
      unit: SemanticConventions.Unit.milliseconds,
      gauge: OTLPMetricsRequest.Gauge(dataPoints: [
        OTLPMetricsRequest.NumberDataPoint(
          attributes: [],
          timeUnixNano: Self.unixNano(timestamp),
          asInt: .none,
          asDouble: testRun.duration * 1000,
        )
      ]),
      histogram: .none,
    )
  }

  // MARK: - Grouping

  /// A set of test cases sharing the attributes their data points carry.
  private struct Group {
    /// Attributes shared by every data point derived from these test cases.
    let attributes: [OTLPMetricsRequest.KeyValue]
    /// The test cases in the group.
    let testCases: [TestRun.Suite.TestCase]
  }

  /// Splits a test run into the groups that become data points.
  ///
  /// With the per-suite breakdown enabled there is one group per suite; otherwise the whole run
  /// forms a single unattributed group.
  ///
  /// - Parameter testRun: The completed test run.
  /// - Returns: The groups to emit data points for.
  private func groups(for testRun: TestRun) -> [Group] {
    guard isPerSuiteEnabled else {
      return [Group(attributes: [], testCases: testRun.testCases)]
    }

    return testRun.suites.map { suite in
      Group(
        attributes: [
          OTLPMetricsRequest.KeyValue(
            key: SemanticConventions.Attribute.testSuiteName,
            stringValue: suite.name,
          )
        ],
        testCases: suite.testCases,
      )
    }
  }

  // MARK: - Resource

  /// Collects the resource attributes describing where the run executed.
  ///
  /// Attributes the CI cannot report are omitted rather than sent empty, so that a backend can
  /// tell "not reported" from "reported as blank".
  ///
  /// - Parameters:
  ///   - repository: Repository metadata for the run.
  ///   - cicd: Pipeline metadata for the run.
  ///   - ciProviderName: Name of the CI the run executed on.
  /// - Returns: The resource attributes to export.
  private func resourceAttributes(
    repository: CI.Repository,
    cicd: CI.CICD,
    ciProviderName: String?,
  ) -> [OTLPMetricsRequest.KeyValue] {
    let attributes: [(key: String, value: String?)] = [
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

  // MARK: - Helpers

  /// Buckets a set of values into an OTLP histogram data point.
  ///
  /// - Parameters:
  ///   - durations: The values to bucket, in milliseconds.
  ///   - attributes: Attributes qualifying the data point.
  ///   - timestamp: Timestamp recorded on the data point.
  /// - Returns: The histogram data point.
  private static func histogramDataPoint(
    durations: [Double],
    attributes: [OTLPMetricsRequest.KeyValue],
    timestamp: Date,
  ) -> OTLPMetricsRequest.HistogramDataPoint {
    let boundaries = durationBucketBoundaries
    var bucketCounts: [Int] = Array(repeating: 0, count: boundaries.count + 1)

    for duration in durations {
      let index = boundaries.firstIndex { duration <= $0 } ?? boundaries.count
      bucketCounts[index] += 1
    }

    return OTLPMetricsRequest.HistogramDataPoint(
      attributes: attributes,
      startTimeUnixNano: unixNano(timestamp),
      timeUnixNano: unixNano(timestamp),
      count: String(durations.count),
      sum: durations.reduce(0, +),
      bucketCounts: bucketCounts.map(String.init),
      explicitBounds: boundaries,
      min: durations.min(),
      max: durations.max(),
    )
  }

  /// Formats a date as nanoseconds since the Unix epoch.
  ///
  /// - Parameter date: The date to format.
  /// - Returns: The nanosecond timestamp, as the string OTLP's JSON mapping requires for 64-bit
  ///   integers.
  static func unixNano(_ date: Date) -> String {
    String(UInt64((date.timeIntervalSince1970 * 1_000_000_000).rounded()))
  }
}
