#!/usr/bin/env bash

set -eu

# shellcheck source=./scripts/linux-container-actions/_common-source.bash
. "$(dirname "$(realpath "$0")")/_common-source.bash"
# shellcheck source=./scripts/tools/swift/static-sdk.bash
. "$(dirname "$(realpath "$0")")/../tools/swift/static-sdk.bash"

prepare_package_copy

echo "Listing Swift SDKs..."
swift sdk list

echo "Listing Swift SDKs with ls..."
ls ~/.swiftpm/swift-sdks

echo "Building Release configuration..."

SWIFT_LIBC_IMPLEMENTATION="${SWIFT_LIBC_IMPLEMENTATION:-"gnu"}"
ARCH="$(swift_linux_arch "${ARCH:-"$(uname -m)"}")"
SWIFT_RELEASE_DIRECTORY="${SWIFT_RELEASE_DIRECTORY:-"$(swift_release_directory "${SWIFT_LIBC_IMPLEMENTATION}" "${ARCH}")"}"

BUILD_ARGS=(
  "--action=build"
  "--configuration=release"
  "--libc-implementation=${SWIFT_LIBC_IMPLEMENTATION}"
  "--arch=${ARCH}"
)

if [[ -n ${SWIFT_PACKAGE_BINARY_NAME} ]]; then
  # `/package` is mounted read-only, except for the release directory the host mounts read-write.
  BUILD_ARGS+=(
    "--product=${SWIFT_PACKAGE_BINARY_NAME}"
    "--output=/package/.build/${SWIFT_RELEASE_DIRECTORY}"
  )
fi

./scripts/tools/swift/swift.bash "${BUILD_ARGS[@]}" -- --disable-automatic-resolution --disable-prefetching

finish
