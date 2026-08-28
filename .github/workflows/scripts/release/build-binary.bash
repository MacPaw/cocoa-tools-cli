#!/usr/bin/env bash

set -Eeo pipefail

# Extract version from tag (remove 'v' prefix if present)
function version_filename() {
  local SUPPORTED_VERSION_FILENAMES=(
    ".config/semantic-version/version"
    ".version"
  )

  for filename in "${SUPPORTED_VERSION_FILENAMES[@]}"; do
    if [ -f "${filename}" ]; then
      echo "${filename}"
      return 0
    fi
  done

  return 0
}

VERSION_FILE="$(version_filename)"
VERSION="${VERSION:-"$( (cat "${VERSION_FILE}" || echo '0.0.1') | tr -d '[:space:]')"}"
VERSION="${VERSION#v}"
SWIFT_PACKAGE_BINARY_NAME="${SWIFT_PACKAGE_BINARY_NAME:-""}"
HOST_PLATFORM="$(uname -s | tr '[:upper:]' '[:lower:]')"
HOST_ARCH="$(uname -m)"
PLATFORM="${PLATFORM:-"${HOST_PLATFORM}"}"
ARCH="${ARCH:-"${HOST_ARCH}"}"
SWIFT_LIBC_IMPLEMENTATION="${SWIFT_LIBC_IMPLEMENTATION:-""}"

# `all` builds every target a Darwin host can produce: Darwin x86_64, arm64 and universal plus
# the musl Linux cross-builds. Any other value builds the single PLATFORM/ARCH target.
TARGETS="${TARGETS:-""}"

STAGING_DIR="build/staging"

ASSET_NAMES=()
ASSET_PATHS=()

die() {
  echo "${*}" >&2
  exit 1
}

normalize_arch() {
  case "${1}" in
    arm64 | aarch64) echo "arm64" ;;
    x86_64 | amd64) echo "x86_64" ;;
    *) echo "${1}" ;;
  esac
}

target_staging_dir() {
  local TARGET_PLATFORM="${1}" TARGET_ARCH="${2}" TARGET_LIBC="${3}"
  echo "${STAGING_DIR}/${TARGET_PLATFORM}-${TARGET_ARCH}${TARGET_LIBC:+-${TARGET_LIBC}}"
}

target_archive_name() {
  local TARGET_PLATFORM="${1}" TARGET_ARCH="${2}" TARGET_LIBC="${3}"
  echo "${SWIFT_PACKAGE_BINARY_NAME}-${VERSION}-${TARGET_PLATFORM}-${TARGET_ARCH}${TARGET_LIBC:+-${TARGET_LIBC}}.zip"
}

# Only a binary for the host platform and architecture can report its own version. Cross-built
# binaries are inspected instead: the macOS runners are arm64 and carry no guaranteed Rosetta,
# so even a Darwin x86_64 slice is not runnable there.
can_execute_target() {
  local TARGET_PLATFORM="${1}" TARGET_ARCH="${2}"

  if [ "${TARGET_PLATFORM}" != "${HOST_PLATFORM}" ]; then
    return 1
  fi

  if [ "${TARGET_ARCH}" == "universal" ]; then
    return 0
  fi

  [ "$(normalize_arch "${TARGET_ARCH}")" == "$(normalize_arch "${HOST_ARCH}")" ]
}

verify_binary() {
  local TARGET_PLATFORM="${1}" TARGET_ARCH="${2}" TARGET_LIBC="${3}"
  local BINARY_PATH BINARY_VERSION
  BINARY_PATH="$(target_staging_dir "${TARGET_PLATFORM}" "${TARGET_ARCH}" "${TARGET_LIBC}")/${SWIFT_PACKAGE_BINARY_NAME}"

  if [ ! -f "${BINARY_PATH}" ]; then
    die "Error: ${BINARY_PATH} was not built"
  fi

  echo "Binary size: $(du -h "${BINARY_PATH}" | cut -f1)"

  if [ "${TARGET_PLATFORM}" == "darwin" ] && [ "${HOST_PLATFORM}" == "darwin" ]; then
    local EXPECTED_ARCHS EXPECTED_ARCH

    if [ "${TARGET_ARCH}" == "universal" ]; then
      EXPECTED_ARCHS=("arm64" "x86_64")
    else
      EXPECTED_ARCHS=("${TARGET_ARCH}")
    fi

    # `lipo` verifies a single architecture per invocation.
    for EXPECTED_ARCH in "${EXPECTED_ARCHS[@]}"; do
      echo "Verifying that ${BINARY_PATH} contains the ${EXPECTED_ARCH} architecture..."
      lipo "${BINARY_PATH}" -verify_arch "${EXPECTED_ARCH}"
    done
  fi

  if can_execute_target "${TARGET_PLATFORM}" "${TARGET_ARCH}"; then
    BINARY_VERSION="$("${BINARY_PATH}" --version | tr -d '[:space:]')"
    echo "Binary version: ${BINARY_VERSION}"

    if [ "${BINARY_VERSION}" != "${VERSION}" ]; then
      die "Binary version ${BINARY_VERSION} does not match the expected version ${VERSION}"
    fi
  else
    echo "Skipping the --version check: ${TARGET_PLATFORM}/${TARGET_ARCH} does not run on ${HOST_PLATFORM}/${HOST_ARCH}"

    if which file > /dev/null 2>&1; then
      file "${BINARY_PATH}"
    else
      # The `file` tool is not available in the swift container images.
      echo "Binary file found: ${BINARY_PATH}"
    fi
  fi
}

build_target() {
  local TARGET_PLATFORM="${1}" TARGET_ARCH="${2}" TARGET_LIBC="${3}"
  local OUTPUT_DIR BUILD_ARGS
  OUTPUT_DIR="$(target_staging_dir "${TARGET_PLATFORM}" "${TARGET_ARCH}" "${TARGET_LIBC}")"

  echo "Building ${TARGET_PLATFORM}/${TARGET_ARCH}${TARGET_LIBC:+ (${TARGET_LIBC})} binary, version ${VERSION}..."
  rm -rf "${OUTPUT_DIR}"

  BUILD_ARGS=(
    "--action=build"
    "--configuration=release"
    "--arch=${TARGET_ARCH}"
  )

  if [ -n "${SWIFT_PACKAGE_BINARY_NAME}" ]; then
    BUILD_ARGS+=("--product=${SWIFT_PACKAGE_BINARY_NAME}")
  fi

  if [ -n "${SWIFT_PACKAGE_BINARY_NAME}" ]; then
    BUILD_ARGS+=("--output=${OUTPUT_DIR}")
  fi

  if [ -n "${TARGET_LIBC}" ]; then
    BUILD_ARGS+=("--libc-implementation=${TARGET_LIBC}")
  fi

  echo "Running swift.bash: ./scripts/tools/swift/swift.bash ${BUILD_ARGS[*]}"
  ./scripts/tools/swift/swift.bash "${BUILD_ARGS[@]}"
}

stage_universal_binary() {
  local OUTPUT_DIR
  OUTPUT_DIR="$(target_staging_dir darwin universal "")"

  echo "Creating universal binary..."
  mkdir -p "${OUTPUT_DIR}"
  lipo \
    "$(target_staging_dir darwin arm64 "")/${SWIFT_PACKAGE_BINARY_NAME}" \
    "$(target_staging_dir darwin x86_64 "")/${SWIFT_PACKAGE_BINARY_NAME}" \
    -create \
    -output "${OUTPUT_DIR}/${SWIFT_PACKAGE_BINARY_NAME}"
}

archive_target() {
  local TARGET_PLATFORM="${1}" TARGET_ARCH="${2}" TARGET_LIBC="${3}"
  local ARCHIVE_NAME ARCHIVE_PATH STAGE_DIR
  ARCHIVE_NAME="$(target_archive_name "${TARGET_PLATFORM}" "${TARGET_ARCH}" "${TARGET_LIBC}")"
  ARCHIVE_PATH="${PWD}/${ARCHIVE_NAME}"
  STAGE_DIR="$(target_staging_dir "${TARGET_PLATFORM}" "${TARGET_ARCH}" "${TARGET_LIBC}")"

  echo "Creating archive: ${ARCHIVE_NAME}"
  rm -f "${ARCHIVE_PATH}"

  case "${TARGET_PLATFORM}" in
    darwin)
      (cd "${STAGE_DIR}" && ditto -c -k --sequesterRsrc --keepParent "${SWIFT_PACKAGE_BINARY_NAME}" "${ARCHIVE_PATH}")
      ;;
    linux)
      (cd "${STAGE_DIR}" && zip "${ARCHIVE_PATH}" "${SWIFT_PACKAGE_BINARY_NAME}")
      ;;
    *)
      die "Unsupported platform for archiving: ${TARGET_PLATFORM}"
      ;;
  esac

  if [ ! -f "${ARCHIVE_PATH}" ]; then
    die "Error: archive ${ARCHIVE_NAME} was not created"
  fi

  echo "Archive created successfully: ${ARCHIVE_NAME}, size: $(du -h "${ARCHIVE_PATH}" | cut -f1)"

  ASSET_NAMES+=("${ARCHIVE_NAME}")
  ASSET_PATHS+=("${ARCHIVE_PATH}")
}

build_and_verify_target() {
  build_target "${@}"

  if [[ ${SWIFT_HAS_BUILD_ARTIFACTS} == "true" ]]; then
    verify_binary "${@}"
  fi
}

release_target() {
  build_and_verify_target "${@}"
  if [[ ${SWIFT_HAS_BUILD_ARTIFACTS} == "true" ]]; then
    archive_target "${@}"
  fi
}

release_universal_target() {
  if [[ ${SWIFT_HAS_BUILD_ARTIFACTS} == "true" ]]; then
    stage_universal_binary
    verify_binary darwin universal ""
    archive_target darwin universal ""
  fi
}

mkdir -p "${STAGING_DIR}"

if [ "${TARGETS}" == "all" ]; then
  if [ "${HOST_PLATFORM}" != "darwin" ]; then
    die "TARGETS=all builds Darwin and musl Linux binaries and requires a Darwin host, got ${HOST_PLATFORM}"
  fi

  release_target darwin x86_64 ""
  release_target darwin arm64 ""
  release_universal_target

  release_target linux x86_64 musl
  release_target linux aarch64 musl
elif [ "${PLATFORM}" == "darwin" ] && [ "${ARCH}" == "universal" ]; then
  build_and_verify_target darwin x86_64 ""
  build_and_verify_target darwin arm64 ""
  release_universal_target
elif [ "${PLATFORM}" == "darwin" ] && [[ ${ARCH} == "arm64" || ${ARCH} == "x86_64" ]]; then
  release_target darwin "${ARCH}" ""
elif [ "${PLATFORM}" == "linux" ] && [[ ${ARCH} == "aarch64" || ${ARCH} == "x86_64" ]]; then
  release_target linux "${ARCH}" "${SWIFT_LIBC_IMPLEMENTATION}"
else
  die "Unsupported platform/architecture combination: ${PLATFORM}/${ARCH}"
fi

if [ -n "${GITHUB_OUTPUT}" ]; then
  # One archive per line: a `TARGETS=all` build produces several assets.
  {
    echo "asset_names<<ASSETS_EOF"
    printf '%s\n' "${ASSET_NAMES[@]}"
    echo "ASSETS_EOF"
    echo "asset_paths<<ASSETS_EOF"
    printf '%s\n' "${ASSET_PATHS[@]}"
    echo "ASSETS_EOF"
  } >> "${GITHUB_OUTPUT}"
fi

# Clean up build artifacts
rm -rf build
