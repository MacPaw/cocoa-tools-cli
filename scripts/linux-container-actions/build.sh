#!/usr/bin/env sh

set -Eeo

. "$(dirname "$(realpath "$0")")/_common-source.sh"

prepare_package_copy

echo "Building Release configuration..."
./scripts/tools/swift/swift.sh --action=build --configuration=release

echo "Making built binary executable..."
chmod +x .build/aarch64-unknown-linux-gnu/release/mpct

echo "Copying built release binary back to the original package directory..."
cp .build/aarch64-unknown-linux-gnu/release/mpct /package/.build/aarch64-unknown-linux-gnu/release/mpct

finish
