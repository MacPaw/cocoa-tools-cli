# ImportSecrets Module

A comprehensive Swift module for importing secrets from various providers (like 1Password) and exporting them to different destinations (environment files, mise configurations, etc.).

## Overview

The ImportSecrets module provides a unified interface for managing secrets across different providers and export formats. It supports YAML-based configuration, environment variable substitution, and extensible provider architecture.

## Features

- **Multiple Secret Providers**: Built-in support for 1Password and HashiCorp Vault, extensible for other providers
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
let providers = [
    ImportSecrets.Providers.OnePassword(),
    ImportSecrets.Providers.HashiCorpVault()
]

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
  
  vault:  # HashiCorp Vault
    vaultAddress: "https://vault.example.com:8200"
    authenticationMethod: "token"
    authenticationCredentials:
      token:
        vaultToken: "${VAULT_TOKEN}"
    defaultEngineConfigurations:
      keyValue:
        defaultSecretMountPath: "secret"

# Individual secrets configuration
secrets:
  # Database connection string from 1Password
  DATABASE_URL:
    sources:
      op:
        item: "Database Config"
        label: "connection_string"
  
  # API key from 1Password with vault override
  API_KEY:
    sources:
      op:
        item: "API Keys"
        label: "production_key"
        vault: "Production"  # Override default vault
  
  # Application secret from HashiCorp Vault
  APP_SECRET:
    sources:
      vault:
        keyValue:
          path: "myapp/secrets"
          key: "app_secret"
  
  # AWS credentials from HashiCorp Vault
  AWS_ACCESS_KEY_ID:
    sources:
      vault:
        aws:
          role: "myapp-role"
          key: "accessKey"
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

### HashiCorp Vault Provider

The built-in HashiCorp Vault provider integrates with HashiCorp Vault servers to fetch secrets from KeyValue and AWS secrets engines:

```swift
// Basic HashiCorp Vault provider
let vaultProvider = ImportSecrets.Providers.HashiCorpVault()

// With custom reader
let customReader = HashiCorpVaultReader()
let customProvider = ImportSecrets.Providers.HashiCorpVault(
    fetcher: .init(reader: customReader)
)
```

#### HashiCorp Vault Configuration Format

```yaml
sourceConfigurations:
  vault:
    # Required: Vault server address
    vaultAddress: "https://vault.example.com:8200"
    
    # Optional: API version (defaults to "v1")
    apiVersion: "v1"
    
    # Required: Authentication method
    authenticationMethod: "token"  # or "appRole"
    
    # Required: Authentication credentials
    authenticationCredentials:
      # For token authentication
      token:
        vaultToken: "..."
      
      # For AppRole authentication (alternative to token)
      appRole:
        roleId: "role-id-here"
        secretId: "secret-id-here"
    
    # Optional: Default engine configurations
    defaultEngineConfigurations:
      # KeyValue engine defaults
      keyValue:
        defaultSecretMountPath: "secret"  # Default mount path
      
      # AWS engine defaults
      aws:
        defaultEnginePath: "aws"  # Default engine path

secrets:
  # KeyValue engine secret
  DATABASE_PASSWORD:
    sources:
      vault:
        keyValue:
          secretMountPath: "secret"        # Optional: Override default
          path: "myapp/database"           # Required: Secret path
          key: "password"                  # Required: Key within secret
          version: 2                       # Optional: Specific version (If not specified or value less than 1 the latest version will be used)
  
  # AWS engine secret (access key)
  AWS_ACCESS_KEY:
    sources:
      vault:
        aws:
          enginePath: "aws"               # Optional: Override default
          role: "my-role"                 # Required: AWS role name
          key: "accessKey"                # Required: "accessKey" or "secretKey"
  
  # AWS engine secret (secret key)
  AWS_SECRET_KEY:
    sources:
      vault:
        aws:
          enginePath: "aws"
          role: "my-role"
          key: "secretKey"
```

#### Authentication Methods

**Token Authentication:**
```yaml
sourceConfigurations:
  vault:
    vaultAddress: "https://vault.example.com:8200"
    authenticationMethod: "token"
    authenticationCredentials:
      token:
        vaultToken: "${VAULT_TOKEN}"
```

**AppRole Authentication:**
```yaml
sourceConfigurations:
  vault:
    vaultAddress: "https://vault.example.com:8200"
    authenticationMethod: "appRole"
    authenticationCredentials:
      appRole:
        roleId: "${VAULT_APP_ROLE_ROLE_ID}"
        secretId: "${VAULT_APP_ROLE_SECRET_ID}"
```

You can specify both `authenticationCredentials` at the same time and use `EnvSubst` for the `authenticationMethod`, 

#### Supported Engines

**KeyValue Engine (KV v2):**
- Supports versioned key-value secrets
- Configurable mount paths
- Specific version retrieval or latest version

**AWS Secrets Engine:**
- Dynamic AWS credentials generation
- Role-based access
- Returns both access key and secret key

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
8. **HashiCorp Vault Security**: Use appropriate authentication methods (prefer AppRole for applications)
9. **Version Management**: Use specific versions for critical secrets in HashiCorp Vault KV engine
10. **Engine Path Organization**: Organize HashiCorp Vault secrets with clear mount paths and role naming


## Security Considerations

1. **Configuration File Security**: Don't commit configuration files with sensitive information
2. **Environment Variable Exposure**: Be careful with environment variables in CI/CD
3. **Provider Authentication**: Ensure proper authentication setup for secret providers
4. **Error Message Sanitization**: Avoid exposing sensitive information in error messages
5. **Temporary File Handling**: The module handles temporary files securely during processing
6. **HashiCorp Vault Token Security**: Store vault tokens securely and rotate them regularly
7. **AppRole Credentials**: Use AppRole authentication for applications and secure role/secret IDs
8. **Network Security**: Ensure HashiCorp Vault communication uses HTTPS and proper certificates
9. **Access Policies**: Implement least-privilege access policies in HashiCorp Vault
10. **Audit Logging**: Enable audit logging in HashiCorp Vault for security monitoring
