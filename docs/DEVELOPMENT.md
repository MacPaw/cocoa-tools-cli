# Development

## Getting started

1. Run `make bootstrap`.  
This will install necessary tools:  
  * mise
    * `op` - 1Password CLI.
    * `swift-confidential` - github.com/securevale/swift-confidential CLI.

## Testing

Usual `swift test` is supported.

### Linux
To test on Linux platform:  
1. Start the Docker app.
2. Run `mise tasks run test-linux`.

### 1Password

#### Prerequisites

1. You must add a persoanal account to 1Password.
2. 1Password CLI must be authenticated.

#### Test 1Password integration 
To test 1Password integration run `mise tasks run test-op`.

## Release process
Update the `.version` file in the repo root and merge changes into the main branch. 

The contents of the `.version` file is a single line with a [Semantic Version](https://semver.org/spec/v2.0.0.html). If there are [pre-release identifiers](https://semver.org/spec/v2.0.0.html#spec-item-9) the release on the GitHub will be marked as a pre-release.

If something fails during the release updating `.github` workflows and scripts will trigger the release process once again, and no need to constantly bump version.

## Other

### CodeQL
CodeQL will run swift and actions checks only if corresponding files were changed.
