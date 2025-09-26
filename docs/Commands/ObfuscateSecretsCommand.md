# ObfuscateSecretsCommand

Command-line interface for obfuscating secret literals in Swift code generation.

## Overview

The ObfuscateSecretsCommand is using [swift-confidential](https://github.com/securevale/swift-confidential) to generates Swift code that provides accessors for secret literals, grouped into namespaces as defined in a configuration file. The generated accessors allow for retrieving deobfuscated literals at runtime while keeping the actual secret values obfuscated in the source code.

The added functionality:
- Support [`envsusbt`](./EnvSubstCommand.md) to substitute environment variables in configuration file (`${VAR}`) with actual values
- Supports [`secrets export`](./ExportSecretsCommand.md) to fetch secrets from various secret sources (1Password)

## Usage

```bash
mpct secrets obfuscate --swift-confidential-config <swift-confidential-config> [--no-unset] [--no-empty] [--fail-fast] [--import-secrets-config <import-secrets-config>] --secrets-source <secrets-source> ... [--overwrite-existing] --output <output>
```

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `--swift-confidential-config` | Yes | Path to the swift-confidential configuration file that defines how secrets should be obfuscated and organized in the generated Swift code. |
| `--output`, `-o` | Yes | Path to the output Swift source file where the generated code will be written. |
| `--import-secrets-config` | No | Path to a secrets import configuration file (same format as used by ExportSecretsCommand). |
| `--secrets-source` | No | Source provider to import secrets from. Can be specified multiple times.<br><br>**Available sources:**<br>• `op` - Import secrets from 1Password using the 1Password CLI |
| `--overwrite-existing` | No | Flag to overwrite existing environment variables with fetched secrets. By default, existing environment variables take precedence. |
| `--no-unset` | No | Fail if a referenced variable is not set in the environment. |
| `--no-empty` | No | Fail if a referenced variable is set but contains an empty value. |
| `--fail-fast` | No | Stop processing at the first error encountered during substitution. |

## Configuration Files

### Swift Confidential Configuration
Defines how secrets should be obfuscated and structured in the generated Swift code. This typically includes:
- Namespace organization
- Secret naming conventions
- Obfuscation parameters

### Secrets Import Configuration (Optional)
When using secret import options, this YAML file defines which secrets to fetch from external sources, following the same format as ExportSecretsCommand.

## Examples

### Basic Obfuscation
Generate obfuscated Swift code from a configuration file:
```bash
mpct secrets obfuscate --swift-confidential-config confidential.yaml --output Sources/Secrets.swift
```

### With Secret Import
Import secrets from 1Password and then obfuscate them:
```bash
mpct secrets obfuscate \
  --swift-confidential-config confidential.yaml \
  --output Sources/Secrets.swift \
  --import-secrets-config secrets.yaml \
  --secrets-source op
```

### With Environment Variable Substitution
Generate code with strict variable validation:
```bash
mpct secrets obfuscate \
  --swift-confidential-config confidential.yaml \
  --output Sources/Secrets.swift \
  --no-unset \
  --fail-fast
```

### Overwrite Existing Environment Variables
Import secrets and overwrite any existing environment variables:
```bash
mpct secrets obfuscate \
  --swift-confidential-config confidential.yaml \
  --output Sources/Secrets.swift \
  --import-secrets-config secrets.yaml \
  --secrets-source op \
  --overwrite-existing
```

## Workflow

1. **Environment Setup**: Collects current environment variables
2. **Secret Import** (if configured): Fetches secrets from specified sources
3. **Environment Merging**: Combines fetched secrets with existing environment
4. **Variable Substitution**: Processes configuration files with environment variables
5. **Code Generation**: Creates obfuscated Swift code with runtime accessors

## Error Handling

The command will fail if:
- Configuration files cannot be found or parsed
- Secret sources cannot be accessed or authenticated
- Output file cannot be written
- Environment variable substitution fails
- Swift code generation encounters errors

## Related Commands

- [`secrets export`](./ExportSecretsCommand.md) - For standalone secret importing
- [`envsubst`](./EnvSubstCommand.md) - For environment variable substitution

## Dependencies

- swift-confidential tool for code generation
- 1Password CLI (`op`) if using 1Password integration
- Valid YAML configuration files
