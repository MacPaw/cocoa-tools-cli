# mpct — MacPaw Cocoa Tools CLI

Swift CLI for macOS CI/CD tooling. Modular SPM package, Swift 6.1, macOS 15+.

## Modules

| Module | Purpose |
|---|---|
| `ENV` | `@dynamicMemberLookup` wrapper around `ProcessInfo` environment |
| `CI` | CI platform abstraction: GitHub Actions, Azure Pipelines, local |
| `Shell` | Process execution, `which`, `mise` CLI integration |
| `EnvSubst` | POSIX-compatible `$VAR` / `${VAR:-default}` substitution engine |
| `SecretsInterface` | Protocol layer for secret provider implementations |
| `SecretsInterfaceTesting` | Mock implementations for use in tests |
| `HashiCorpVaultReader` | HashiCorp Vault HTTP client (KV v1/v2, AWS engine) |
| `ImportSecrets` | Loads secrets from 1Password CLI or HashiCorp Vault via YAML config |
| `ExportSecrets` | Writes secrets to dotenv / mise / stdout / CI env |
| `ObfuscateSecrets` | Envsubst + `swift-confidential` obfuscation (macOS only) |
| `SemanticVersion` | SemVer 2.0 type + build-tool plugin embedding `.config/semantic-version/version` |
| `SharedLogger` | `swift-log` singleton; all targets depend on it automatically |
| `XCResultParsing` | `xcresulttool` CLI wrapper + Codable types for coverage and test results |
| `XUnitParser` | xUnit XML parser — `TestSuites.load(from:)` → `TestSuites`/`TestSuite`/`TestCase`/`Failure` |
| `LLVMCoverageParser` | LLVM coverage JSON parser — `LLVMCoverage.load(from:)` → `LLVMCoverage`/`File`/`Summary`/`Stat` |
| `TestsCoverageCommand` | `mpct tests coverage parse` — exports and prints coverage report |
| `TestsResultsCommand` | `mpct tests results parse` — fetches and prints test result summary |
| `TestsOTELReporter` | Neutral `TestRun` model + OTLP/HTTP JSON metrics payload and push (no OpenTelemetry SDK dependency) |
| `TestsOTELReporterCommand` | `mpct tests report otel` — parses a report and pushes its metrics |

## CLI

```
mpct [--verbose]
  envsubst          Substitute env vars in a file or stdin
  secrets
    export          Fetch secrets → --destination (dotenv | mise | stdout | ci)
    obfuscate       Envsubst + swift-confidential (macOS only)
  tests
    coverage
      parse         Export xcresult coverage → CoverageReport
    results
      parse         Fetch xcresult test results → TestResults
    report
      otel          Push test metrics to an OpenTelemetry collector (OTLP/HTTP)
```

### `tests report otel`

Takes exactly one of `--xcresult` (macOS only) or `--xunit`. Endpoint and headers fall back to
`OTEL_EXPORTER_OTLP_ENDPOINT` / `OTEL_EXPORTER_OTLP_HEADERS`; there is no default endpoint.
`OTEL_EXPORTER_OTLP_ENDPOINT` is a **base** URL — `v1/metrics` is appended, per the OTLP spec.

Emits three gauges/histograms, all with millisecond durations: `cicd.test.case.count`
(attributed by `test.case.result.status`), `cicd.test.case.duration`, `cicd.test.run.duration`.
Resource attributes come from `CI.current.repository` / `.cicd`.

## Commands

Use `mise tasks run` (not `mise run`). Nested tasks use `:` as separator.

```bash
mise tasks run build                # Build
mise tasks run test                 # Run all tests
mise tasks run test:swift           # Run Swift tests only
mise tasks run fixtures:generate    # Regenerate lcov, llvm-diff, xcresult fixtures
mise tasks run format               # Format Swift, YAML, shell
mise tasks run lint                 # Lint Swift, YAML, shell
make bootstrap                      # First-time setup (installs mise and tools)
```

### Test fixtures

All generated fixtures live under `Tests/*/fixtures/` and are regenerated with:

```bash
mise tasks run fixtures:generate
```

The task builds from `Tests/fixtures/TestPackage` (two source targets, a recording test target) and `Tests/fixtures/Diffs/Before` + `After`. It regenerates:
- `Tests/LLVMCoverageParserTests/fixtures/lcov.json`
- `Tests/LLVMCoverageParserTests/fixtures/llvm-diff-before.json`
- `Tests/LLVMCoverageParserTests/fixtures/llvm-diff-after.json`
- `Tests/XCResultParsingTests/fixtures/test-package.xcresult`
- `Tests/XCResultParsingTests/fixtures/coverage-diff.json`

`Tests/XUnitReportTests/fixtures/test-package-xUnit-swift-testing.xml` is hand-maintained — `swift test --xunit-output` does not write the file when any test fails (Swift 6.4), so it cannot be regenerated automatically when `RecordingTests` intentionally fails.

## Package conventions

- Every target is created with `targetBundle(...)` in `Package.swift`, which automatically adds `SharedLogger` as a dependency.
- Command targets (e.g., `ExportSecretsCommand`) also get `ArgumentParser` added automatically.
- Conditional (macOS-only) targets use `#if os(macOS)` / `.when(platforms: [.macOS])`.
- **Multiple Package manifests**: the repo has `Package.swift` and `Package@swift-6.3.swift`. When adding or modifying targets, update ALL manifests. Check with `ls Package*.swift`.
- **All public declarations must have `///` doc comments** — types, properties, methods, and initializers.

## Testing conventions

Always invoke the `/new-module` skill before writing tests to pick up the current conventions. Key rules:
- Name the system under test `sut`.
- Method name: `test_functionOrProperty_testExplanation`.
- `@Test` label: `"functionOrProperty testExplanation"` (no `test_` prefix).
- Structure each test with `// GIVEN`, `// WHEN`, `// THEN` inline comments.
- Test outputs, not internal behaviour.

## Release

Bump the version in `.config/semantic-version/version`, update `README.md`, and merge to `main`. CI builds and publishes the release automatically.

## Skills

Always invoke the relevant skill before starting a task. Available skills:

- `/new-module` — scaffold a new SPM module (includes Package manifest, source, test conventions, and doc comment rules)

If skills don't appear in your agent, run:

```bash
./scripts/tools/ai/ai.bash
```
