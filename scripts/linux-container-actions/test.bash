#!/usr/bin/env bash

set -eu

# shellcheck source=./scripts/linux-container-actions/_common-source.bash
. "$(dirname "$(realpath "$0")")/_common-source.bash"

# Running test on a package copy to avoid modifying files in the original package folder (.build, .swiftpm, etc.).
prepare_package_copy

echo "Testing..."
./scripts/tools/swift/swift.bash --action=test

echo "Building..."
./scripts/tools/swift/swift.bash --action=build --configuration=debug

finish
