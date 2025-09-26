# Development Guide

## Getting Started

### Prerequisites
- macOS 15+ (for local development)
- Swift 6.1+
- Docker Desktop (for Linux testing)
- 1Password account (for integration testing)

### Setup
**Bootstrap the development environment:**
   ```bash
   make bootstrap
   ```
   
   This installs necessary tools via `mise`:
   - **`op`** - 1Password CLI for secrets management
   - **`swift-confidential`** - CLI from [github.com/securevale/swift-confidential](https://github.com/securevale/swift-confidential)
   - **`container`** - containerization tool to tests in Linux container
   - **`shfmt`**, **`shellcheck`** - formatter and linter for shell scipts

## Testing

### Local Testing
Standard Swift testing is fully supported:
```bash
swift test --enable-experimental-prebuilts
```

### Platform-Specific Testing

#### Linux Testing
To test cross-platform compatibility on Linux:
**Run Linux tests:**
  ```bash
  mise tasks run test:linux
  ```

#### 1Password Integration Testing

**Prerequisites:**
1. Add a personal account to 1Password app
2. Authenticate the 1Password CLI:
   ```bash
   op account add
   op signin
   ```

**Run integration tests:**
```bash
mise tasks run test:integration:op
```

## Code formatting and linting
Used tools:
* [swift-format](https://github.com/swiftlang/swift-format) to format and lint `*.swift` files
* [shellcheck](github.com/koalaman/shellcheck) to lint and auto-fix linting issues of the `*.sh` files
* [shfmt](https://github.com/mvdan/sh) to format `*.sh` files

### Formatting

To format code run:
```bash
mise tasks run format
```

### Linting

To format code run:
```bash
mise tasks run lint
```

## Release Process

### Creating a Release
1. **Update version:**
   - Edit `.version` file in the repository root
   - Use [Semantic Versioning](https://semver.org/spec/v2.0.0.html) format (e.g., `1.2.3`)
   - For pre-releases, add pre-release identifiers (e.g., `1.2.3-rc.1`)

2. **Trigger release:**
   - Merge changes to the `main` branch
   - GitHub Actions will automatically create the release

### Release Behavior
- **Pre-release versions** (with `-` identifiers) are marked as pre-releases on GitHub
- **Failed releases** can be retried by updating `.github/workflows/` files without version bumps
- **Multi-platform binaries** are built for macOS (universal, arm64, x86_64) and Linux (x86_64)

## Continuous Integration

### CodeQL Security Analysis
We use manual CodeQL configuration because default CodeQL runners don't support Swift 6.1.

CodeQL runs conditionally based on file changes:
- **Swift analysis** - triggered by changes to `**/*.swift`, `Package.swift`, or `Package.resolved`
- **Actions analysis** - triggered by changes to `.github/**/*.yaml` or `.github/**/*.yml`
