#!/usr/bin/env sh

set -Eeo

. "$(dirname "$(realpath "$0")")/_common-source.sh"

prepare_package_copy

echo "Listing Swift SDKs..."
swift sdk list

echo "Listing Swift SDKs with ls..."
ls ~/.swiftpm/swift-sdks

echo "Building Release configuration..."

export SWIFT_SDK="${SWIFT_SDK:-"x86_64-swift-linux-musl"}"

./scripts/tools/swift/swift.sh --action=build --configuration=release

echo "Listing build directory..."
ls -la --block-size=M .build/**/release/mpct

echo "Making built binary executable..."
chmod +x .build/${SWIFT_SDK}/release/mpct

echo "Copying built release binary back to the original package directory..."
cp .build/${SWIFT_SDK}/release/mpct /package/.build/${SWIFT_SDK}/release/mpct

finish
