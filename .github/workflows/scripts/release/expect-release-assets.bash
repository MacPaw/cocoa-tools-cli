#!/usr/bin/env bash

set -Eeo pipefail

# Validates the archives downloaded from the Build run before anything is published.
#
# Runs before the release is created so a partial matrix, a renamed archive or a corrupted
# download cannot turn into a half-published release: immutable releases cannot be fixed
# after the fact.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.github/workflows/scripts/release/sha256.bash
source "${SCRIPT_DIR}/sha256.bash"

: "${VERSION:?VERSION is required}"
: "${SWIFT_PACKAGE_BINARY_NAME:?SWIFT_PACKAGE_BINARY_NAME is required}"
: "${EXPECTED_ZIP_COUNT:?EXPECTED_ZIP_COUNT is required}"

ARTIFACTS_DIR="${ARTIFACTS_DIR:-"artifacts"}"

die() {
  echo "::error::${*}"
  exit 1
}

if [[ ! -d ${ARTIFACTS_DIR} ]]; then
  die "Artifacts directory ${ARTIFACTS_DIR} does not exist"
fi

ARCHIVES=()
while IFS= read -r ARCHIVE; do
  ARCHIVES+=("${ARCHIVE}")
done < <(find "${ARTIFACTS_DIR}" -type f -name '*.zip' | sort)

if [[ ${#ARCHIVES[@]} -ne ${EXPECTED_ZIP_COUNT} ]]; then
  die "Expected ${EXPECTED_ZIP_COUNT} archives in ${ARTIFACTS_DIR}, found ${#ARCHIVES[@]}: ${ARCHIVES[*]}"
fi

# Platform and architecture name the build target, not the machine that produced the
# archive: the macOS runner also cross-builds the musl Linux archives.
VERSION_PATTERN="${VERSION//./\\.}"
NAME_PATTERN="^${SWIFT_PACKAGE_BINARY_NAME}-${VERSION_PATTERN}-(Darwin-(arm64|x86_64|universal)|Linux-(aarch64|x86_64)-(gnu|musl))\.zip$"

for ARCHIVE in "${ARCHIVES[@]}"; do
  ARCHIVE_NAME="$(basename "${ARCHIVE}")"

  if [[ ! ${ARCHIVE_NAME} =~ ${NAME_PATTERN} ]]; then
    die "Archive ${ARCHIVE_NAME} does not match the release naming convention: ${NAME_PATTERN}"
  fi

  if [[ ! -f "$(sha256_sidecar_path "${ARCHIVE}")" ]]; then
    die "Archive ${ARCHIVE_NAME} has no ${ARCHIVE_NAME}.sha256 checksum"
  fi

  sha256_verify_sidecar "${ARCHIVE}" || die "Checksum verification failed for ${ARCHIVE_NAME}"
done

echo "Verified ${#ARCHIVES[@]} archives and their checksums"
