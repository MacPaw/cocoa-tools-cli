# debug-ci

Diagnose a failing GitHub Actions run in this repo.

## Workflow map

| Workflow | What it does |
|---|---|
| `test.yaml` | Runs `swift test` |
| `build.yaml` | Builds release binaries for macOS and Linux (musl + gnu) |
| `release.yaml` | Publishes a GitHub release; triggered by `build.yaml` |
| `load-env.yaml` | Reusable; extracts Swift version, platform, container info |

Custom actions live in `.github/actions/`:
- `prepare-swift/` — installs/caches Swift toolchain and cross-compilation SDKs
- `swift-cache/` — caches `.build/` between runs
- `select-swift-version/` — picks Xcode/Swift version from `.swift-version`

## Diagnostic checklist

1. **Identify the layer**: is the failure in a step, a job, or a required check (`require-needs`)?

2. **Build failures** — check:
   - Swift version mismatch: see `.swift-version` and `select-swift-version/`
   - Linux cross-compilation: `prepare-swift/` sets up musl/gnu SDKs; missing SDK = linker error
   - Conditional macOS-only targets (`ObfuscateSecrets`) included in a Linux build

3. **Test failures** — check:
   - Which target failed (`--filter` argument in the workflow step)
   - Whether it's a concurrency/strict-concurrency issue (Swift 6 strict mode is on)
   - Missing environment variables the test expects

4. **Release failures** — `release.yaml` requires the build gate artifact from `build.yaml`; if that artifact wasn't uploaded the release job is skipped/fails

5. **Caching issues** — `swift-cache/` key is based on `Package.resolved`; a stale cache after a dependency bump can cause phantom build errors; re-running the job without cache usually confirms

6. **Linux container builds** — the repo uses Apple's `container` tool and Docker; for local reproduction run `mise tasks run build:linux:container` or `mise tasks run build:linux:docker`

## Local reproduction

```bash
mise tasks run test                        # reproduce test failure locally
mise tasks run build:linux:container       # reproduce Linux build (requires container tool)
mise tasks run build:linux:docker          # reproduce Linux build (requires Docker)
```
