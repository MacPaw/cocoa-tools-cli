# ObfuscateSecrets Module

A Swift module that wraps [swift-confidential](https://github.com/securevale/swift-confidential) with environment variable substitution support, enabling dynamic configuration of secret obfuscation based on the current environment.

## Overview

The ObfuscateSecrets module is a wrapper around the [swift-confidential](https://github.com/securevale/swift-confidential) tool that adds environment variable substitution capabilities. It provides a two-stage processing pipeline: first performing environment variable substitution using the EnvSubst module, then obfuscating the resulting configuration using swift-confidential's powerful obfuscation techniques.

This approach allows you to create dynamic configuration templates that can be customized for different environments (development, staging, production) while still benefiting from swift-confidential's static config without storing secrets in file.

## Features

- **Swift-Confidential Integration**: Utilizes [swift-confidential](https://github.com/securevale/swift-confidential) under the hood for secret values obfuscation
- **Environment Variable Substitution**: Supports EnvSubst-style variable substitution in configuration files
- **Secure Processing**: Safe handling of sensitive data during the transformation pipeline

## Configuration Format

The module uses swift-confidential's YAML configuration format with added support for environment variable substitution. All swift-confidential configuration options are supported, plus the ability to use environment variables throughout the configuration.

### Configuration

For detailed configuration and docs refer to the [swift-confidential configuration](https://github.com/securevale/swift-confidential?tab=readme-ov-file#configuration)


For environment substitution docs refer to the [EnvSubst.md](./EnvSubst.md)


```yaml
# confidential.template.yml
algorithm:
  - encrypt using aes-256-gcm
  - shuffle

defaultNamespace: create Secrets
defaultAccessModifier: "${ACCESS_MODIFIER:-internal}"

secrets:
  - name: apiKey
    value: "${API_KEY:?API key is required}"
    accessModifier: "${API_ACCESS_MODIFIER:-internal}"
  
  - name: databaseURL
    value: "${DATABASE_URL:?Database URL is required}"
  
  - name: trustedCertificates
    value:
      - "${CERT_1:?First certificate is required}"
      - "${CERT_2:?Second certificate is required}"
      - "${CERT_3:-}"  # Optional third certificate
    
  - name: debugMode
    value: "${DEBUG_MODE:-false}"
    namespace: create Debug
```

This configuration supports all swift-confidential features while allowing dynamic values through environment variables.

## Usage

### CLI-Based Processing (Recommended)

The CLI-based approach uses the swift-confidential command-line tool and is the recommended method:

```swift
import ObfuscateSecrets

// Basic usage with default settings
try ObfuscateSecrets.substituteEnvAndObfuscateWithCLI(
    inputFileURL: URL(fileURLWithPath: "confidential.template.yml"),
    outputFileURL: URL(fileURLWithPath: "Sources/Config/Secrets.swift")
)

// Advanced usage with custom configuration
try ObfuscateSecrets.substituteEnvAndObfuscateWithCLI(
    inputFileURL: inputURL,
    outputFileURL: outputURL,
    environment: customEnvironment,            // Custom environment variables
    options: .strict,                          // Strict environment substitution
    encoding: .utf8,                           // File encoding
    swiftConfidentialBinaryURL: customCLIURL,  // Custom CLI tool path
    fileManager: customFileManager             // Custom file manager
)
```

### Library-Based Processing (Experimental)

> **Note**: The library-based approach requires [swift-confidential PR #10](https://github.com/securevale/swift-confidential/pull/10) to be merged and the `ConfidentialObfuscator` module to be available.

```swift
#if canImport(ConfidentialObfuscator)
import ObfuscateSecrets

// Library-based processing (when available)
try ObfuscateSecrets.substituteEnvAndObfuscateWithLibrary(
    inputFileURL: inputURL,
    outputFileURL: outputURL,
    environment: environment,
    options: .strict
)
#endif
```

The library-based approach provides tighter integration and faster processing time but requires the experimental ConfidentialObfuscator module.

## Processing Pipeline

### Stage 1: Environment Variable Substitution

The module first processes your configuration template through EnvSubst:

```yaml
# Input: confidential.template.yml
algorithm:
  - encrypt using aes-256-gcm
  - shuffle

defaultNamespace: create Secrets
defaultAccessModifier: "${ACCESS_MODIFIER:-internal}"

secrets:
  - name: apiKey
    value: "${API_KEY:?API key is required}"
  
  - name: databaseURL  
    value: "${DATABASE_URL:?Database URL is required}"
    
  - name: environment
    value: "${ENVIRONMENT:-development}"
```

With environment variables:
```bash
export ACCESS_MODIFIER="public"
export API_KEY="sk-1234567890abcdef"
export DATABASE_URL="postgres://user:pass@localhost/db"
export ENVIRONMENT="production"
```

Results in standard swift-confidential configuration:
```yaml
algorithm:
  - encrypt using aes-256-gcm
  - shuffle

defaultNamespace: create Secrets
defaultAccessModifier: public

secrets:
  - name: apiKey
    value: sk-1234567890abcdef
  
  - name: databaseURL
    value: postgres://user:pass@localhost/db
    
  - name: environment
    value: production
```

### Stage 2: Swift-Confidential Obfuscation

The substituted configuration is then processed by swift-confidential to generate obfuscated Swift code:

```swift
// Generated Secrets.swift
import ConfidentialKit
import Foundation

public enum Secrets {

    @ConfidentialKit.Obfuscated<Swift.String>(deobfuscateData)
    public static var apiKey: ConfidentialKit.Obfuscation.Secret = .init(
        data: [/* obfuscated data */], 
        nonce: /* cryptographically secure random number */
    )

    @ConfidentialKit.Obfuscated<Swift.String>(deobfuscateData)
    public static var databaseURL: ConfidentialKit.Obfuscation.Secret = .init(
        data: [/* obfuscated data */], 
        nonce: /* cryptographically secure random number */
    )

    @ConfidentialKit.Obfuscated<Swift.String>(deobfuscateData)
    public static var environment: ConfidentialKit.Obfuscation.Secret = .init(
        data: [/* obfuscated data */], 
        nonce: /* cryptographically secure random number */
    )

    // Private deobfuscation function
    private static func deobfuscateData(_ data: [UInt8], nonce: UInt64) -> [UInt8] {
        // Swift-confidential's obfuscation algorithm implementation
    }
}
```

## Related Projects

- **[swift-confidential](https://github.com/securevale/swift-confidential)**: The core obfuscation tool
- **EnvSubst**: Environment variable substitution module
- **ImportSecrets**: For importing secrets from external providers before obfuscation
