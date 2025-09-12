# MacPaw Cocoa Tools CLI (mpct)

A comprehensive Swift CLI toolkit for engineers, providing essential utilities for scripts and secret management.

## Overview

mpct is a modular Swift CLI project targeting macOS 15+ that helps engineers with common development tasks through a collection of specialized modules and commands.

## 🚀 Quick Start

### Installation

### mise

1. Add `mpct` to the `[tools]` section in your `mise.toml`
    ```toml
    [tools]
    "ubi:MacPaw/cocoa-tools-cli" = { version = "latest", exe = "mpct" }
    ```

2. Run `mise install`.

## 🛠 Commands

### Command Structure
```
mpct
├── envsubst              # Environment variable substitution
└── secrets               # Secret management commands
    ├── import            # Import secrets from providers
    └── obfuscate         # Generate obfuscated Swift code
```

### [envsubst](docs/Commands/EnvSubstCommand.md)
Environment variable substitution command.

```bash
mpct envsubst --input template.txt --output config.txt
```

**Key Features:**
- Shell-compatible variable expansion
- Support for default values and error handling
- Stdin/stdout processing
- Strict validation options

### [secrets export](docs/Commands/ExportSecretsCommand.md)
Import secrets from various providers.

```bash
mpct secrets export --config secrets.yaml --source op --destination mise
```

**Key Features:**
- 1Password CLI integration
- Multiple export formats (dotenv, mise, stdout)
- YAML-based configuration
- Environment variable substitution in configs

### [secrets obfuscate](docs/Commands/ObfuscateSecretsCommand.md)
Generate obfuscated Swift code for secrets.

```bash
mpct secrets obfuscate --swift-confidential-config config.yaml --output Sources/Secrets.swift
```

**Key Features:**
- Swift-confidential integration
- Environment variable substitution
- Secret importing integration
- Build-time code generation

## 📦 Modules

### Core Libraries

#### [EnvSubst](docs/Products/EnvSubst.md)
Shell-compatible environment variable substitution in strings and data.

- **Features**: Shell-style variable expansion, default values, error handling
- **Use Cases**: Template processing, configuration file generation
- **Example**: `${VAR:-default}`, `${VAR+alternate}`, `${VAR?error}`

#### [ImportSecrets](docs/Products/ImportSecrets.md)
Comprehensive secret management with support for multiple providers and export destinations.

- **Features**: 1Password integration, YAML configuration, batch operations
- **Use Cases**: Secret importing, environment file generation, CI/CD integration
- **Example**: Import from 1Password to `.env` files or mise configurations

#### [ObfuscateSecrets](docs/Products/ObfuscateSecrets.md)
Swift code generation with obfuscated secret literals using swift-confidential.

- **Features**: Swift-confidential integration, environment variable substitution
- **Use Cases**: Secure secret storage in mobile apps, build-time secret processing
- **Example**: Generate obfuscated Swift accessors for runtime secret access

#### [SemanticVersion](docs/Products/SemanticVersion.md)
Comprehensive semantic versioning implementation with compile-time macro support and build tool integration.

- **Features**: Semantic Versioning 2.0.0 compliance, compile-time `#semanticVersion` macro, build plugin for automatic version generation
- **Use Cases**: Version management, build automation, CI/CD integration
- **Example**: `#semanticVersion("1.2.3-beta.1")`, automatic `.version` file processing


### Supporting Libraries

#### Shell
Shell command execution utilities with mise integration.

- **Features**: Process execution, mise tool management
- **Use Cases**: Build scripts, tool integration

## 🏗 Architecture

### Modular Design
- **Loose Coupling**: Modules can be used independently (w/o CLI execution)
- **Protocol-Based**: Extensible through well-defined interfaces
- **Type Safety**: Leverages Swift's type system for safety

#### Module Dependencies Sample
```
mpct (executable)
├── EnvSubstCommand → EnvSubst
├── ExportSecretsCommand → ImportSecrets → EnvSubst, Shell
└── ObfuscateSecretsCommand → ObfuscateSecrets → EnvSubst, ImportSecrets
```

## 🔧 Development

See the [docs/DEVELOPMENT.md](./docs/DEVELOPMENT.md) file.

## 📚 Documentation

### Commands
- [EnvSubstCommand](docs/Commands/EnvSubstCommand.md) - Environment variable substitution
- [ExportSecretsCommand](docs/Commands/ExportSecretsCommand.md) - Secret importing
- [ObfuscateSecretsCommand](docs/Commands/ObfuscateSecretsCommand.md) - Secret obfuscation

### Modules
- [EnvSubst](docs/Products/EnvSubst.md) - Variable substitution engine
- [ImportSecrets](docs/Products/ImportSecrets.md) - Secret management
- [ObfuscateSecrets](docs/Products/ObfuscateSecrets.md) - Secret obfuscation
- [SemanticVersion](docs/Products/SemanticVersion.md) - Semantic versioning

## 🔗 Related Projects

- [swift-confidential](https://github.com/securevale/swift-confidential) - Secret obfuscation library
- [swift-argument-parser](https://github.com/apple/swift-argument-parser) - Command-line argument parsing
- [Yams](https://github.com/jpsim/Yams) - YAML parsing for Swift

---

**Built with ❤️ by the MacPaw Foundation/Terminus Team**
