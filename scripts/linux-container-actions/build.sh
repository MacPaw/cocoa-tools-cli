#!/usr/bin/env sh

set -Eeo

. "$(dirname "$(realpath "$0")")/_common-source.sh"

prepare_package_copy

echo "Listing Swift SDKs..."
swift sdk list

echo "Building Release configuration..."

SDK="swift-${SWIFT_VERSION}-RELEASE_static-linux-0.0.1"
TRIPLE="${TRIPLE:-"aarch64-swift-linux-musl"}"

./scripts/tools/swift/swift.sh --action=build --configuration=release -- \
  --swift-sdk "${SDK}" \
  --triple "${TRIPLE}"

echo "Making built binary executable..."
chmod +x .build/${TRIPLE}/release/mpct

echo "Copying built release binary back to the original package directory..."
cp .build/${TRIPLE}/release/mpct /package/.build/${TRIPLE}/release/mpct

finish
