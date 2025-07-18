# EnvSubst Module

A Swift module for environment variable substitution in strings and data, compatible with shell-style variable expansion syntax.

## Overview

The EnvSubst module provides powerful environment variable substitution capabilities similar to the Unix `envsubst` command. It supports various substitution patterns including default values, alternate values, and error handling for missing or empty variables.

## Features

- **Shell-Compatible Syntax**: Supports standard shell variable expansion patterns. With default options and without escaping behaves like native `eval`.
- **Multiple Substitution Patterns**: Default values, alternate values, error handling
- **Flexible Options**: Control behavior for unset/empty variables and error handling
- **Data Support**: Works with both strings and binary data
- **Error Handling**: Comprehensive error reporting with detailed context

## Supported Substitution Patterns

### Basic Variable Substitution
- `$VAR` - Simple variable substitution
- `${VAR}` - Braced variable substitution

### Default Value Patterns
- `${VAR-default}` - Use default if VAR is unset
- `${VAR:-default}` - Use default if VAR is unset or empty

### Assignment Patterns
- `${VAR=default}` - Set and use default if VAR is unset
- `${VAR:=default}` - Set and use default if VAR is unset or empty

### Alternate Value Patterns
- `${VAR+alternate}` - Use alternate if VAR is set (even if empty)
- `${VAR:+alternate}` - Use alternate if VAR is set and not empty

### Error Patterns
- `${VAR?error}` - Display error if VAR is unset
- `${VAR:?error}` - Display error if VAR is unset or empty

### Escaping
- `$$VAR` - Literal `$VAR` (escaped dollar sign)

## Basic Usage

### Simple Substitution

```swift
import EnvSubst

// Basic substitution
let template = "Hello $USER from $HOME"
let result = try EnvSubst.substitute(template)
// Result: "Hello john from /Users/john"

// With custom environment
let customEnv = ["NAME": "Alice", "GREETING": "Hi"]
let greeting = try EnvSubst.substitute(
    "Hello $NAME", 
    environment: customEnv
)
// Result: "Hello Alice"
```

### Advanced Patterns

```swift
// Default values
let config = try EnvSubst.substitute("""
    Port: ${PORT:-8080}
    Debug: ${DEBUG:-false}
    Database: ${DB_URL-sqlite://memory}
    """)

// Alternate values
let features = try EnvSubst.substitute("""
    ${FEATURE_X+Feature X is enabled}
    ${FEATURE_Y:+Feature Y is configured: $FEATURE_Y}
    """)

// Provide default value once with :=
let dryAssignments = try EnvSubst.substitute("""
    Port: ${PORT:=8080}
    Port is ${PORT}
    """)

// Error handling
let required = try EnvSubst.substitute("""
    API Key: ${API_KEY:?API_KEY is required}
    Database: ${DATABASE_URL?DATABASE_URL must be set}
    """)


```

### Working with Data

```swift
// Substitute in file content
let templateData = try Data(contentsOf: templateURL)
let processedData = try EnvSubst.substitute(
    templateData,
    encoding: .utf8
)

// Write processed data
try processedData.write(to: outputURL)
```

### Instance-Based Usage

```swift
// Create reusable instance
let envSubst = EnvSubst(
    environment: customEnvironment,
    options: .strict
)

// Use multiple times
let result1 = try envSubst.substitute(template1)
let result2 = try envSubst.substitute(template2)
```

## Configuration Options

### EnvSubst.Options

Control substitution behavior with various options:

```swift
// Default options (permissive)
let defaultOptions = EnvSubst.Options.default

// Strict options (fail on unset and empty variables)
let strictOptions = EnvSubst.Options.strict

// Custom options
let customOptions = EnvSubst.Options(
    noUnset: true,    // Fail if variable is not set
    noEmpty: false,   // Allow empty variables
    failFast: true    // Stop at first error
)

let result = try EnvSubst.substitute(
    template,
    options: customOptions
)
```

### Option Details

- **`noUnset`**: When `true`, throws an error if a referenced variable is not set in the environment
- **`noEmpty`**: When `true`, throws an error if a referenced variable is set but empty
- **`failFast`**: When `true`, stops processing at the first error; when `false`, collects all errors
