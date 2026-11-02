# Grafana dashboards

Dashboard for the metrics and per-test-case traces pushed by `mpct tests report otel`:
[`dashboards/v2/tests-metrics.json`](dashboards/v2/tests-metrics.json) — test results, durations and line coverage
in one dashboard. It is a Grafana v2 dashboard resource (`apiVersion: dashboard.grafana.app/v2`).

Import it via **Dashboards → New → Import** and pick the Prometheus/Mimir
datasource (the dashboard refers to it through `${datasource}`) and the Tempo datasource
(`${tempo}`, used by the *Executed tests* and *Flaky tests* tables only).

Filters, chained like the Xcode CAS dashboard: Repository → Pipeline → Stage → Job, plus Test suite
and Coverage target.

## Assumptions

- Resource attributes (`vcs.repository.name`, `cicd.pipeline.*`) are available as metric labels,
  e.g. through Mimir's resource attribute promotion. Otherwise the filters stay empty.
- Metric names carry no unit suffixes (`cicd_test_case_count`, `cicd_test_case_duration_bucket`,
  `cicd_test_run_duration`, `cicd_test_coverage_line_count`). If the backend adds them
  (`_milliseconds`, `_ratio`), rename the metrics in the queries.
- The *Test suite* variable and the per-suite panels need the per-suite breakdown when reporting.
- The *Executed tests* table (pass rate is N/A for tests that were only skipped) reads the per-test-case **spans**
  that mpct sends to Tempo, not metrics: test names would otherwise be a series per test. It queries Tempo with TraceQL
  metrics (`count_over_time()` and `avg_over_time(span.test.case.duration)`, grouped by `span.test.suite.name` and
  `span.test.case.name`) and needs the spans to reach Tempo's OTLP intake (`--tempo-otlp-endpoint`, or a collector traces
  pipeline). **TraceQL metrics must be enabled on Tempo**: the `local-blocks` processor of the metrics generator, with
  `flush_to_storage` so queries beyond the most recent data are answered, and retention longer than the dashboard range.
  Counts sum every run in the range, pass rate is the share of passed among passed and failed executions (computed in the panel
  from the two counts, N/A when a test only ever skipped), and execution time is the mean per execution. The queries select
  on resource attributes (`resource.vcs.repository.name` and so on), so spans lacking an attribute that a filter selects (such
  as a CI that reports no stage) match no filter value, including *All*; the metrics-based panels do not have this limit.
- The *Executed tests* row is hidden while Repository, Pipeline, Stage, Job and Test suite are all on *All* (a conditional-rendering rule on the row, which needs Grafana 12 or newer), so its four Tempo queries do not run until a filter is narrowed; while it is hidden, a short text panel in its place asks you to pick a filter.
- The *Flaky tests* table lists the 100 tests that failed at least once in the range (a test that never passed shows a pass rate
  of 0%), ranked by failure count and then by pass rate (lowest first). TraceQL has no join, so the panel runs two queries
  (passed and failed counts per test) and Grafana transformations keep the tests that failed, fill passed with 0, compute the
  pass rate, sort and cut to 100. All tests are therefore read by Tempo before the cut; shorten the range to lower the load.
- Span start times are approximate: reports carry no start times, so mpct lays spans out back-to-back ending at the run
  timestamp. Durations are accurate. A back-dated `--timestamp` or `BUILD_FINISHTIME` must still fall inside Tempo's retention.
- Metrics are one-shot gauges, one sample per CI run, so queries use `*_over_time` rather than `rate`. mpct sends no
  `service.instance.id` (Mimir would make it the `instance` label), so runs of the same pipeline, stage and job share a series
  and each adds a sample. The queries also hold for a reporter that does send a per-run instance id.
- Test case counts (*Test cases*, *Failed test cases*, *Test cases by result*, *Failed test cases by suite*, *Per-suite results*) and the
  *Pass rate* panels sum every sample in the selected range (`sum_over_time`), so the sum covers every run, and a run pushed twice
  counts twice. Pass rate is the share of passed among passed and failed, skipped tests are not counted.
- *Average run duration* and *Run duration* are the mean over runs (`sum_over_time` / `count_over_time`), and the duration
  percentiles sum the histogram buckets of every run. Buckets are 0.1, 0.25, 0.5, 1 and 2.5 ms below 5 ms, then 5 ms up to 10 s, then 30 s, 1, 2, 5, 10 and 30 min (a slower test counts as 30 min); runs pushed before the finer buckets were added have none of them, so a percentile over a range that mixes both is only accurate for tests slower than 5 ms. Line coverage is not additive across runs, so the coverage panels take the
  latest run per series (`last_over_time`); *Per-target line coverage* shows the highest of those per target (`max`), without targets at 0% coverage.
- Mimir rejects a sample older than the newest one in its series unless `out_of_order_time_window` is set. Concurrent runs of
  one job, or a back-dated `--timestamp` / `BUILD_FINISHTIME`, can push out of order, so set the window (an hour or more) on the
  tenant.
- *Per-suite results* sums every run in the selected range (failed, total, and the pass rate of passed among passed and failed; mean
  duration is total time over total cases). The *Failed* column of *Executed tests* is 0 for tests that never failed, so the column
  is always present.
