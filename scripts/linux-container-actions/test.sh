#!/usr/bin/env sh

set -Eeo

# shellcheck source=./scripts/linux-container-actions/_common-source.sh
. "$(dirname "$(realpath "$0")")/_common-source.sh"

# Running test on a package copy to avoid modifying files in the original package folder (.build, .swiftpm, etc.).
prepare_package_copy

echo "Building..."
./scripts/tools/swift/swift.sh --action=build --configuration=debug

echo "Testing..."
./scripts/tools/swift/swift.sh --action=test

finish
