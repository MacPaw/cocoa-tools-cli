#!/usr/bin/env bash

set -Eeo pipefail

# Extract version from tag (remove 'v' prefix if present)
VERSION="${VERSION:-"$( (cat .version || echo '0.0.1') | tr -d '[:space:]')"}"
VERSION="${VERSION#v}"
BINARY_NAME="${BINARY_NAME:-"mpct"}"
PLATFORM="${PLATFORM:-"$(uname -s)"}"
ARCH="${ARCH:-"$(uname -m)"}"
ARCHIVE_NAME="${BINARY_NAME}-${VERSION}-${PLATFORM}-${ARCH}.zip"

echo "Building binary for platform: ${PLATFORM}, architecture: ${ARCH}, version: ${VERSION}"

# Create build directory
mkdir -p build

function build() {
  local ARCH="${1}"
  echo "Building ${ARCH} binary for ${PLATFORM}..."
  ./scripts/tools/swift/swift.sh --action=build --configuration=release -- --arch "${ARCH}"
}

if [ "${PLATFORM}" == "Darwin" ] && [ "${ARCH}" == "universal" ]; then
  # Build universal binary for macOS
  build x86_64
  build arm64

  echo "Creating universal binary..."
  lipo \
    ".build/arm64-apple-macosx/release/${BINARY_NAME}" \
    ".build/x86_64-apple-macosx/release/${BINARY_NAME}" \
    -create \
    -output "build/${BINARY_NAME}"

  # Verify the universal binary
  echo "Verifying universal binary..."
  lipo "build/${BINARY_NAME}" -verify_arch arm64 x86_64

elif [ "${PLATFORM}" == "Darwin" ] && [[ ${ARCH} == "arm64" || ${ARCH} == "x86_64" ]]; then

  # Build $ARCH binary for macOS
  build "${ARCH}"
  mv ".build/${ARCH}-apple-macosx/release/${BINARY_NAME}" "build/${BINARY_NAME}"

  # Verify the binary
  echo "Verifying binary..."
  lipo "build/${BINARY_NAME}" -verify_arch "${ARCH}"

elif [ "${PLATFORM}" == "Linux" ] && [ "${ARCH}" == "x86_64" ]; then
  # Build for Linux x86_64
  build "${ARCH}"
  mv ".build/release/${BINARY_NAME}" "build/${BINARY_NAME}"

  # Verify the binary
  echo "Verifying binary..."
  if which file > /dev/null 2>&1; then
    file "build/${BINARY_NAME}"
  elif [ -f "build/${BINARY_NAME}" ]; then
    # `file` tool is not available in the swift container
    echo "Binary file found"
  else
    echo "Binary file not found"
    exit 1
  fi
else
  echo "Unsupported platform/architecture combination: ${PLATFORM}/${ARCH}"
  exit 1
fi

echo "Binary size: $(du -h "build/${BINARY_NAME}" | cut -f1)"

BINARY_VERSION="$("build/${BINARY_NAME}" --version | tr -d '[:space:]')"
echo "Binary version: ${BINARY_VERSION}"

if [ "${BINARY_VERSION}" != "${VERSION}" ]; then
  echo "Binary version ${BINARY_VERSION} does not match the expected version ${VERSION}"
  exit 1
fi

# Create the archive
echo "Creating archive: ${ARCHIVE_NAME}"
cd build

if [ "${PLATFORM}" == "Darwin" ]; then
  # Use ditto on macOS
  ditto -c -k --sequesterRsrc --keepParent "${BINARY_NAME}" "../${ARCHIVE_NAME}"
elif [ "${PLATFORM}" == "Linux" ]; then
  # Use zip on Linux
  zip "../${ARCHIVE_NAME}" "${BINARY_NAME}"
else
  echo "Unsupported platform for archiving: ${PLATFORM}"
  exit 1
fi

cd ..

# Verify the archive was created
if [ -f "${ARCHIVE_NAME}" ]; then
  echo "Archive created successfully: ${ARCHIVE_NAME}"
  echo "Archive size: $(du -h "${ARCHIVE_NAME}" | cut -f1)"

  if [ -n "${GITHUB_OUTPUT}" ]; then
    # Set outputs for GitHub Actions
    echo "asset_path=${PWD}/${ARCHIVE_NAME}" >> "${GITHUB_OUTPUT}"
    echo "asset_name=${ARCHIVE_NAME}" >> "${GITHUB_OUTPUT}"
  fi
else
  echo "Error: Archive was not created"
  exit 1
fi

# Clean up build artifacts
rm -rf build
