# ImportSecretsCommand

Command-line interface for importing secrets from various providers and exporting them to different destinations.

## Overview

The ImportSecretsCommand provides a CLI wrapper around the ImportSecrets module, allowing users to fetch secrets from different sources (like 1Password) and export them to various destinations such as environment files, mise configurations, or standard output.

## Usage

```bash
mpct secrets import --config <config> --destination <destination> [--file <file>] [--no-unset] [--no-empty] [--fail-fast] --source <source> ...
```

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `--config`, `-c` | Yes | Path to the YAML configuration file that defines which secrets to import.<br><br>The configuration file specifies:<br>• Which secrets to fetch from which providers<br>• How they should be mapped to environment variable names<br>• Source-specific configuration options |
| `--source` | Yes | Source provider to use for fetching secrets. Can be specified multiple times to use multiple sources.<br><br>**Available sources:**<br>• `op` - Import secrets from 1Password using the 1Password CLI<br><br>When multiple sources are provided for the CLI command, it will try to fetch missing secrets from all passed sources. |
| `--destination` | Yes | Destination to export the fetched secrets to.<br><br>**Available destinations:**<br>• `stdout` - Export to standard output in KEY=VALUE format<br>• `mise` - Export to a mise configuration file (default: `mise.local.toml`)<br>• `dotenv` - Export to a .env file format (default: `.env.local`) |
| `--file` | No | Destination file path for file-based destinations (mise, dotenv).<br><br>If not specified, default file names will be used:<br>• `mise`: `mise.local.toml`<br>• `dotenv`: `.env.local` |
| `--no-unset` | No | Fail if a referenced variable is not set in the environment. By default, unset variables are replaced with empty strings. |
| `--no-empty` | No | Fail if a referenced variable is set but contains an empty value. By default, empty variables are allowed. |
| `--fail-fast` | No | Stop processing at the first error encountered during substitution. By default, processing continues and errors are collected. |

## Configuration File Format

The configuration file is a YAML file that defines the secrets to import. Example structure:

```yaml
# Example configuration for importing secrets
sourceConfigurations:
  op:
    vault: personal
secrets:
  API_KEY:
    sources:
      op:
        item: item-name-or-id
        label: field
```

More info on the configuration file structure and avaulable secret sources configurations is available in the [Configuration Format](./../Products/ImportSecrets.md#configuration-format) and [Suported providers](./../Products/ImportSecrets.md#supported-providers).

## Examples

### Basic Usage
Import secrets from 1Password and export to stdout:
```bash
mpct secrets import --config secrets.yaml --source op --destination stdout --no-unset --no-empty
```

### Export to mise configuration
Import secrets and save to mise configuration file:
```bash
mpct secrets import --config secrets.yaml --source op --destination mise
```

### Multiple sources
Import from multiple sources (if supported):
```bash
mpct secrets import --config secrets.yaml --source op --source vault --destination stdout
```

### With environment variable substitution options
Import with strict variable validation:
```bash
mpct secrets import --config secrets.yaml --source op --destination stdout --no-unset --fail-fast
```

## Error Handling

The command will fail if:
- Configuration file cannot be found or parsed
- Source providers cannot authenticate or access secrets
- Destination files cannot be written
- Required environment variables are missing (with `--no-unset`)
- Environment variables are empty (with `--no-empty`)

## Security Considerations

- Ensure configuration files don't contain sensitive data directly and secrets are not commited to the repository
- Be cautious when using `stdout` destination to avoid logging secrets

## Related Commands

- [`envsubst`](./EnvSubstCommand.md) - For standalone environment variable substitution
- [`secrets obfuscate`](./ObfuscateSecretsCommand.md) - For obfuscating secrets in Swift code

## Dependencies

- 1Password CLI (`op`) must be installed and authenticated for 1Password integration
- Configuration files must be valid YAML format
- Write permissions required for file-based destinations
