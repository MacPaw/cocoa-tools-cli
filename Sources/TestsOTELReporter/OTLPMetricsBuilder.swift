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
  /// Whether metrics carry a `test.case.name` breakdown.
  let isPerTestEnabled: Bool
  /// Timestamp recorded on every data point.
  let timestamp: Date

  /// Builds the export request for a test run and its coverage.
  ///
  /// - Parameters:
  ///   - testRun: The completed test run, if there is one to report.
  ///   - lineCoverage: Line coverage of the run, if there is any to report.
  ///   - repository: Repository metadata for the run.
  ///   - cicd: Pipeline metadata for the run.
  ///   - ciProviderName: Name of the CI the run executed on.
  /// - Returns: The OTLP export request, ready to be encoded.
  func build(
    testRun: TestRun?,
    lineCoverage: LineCoverage?,
    repository: CI.Repository,
    cicd: CI.CICD,
    ciProviderName: String?,
  ) -> OTLPMetricsRequest {
    let resource = resourceAttributes(repository: repository, cicd: cicd, ciProviderName: ciProviderName)
    let labels = Self.dataPointLabels(from: resource)

    return OTLPMetricsRequest(
      resourceMetrics: [
        OTLPMetricsRequest.ResourceMetrics(
          resource: OTLPMetricsRequest.Resource(
            attributes: resource
          ),
          scopeMetrics: [
            OTLPMetricsRequest.ScopeMetrics(
              scope: OTLPMetricsRequest.Scope(name: SemanticConventions.scopeName),
              metrics: ((testRun.map(metrics(for:)) ?? []) + (lineCoverage.map(lineCoverageMetrics(for:)) ?? []))
                .map { Self.adding(labels, to: $0) },
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
  /// Cumulative rather than delta: Prometheus-compatible backends (Mimir) reject delta histograms.
  /// Each run is a one-shot process, so its cumulative total equals its own measurements.
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
        aggregationTemporality: OTLPMetricsRequest.AggregationTemporality.cumulative.rawValue,
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

  // MARK: - Line coverage

  /// Builds every metric derived from line coverage.
  ///
  /// A gauge for the same reason as the test case count: each CI run is a one-shot process. The
  /// covered and uncovered lines are disjoint, so their sum is the executable line count and a
  /// ratio can be derived without weighting targets by size. There is deliberately no run-level
  /// total, which would double-count in a sum over the target attribute.
  ///
  /// - Parameter lineCoverage: Line coverage of the run.
  /// - Returns: The metrics to export.
  private func lineCoverageMetrics(for lineCoverage: LineCoverage) -> [OTLPMetricsRequest.Metric] {
    let dataPoints: [OTLPMetricsRequest.NumberDataPoint] = lineCoverage.targets.flatMap { target in
      [
        (SemanticConventions.LineCoverageStatus.covered, target.coveredLines),
        (SemanticConventions.LineCoverageStatus.uncovered, target.uncoveredLines),
      ]
      .map { status, lines in
        OTLPMetricsRequest.NumberDataPoint(
          attributes: [
            OTLPMetricsRequest.KeyValue(
              key: SemanticConventions.Attribute.testLineCoverageTargetName,
              stringValue: target.name,
            ),
            OTLPMetricsRequest.KeyValue(
              key: SemanticConventions.Attribute.testLineCoverageStatus,
              stringValue: status,
            ),
          ],
          timeUnixNano: Self.unixNano(timestamp),
          asInt: String(lines),
          asDouble: .none,
        )
      }
    }

    return [
      OTLPMetricsRequest.Metric(
        name: SemanticConventions.Metric.testLineCoverageCount,
        description: "Number of executable lines, by whether they were covered, per target.",
        unit: SemanticConventions.Unit.lines,
        gauge: OTLPMetricsRequest.Gauge(dataPoints: dataPoints),
        histogram: .none,
      )
    ]
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
  /// With the per-test breakdown enabled there is one group per test case name within its suite
  /// (a name repeated by parameterized cases forms one group). With only the per-suite breakdown
  /// there is one group per suite; otherwise the whole run forms a single unattributed group.
  ///
  /// - Parameter testRun: The completed test run.
  /// - Returns: The groups to emit data points for.
  private func groups(for testRun: TestRun) -> [Group] {
    if isPerTestEnabled {
      return testRun.suites.flatMap { suite in
        var names: [String] = []
        for testCase in suite.testCases where !names.contains(testCase.name) { names.append(testCase.name) }

        return names.map { name in
          Group(
            attributes: (isPerSuiteEnabled ? [suiteAttribute(suite.name)] : [])
              + [
                OTLPMetricsRequest.KeyValue(key: SemanticConventions.Attribute.testCaseName, stringValue: name)
              ],
            testCases: suite.testCases.filter { $0.name == name },
          )
        }
      }
    }

    guard isPerSuiteEnabled else {
      return [Group(attributes: [], testCases: testRun.testCases)]
    }

    return testRun.suites.map { suite in
      Group(
        attributes: [suiteAttribute(suite.name)],
        testCases: suite.testCases,
      )
    }
  }

  /// Builds the suite name attribute.
  ///
  /// - Parameter name: The suite name.
  /// - Returns: The `test.suite.name` attribute.
  private func suiteAttribute(_ name: String) -> OTLPMetricsRequest.KeyValue {
    OTLPMetricsRequest.KeyValue(key: SemanticConventions.Attribute.testSuiteName, stringValue: name)
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

  /// Resource attributes that are also sent on every data point.
  ///
  /// Backends only turn resource attributes into metric labels when configured to, so without
  /// these the dashboard filters have nothing to select on. Run-unique values (run id, number, URL)
  /// are left on the resource, as labels they would create a series per run.
  private static let labelledResourceAttributes: Set<String> = [
    SemanticConventions.Resource.vcsRepositoryName,
    SemanticConventions.Resource.cicdPipelineName,
    SemanticConventions.Resource.cicdPipelineStageName,
    SemanticConventions.Resource.cicdPipelineTaskName,
  ]

  /// Picks the resource attributes that are repeated on data points.
  ///
  /// - Parameter resource: The resource attributes of the export.
  /// - Returns: The attributes to add to every data point.
  private static func dataPointLabels(from resource: [OTLPMetricsRequest.KeyValue]) -> [OTLPMetricsRequest.KeyValue] {
    resource.filter { labelledResourceAttributes.contains($0.key) }
  }

  /// Adds attributes to every data point of a metric.
  ///
  /// - Parameters:
  ///   - labels: The attributes to add.
  ///   - metric: The metric to extend.
  /// - Returns: The metric with the attributes on each data point.
  private static func adding(_ labels: [OTLPMetricsRequest.KeyValue], to metric: OTLPMetricsRequest.Metric)
    -> OTLPMetricsRequest.Metric
  {
    var metric = metric
    if var gauge = metric.gauge {
      gauge.dataPoints = gauge.dataPoints.map { dataPoint in
        var dataPoint = dataPoint
        dataPoint.attributes += labels
        return dataPoint
      }
      metric.gauge = gauge
    }
    if var histogram = metric.histogram {
      histogram.dataPoints = histogram.dataPoints.map { dataPoint in
        var dataPoint = dataPoint
        dataPoint.attributes += labels
        return dataPoint
      }
      metric.histogram = histogram
    }
    return metric
  }

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
