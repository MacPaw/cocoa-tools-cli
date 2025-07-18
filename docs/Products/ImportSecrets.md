# ImportSecrets Module

A comprehensive Swift module for importing secrets from various providers (like 1Password) and exporting them to different destinations (environment files, mise configurations, etc.).

## Overview

The ImportSecrets module provides a unified interface for managing secrets across different providers and export formats. It supports YAML-based configuration, environment variable substitution, and extensible provider architecture.

## Features

- **Multiple Secret Providers**: Built-in support for 1Password, extensible for other providers
- **Flexible Export Destinations**: Support for .env files, mise configurations, stdout, and custom destinations
- **YAML Configuration**: Declarative configuration with environment variable substitution
- **Batch Operations**: Optimized fetching with provider-specific batching
- **Type Safety**: Strong typing with protocol-based architecture
- **Error Handling**: Comprehensive error reporting and validation

## Quick Start

### Basic Configuration

Create a `.import-secrets.yaml` file:

```yaml
version: "1.0"

# Global provider configurations
sourceConfigurations:
  op:  # 1Password configuration
    account: myacc        # Default account
    vault: "Development"  # Default vault

# Secrets to import
secrets:
  DATABASE_URL:
    sources:
      op:
        item: "Database Config"
        label: "connection_string"
  
  API_KEY:
    sources:
      op:
        item: "API Keys"
        label: "production_key"
        account: "another_acc"  # Override default account
        vault: "Production"     # Override default vault
```

### Import Secrets

```swift
import ImportSecrets

// Configure providers
let providers = [ImportSecrets.Providers.OnePassword()]

// Load and fetch secrets
let secrets = try await ImportSecrets.getSecrets(
    configurationURL: URL(fileURLWithPath: ".import-secrets.yaml"),
    sourceProviders: providers
)

// Result: ["DATABASE_URL": "postgres://...", "API_KEY": "sk-..."]
```

## Configuration Format

### Complete Configuration Example

```yaml
version: "1.0"

# Global configurations for secret providers
sourceConfigurations:
  op:  # 1Password
    vault: "Development"  # Default vault for all secrets

# Individual secrets configuration
secrets:
  # Database connection string
  DATABASE_URL:
    sources:
      op:
        item: "Database Config"
        label: "connection_string"
  
  # API key with vault override
  API_KEY:
    sources:
      op:
        item: "API Keys"
        label: "production_key"
        vault: "Production"  # Override default vault
  
  # Secret with multiple potential sources
  BACKUP_TOKEN:
    sources:
      op:
        item: "Backup Service"
        label: "api_token"
```

### Environment Variable Substitution

Configuration files support environment variable substitution:

```yaml
sourceConfigurations:
  op:
    vault: "${DEFAULT_VAULT:-Development}"

secrets:
  DATABASE_URL:
    sources:
      op:
        item: "${DB_ITEM_NAME}"
        label: "${DB_FIELD_NAME:-connection_string}"
```

Use with substitution:

```swift
let secrets = try await ImportSecrets.getSecrets(
    configurationURL: configURL,
    sourceProviders: providers,
    envSubstOptions: .strict  // Fail if variables are missing
)
```

## Supported Providers

### 1Password Provider

The built-in 1Password provider integrates with the 1Password CLI:

```swift
// Basic 1Password provider
let opProvider = ImportSecrets.Providers.OnePassword()

// With custom CLI path
let customCLI = try Shell.OnePassword(cliURL: URL(fileURLWithPath: "/custom/path/op"))
let customProvider = ImportSecrets.Providers.OnePassword(
    fetcher: .init(onePasswordCLI: customCLI)
)
```

#### 1Password Configuration Format

```yaml
sourceConfigurations:
  op:
    account: "myacc"   # Default account shorthand, sign-in address, account ID, or user ID
    vault: "My Vault"  # Default vault name or ID

secrets:
  SECRET_NAME:
    sources:
      op:
        item: "Item Name or ID"      # Required: 1Password item
        label: "field_label"         # Required: Field label in the item
        account: "another_acc"       # Optional: Override default account
        vault: "Specific Vault"      # Optional: Override default vault
```

## Advanced Usage

### Custom Providers

Create custom secret providers:

```swift
// 1. Define your source type
struct MySource: SecretSourceProtocol, Decodable {
    typealias Configuration = MyConfiguration
    
    let identifier: String
    let field: String
    
    mutating func validate(with configuration: MyConfiguration?) throws {
        // Validation logic
    }
}

// 2. Define configuration
struct MyConfiguration: SecretConfigurationProtocol, Decodable {
    static let configurationKey = "my_provider"
    let endpoint: String
    
    mutating func validate() throws {
        // Validation logic
    }
}

// 3. Create fetcher
struct MyFetcher: SecretFetcherProtocol {
    typealias Source = MySource
    
    func fetch(
        secrets: [String: MySource], 
        sourceConfiguration: MyConfiguration?
    ) async throws -> SecretsFetchResult {
        // Fetching logic
        var result = SecretsFetchResult()
        // ... implement fetching
        return result
    }
}

// 4. Create provider
struct MyProvider: SecretProviderProtocol {
    typealias Source = MySource
    typealias Fetcher = MyFetcher
    
    let fetcher: MyFetcher
    
    init(fetcher: MyFetcher = MyFetcher()) {
        self.fetcher = fetcher
    }
}

// 5. Use custom secret source provider
do {
  let secrets = try await ImportSecrets.getSecrets(
      configurationURL: configURL,
      sourceProviders: [MyProvider()]
  )
} catch {
    print("Failed to fetch secrets: \(error)")
}
```

### Error Handling

```swift
do {
    let secrets = try await ImportSecrets.getSecrets(
        configurationURL: configURL,
        sourceProviders: providers
    )
} catch ImportSecrets.Error.configurationFileNotFound {
    print("Configuration file not found")
} catch ImportSecrets.Error.missingSecrets(let secretNames) {
    print("Missing secrets: \(secretNames)")
} catch ImportSecrets.Error.failedToFetchSecrets(let errors) {
    print("Failed to fetch secrets: \(errors)")
}
```

### Configuration Validation

```swift
// Load configuration without fetching
var config = try ImportSecrets.configuration(
    configurationURL: configURL,
    sourceProviders: providers
)

// Validate configuration
try config.validate()

// Fetch secrets using validated configuration
let secrets = try await ImportSecrets.getSecrets(configuration: config)
```

## Performance Considerations

### Batching Optimization

The module automatically optimizes API calls by batching requests to the same provider:

```swift
// These secrets will be fetched in a single 1Password API call
// if they reference the same item
secrets:
  DB_HOST:
    sources:
      op: { item: "Database", label: "host" }
  DB_PORT:
    sources:
      op: { item: "Database", label: "port" }
  DB_NAME:
    sources:
      op: { item: "Database", label: "database" }
```

## Best Practices

1. **Use Specific Vault Names**: Specify exact vault names rather than relying on defaults
2. **Validate Configurations**: Always validate configurations before fetching
3. **Handle Errors Gracefully**: Implement proper error handling for missing secrets
4. **Use Environment Variable Substitution**: Make configurations flexible with environment variables
5. **Batch Related Secrets**: Group secrets from the same source for better performance
6. **Test with Mock Providers**: Use mock providers for unit testing
7. **Secure Configuration Files**: Keep configuration files secure and don't commit them with sensitive data


## Security Considerations

1. **Configuration File Security**: Don't commit configuration files with sensitive information
2. **Environment Variable Exposure**: Be careful with environment variables in CI/CD
3. **Provider Authentication**: Ensure proper authentication setup for secret providers
4. **Error Message Sanitization**: Avoid exposing sensitive information in error messages
5. **Temporary File Handling**: The module handles temporary files securely during processing
