# Grafana dashboards

Dashboard for the metrics and per-test-case logs pushed by `mpct tests report otel`:
[`dashboards/v2/tests-metrics.json`](dashboards/v2/tests-metrics.json) — test results, durations and line coverage
in one dashboard. It is a Grafana v2 dashboard resource (`apiVersion: dashboard.grafana.app/v2`).

Import it via **Dashboards → New → Import** and pick the Prometheus/Mimir
datasource (the dashboard refers to it through `${datasource}`) and the Loki datasource
(`${loki}`, used by the *Executed tests* table only).

Filters, chained like the Xcode CAS dashboard: Repository → Pipeline → Stage → Job, plus Test suite
and Coverage target.

## Assumptions

- Resource attributes (`vcs.repository.name`, `cicd.pipeline.*`) are available as metric labels,
  e.g. through Mimir's resource attribute promotion. Otherwise the filters stay empty.
- Metric names carry no unit suffixes (`cicd_test_case_count`, `cicd_test_case_duration_bucket`,
  `cicd_test_run_duration`, `cicd_test_coverage_line_count`). If the backend adds them
  (`_milliseconds`, `_ratio`), rename the metrics in the queries.
- The *Test suite* variable and the per-suite panels need the per-suite breakdown when reporting.
- The *Executed tests* table (pass rate is N/A for tests that were only skipped) reads the per-test-case **logs**
  that mpct sends to Loki, not metrics: test names would otherwise be a series per test. It queries Loki with LogQL
  and needs the logs to reach Loki's OTLP intake (`--loki-otlp-endpoint`, or a collector logs pipeline). Loki turns
  the OTLP log attributes into structured metadata (`test_case_name`, `test_suite_name`, `test_case_result_status`,
  `test_case_duration`). `service_name`, `vcs_repository_name` and `cicd_pipeline_name` are indexed (see the ops Loki config), so the
  queries select on `service_name="macpaw-test"` and the repository inside the stream selector and filter on the rest after it;
  a broad selector such as `service_name=~".+"` would read every service's logs.
  Counts sum every run in the dashboard's range, pass rate is the share of passed among passed and failed executions (N/A when a
  test only ever skipped), and execution time is the mean per execution. Loki splits a query into 24-hour pieces, so a long
  range multiplies the request count; if the panel warns `too many outstanding requests`, shorten the dashboard range.
  Loki rejects log lines older than its `reject_old_samples_max_age` (a week by default), so a back-dated
  `--timestamp` or `BUILD_FINISHTIME` outside that window drops the logs while the metrics still land.
- Metrics are one-shot gauges, one sample per CI run, so queries use `*_over_time` rather than `rate`. mpct sends no
  `service.instance.id` (Mimir would make it the `instance` label), so runs of the same pipeline, stage and job share a series
  and each adds a sample. The queries also hold for a reporter that does send a per-run instance id.
- Test case counts (*Test cases*, *Failed test cases*, *Test cases by result*, *Failed test cases by suite*, *Per-suite results*) and the
  *Pass rate* panels sum every sample in the selected range (`sum_over_time`), so the sum covers every run, and a run pushed twice
  counts twice. Pass rate is the share of passed among passed and failed, skipped tests are not counted.
- *Average run duration* and *Run duration* are the mean over runs (`sum_over_time` / `count_over_time`), and the duration
  percentiles sum the histogram buckets of every run. Line coverage is not additive across runs, so the coverage panels take the
  latest run per series (`last_over_time`); *Per-target line coverage* shows the highest of those per target (`max`).
- Mimir rejects a sample older than the newest one in its series unless `out_of_order_time_window` is set. Concurrent runs of
  one job, or a back-dated `--timestamp` / `BUILD_FINISHTIME`, can push out of order, so set the window (an hour or more) on the
  tenant.
- *Per-suite results* sums every run in the selected range (failed, total, and the pass rate of passed among passed and failed; mean
  duration is total time over total cases). The *Failed* column of *Executed tests* is 0 for tests that never failed, so the column
  is always present.
