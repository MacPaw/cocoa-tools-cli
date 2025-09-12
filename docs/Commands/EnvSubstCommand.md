# EnvSubstCommand

Command-line interface for environment variable substitution in text files.

## Overview

The EnvSubstCommand provides a CLI wrapper around the EnvSubst module, allowing users to substitute environment variables in text files or stdin using shell-style variable expansion. It supports various substitution patterns including default values, alternate values, and error handling.

## Usage

```bash
mpct envsubst [options]
mpct envsubst --input <file> --output <file> [options]
echo 'Hello $USER' | mpct envsubst
```

## Supported Variable Expressions

The command supports the following shell-style variable expansion patterns:

- `$var` or `${var}` - Value of var
- `${var-default}` - Use default if var not set
- `${var:-default}` - Use default if var not set or empty
- `${var+alternate}` - Use alternate if var is set
- `${var:+alternate}` - Use alternate if var is set and not empty
- `$$var` - Escape to literal $var

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `--input`, `-i` | No | Input file path. If not specified, reads from stdin. |
| `--output`, `-o` | No | Output file path. If not specified, writes to stdout. |
| `--no-unset` | No | Fail if a referenced variable is not set in the environment. By default, unset variables are replaced with empty strings. |
| `--no-empty` | No | Fail if a referenced variable is set but contains an empty value. By default, empty variables are allowed and their empty values are used. |
| `--fail-fast` | No | Stop processing at the first error encountered during substitution. By default, processing continues and errors are collected for reporting at the end. |

## Examples

### Basic Substitution
Substitute variables in a string:
```bash
echo 'Hello $USER from $HOME' | mpct envsubst
# Output: Hello john from /Users/john
```

### File Processing
Process a template file and save the result:
```bash
mpct envsubst --input template.txt --output config.txt
```

### Using Default Values
Template with default values:
```bash
echo 'Database: ${DB_HOST:-localhost}:${DB_PORT:-5432}' | mpct envsubst
# Output: Database: localhost:5432 (if DB_HOST and DB_PORT are not set)
```

### Using Alternate Values
Template with alternate values:
```bash
echo 'Mode: ${DEBUG+development}${DEBUG:+debug-enabled}' | mpct envsubst
# Output depends on whether DEBUG is set and its value
```

### Strict Mode
Fail on unset or empty variables:
```bash
mpct envsubst --no-unset --no-empty < template.txt
```

### Fast Failure
Stop at first error:
```bash
mpct envsubst --fail-fast --no-unset < template.txt
```

## Variable Expression Examples

### Basic Variable Substitution
```bash
# Input: Hello $USER
# Environment: USER=alice
# Output: Hello alice
```

### Default Values
```bash
# Input: Server: ${SERVER:-localhost}
# Environment: (SERVER not set)
# Output: Server: localhost

# Input: Server: ${SERVER:-localhost}
# Environment: SERVER=production.example.com
# Output: Server: production.example.com
```

### Default Values with Empty Check
```bash
# Input: Port: ${PORT:-8080}
# Environment: PORT=""
# Output: Port:  (empty string)

# Input: Port: ${PORT:-8080}
# Environment: PORT=""
# Output: Port: 8080
```

### Alternate Values
```bash
# Input: ${DEBUG+Debug mode enabled}
# Environment: DEBUG=1
# Output: Debug mode enabled

# Input: ${DEBUG+Debug mode enabled}
# Environment: (DEBUG not set)
# Output: (empty)
```

### Escaping
```bash
# Input: Price: $$10.99
# Output: Price: $10.99
```

## Error Handling

The command handles various error conditions:

### Unset Variables
- **Default behavior**: Replace with empty string
- **With `--no-unset`**: Fail with error message

### Empty Variables
- **Default behavior**: Use empty value
- **With `--no-empty`**: Fail with error message

### Processing Errors
- **Default behavior**: Collect all errors and report at the end
- **With `--fail-fast`**: Stop at first error

## Common Use Cases

### Configuration File Generation
Generate configuration files from templates:
```bash
mpct envsubst --input config.template --output config.json
```

### Docker Environment Files
Process Docker compose templates:
```bash
mpct envsubst --input docker-compose.template.yml --output docker-compose.yml
```

### CI/CD Pipeline Configuration
Generate pipeline configurations with environment-specific values:
```bash
mpct envsubst --input .github/workflows/template.yml --output .github/workflows/deploy.yml
```

### Application Configuration
Create application config from environment variables:
```bash
mpct envsubst --input app-config.template --output app-config.json --no-unset
```

## Integration with Other Commands

The EnvSubstCommand is also used internally by other commands:

- **ExportSecretsCommand**: Uses envsubst options for processing configuration files
- **ObfuscateSecretsCommand**: Uses envsubst options for variable substitution in configuration

## Error Messages

Common error scenarios and their messages:

- **File not found**: "Failed to read input file 'filename': No such file or directory"
- **Permission denied**: "Failed to write output file 'filename': Permission denied"
- **Unset variable**: "Variable 'VAR_NAME' is not set" (with `--no-unset`)
- **Empty variable**: "Variable 'VAR_NAME' is empty" (with `--no-empty`)
- **Substitution error**: "Substitution failed: [specific error message]"

## Performance Considerations

- Processing is done in memory, so very large files may consume significant RAM
- File I/O is performed atomically for output files
- Environment variable lookups are cached for performance

## Security Considerations

- Be cautious when processing untrusted input files
- Ensure proper file permissions on output files containing sensitive data
- Consider the security implications of environment variable expansion
- Validate that sensitive variables are properly set before processing

## Related Commands

- `import` - For importing secrets with environment variable substitution
- `obfuscate` - For obfuscating secrets with environment variable substitution

## Dependencies

- Read permissions for input files
- Write permissions for output files (when specified)
- Access to environment variables referenced in templates
