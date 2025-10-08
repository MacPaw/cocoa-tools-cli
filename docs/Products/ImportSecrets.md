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

### `.import-secrets.yaml` scheme
```yaml
version: <Int>

# Source configurations with default parameters.
sourceConfigurations:
  # Keys are the secret source provider keys: `op` or `vault`.
  op: 
  vault:

# An array of secrets.
secrets:
   
  - # Prefix is optional string for the fetched secret.
    prefix: <String>
    # An object that contains source configuration for secret providers.
    # When two providers are given:
    #   * When two `--source` params are given to the CLI, or configuration: tries to resolve with the first one, and when failed tries another one.
    #   * When one `--source` parameter is given to the CLI, or configuration: will use only one source.
    #
    # You can provide two sources `op` and `vault` and use `op` locally and `vault` remotely.
    # In this case the lables in `op` and keys in `vault` must match.
    # If they don't match - you can do two secrets with different sources, and map in the `secretNamesMapping`.
    sources:
      # Keys are the secret source provider keys: `op` or `vault`.
      # For the configuration, please see the corresponding docs below.
      op: 
      vault:

  - ...

# Secret names mapping.
# Maps fetched secrets varaible names to a new ones.
secretNamesMapping:
  # The key is prefixed key, if prefix provided for a secret.
  # The value is the new name of the variable containig a secrets.
  <prefixd-key>: <String>

```

### Configuration

Create a `.import-secrets.yaml` file:

```yaml
version: 1

# Global provider configurations
sourceConfigurations:
  # 1Password configuration
  op:  
    account: myacc        # Default account
    vault: "Development"  # Default vault
  # HashiCorp Vault configuration
  vault: 
    # Vault address.
    vaultAddress: ${VAULT_ADDR:-"https://vault.example.com:8200"}
      # Vault API version. Default is v1.
      apiVersion: v1
      # Vault Authentication method.
      # Supported values: 'token', 'appRole'.
      authenticationMethod: ${VAULT_AUTH_METHOD:-token}
      # Authentication credentials for the given authenticationMethod.
      authenticationCredentials:
        # A simple Vault authentication.
        token:
          vaultToken: ${VAULT_TOKEN}
        # Authentication with appRole credentials.
        appRole:
          roleId: ${VAULT_ROLE_ID}
          secretId: ${VAULT_SECRET_ID}
      # Default engines configurations.
      engines:
        # Key value engine configuration.
        keyValue:
          defaultSecretMountPath: secret
        # AWS engine configuration.
        aws:
          defaultEnginePath: production

# Secrets to import
secrets:
  - prefix: DB_
    sources:
      op:
        item: "Database Config"
        labels: 
          - "connection-string"
          - "admin-username"
  
  - prefix: AWS_STAGING_
    sources:
      vault:
        keyValue:
          path: /staging/secrets
        keys:
          - my-key
      op:
        item: staging keys
        labels:
          - my-key
  
  - prefix: AWS_PROD_
    sources:
      vault:
        aws:
          role: product

- sources:
    op:
      account: "another_acc"  # Override default account
      vault: "Production"     # Override default vault
      item: "API Keys"
      labels: 
        - production_key

# Secret names mapping.
secretNamesMapping:
  DB_connection-string: DB_ADRESS
  DB_admin-username: DB_USERNAME
  production_key: SERVICE_A_PRODUCTION_KEY
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
        labels: 
          - "${DB_FIELD_NAME:-connection-string}"
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
    account: "myacc"   # Default account shorthand, sign-in address, account ID, or user ID.
    vault: "My Vault"  # Default vault name or ID.

secrets:
  - sources:
      op:
        account: "another_acc"       # Optional: Override default account.
        vault: "Specific Vault"      # Optional: Override default vault.
        item: "Item Name or ID"      # Required: 1Password item (name, id or URL).
        labels:                      # Optional: A list of field labels to fetch secrets from.
          - "field_label"            #           If not provided, or empty - will fetch all fields from the item.
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
        # Required: An authorization token
        vaultToken: "..." 
      
      # For AppRole authentication (alternative to token)
      appRole:
        # Required: A role ID
        roleId: "role-id-here"
        # Required: A secret ID
        secretId: "secret-id-here"
    
    # Optional: Default engine configurations
    engines:
      # KeyValue engine defaults
      keyValue:
        defaultSecretMountPath: "secret"  # Default mount path
      
      # AWS engine defaults
      aws:
        defaultEnginePath: "aws"  # Default engine path

secrets:
  # KeyValue engine secret
  - prefix: DATABASE_PASSWORD_
    sources:
      vault:
        keyValue:
          version: 2                       # Optional: Specific version (If not specified or value less than 1 the latest version will be used)
          secretMountPath: "secret"        # Optional: Override the defaultSecretMountPath
          path: "myapp/database"           # Required: Secret path
        keys:                            # Optional: Secret keys within `path` to fetch
          - "password"                   #           If not provided, or empty - will fetch all fields from the item.
  
  # AWS engine creds
  - prefix: AWS_CREDS_
    sources:
      vault:
        aws:
          enginePath: "aws"               # Optional: Override defaultEnginePath
          role: "my-role"                 # Required: AWS role name
        keys:                           # Optional: Secret key names to fetch
          - "access_key"                #           If not provided, or empty - will fetch all fields from the item.
          - "secret_key"
  
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
  - prefix: DB_HOST_
    sources:
      op: { item: "Database", labels: ["host"] }
  - prefix: DB_PORT_
    sources:
      op: { item: "Database", labels: ["port"] }
  - prefix: DB_NAME_
    sources:
      op: { item: "Database", label: ["database"] }
```
