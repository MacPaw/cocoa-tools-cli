#!/usr/bin/env bash

set -Eeo pipefail

# Creates the draft release and attaches the verified archives.
#
# The release is created as a draft pinned to the built commit, so the git tag only appears
# once publish-release.bash publishes it. That ordering matters for immutable releases: the
# assets have to be complete and attested before anything becomes permanent.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.github/workflows/scripts/release/release-state.bash
source "${SCRIPT_DIR}/release-state.bash"

: "${VERSION:?VERSION is required}"
: "${HEAD_SHA:?HEAD_SHA is required}"
: "${GITHUB_OUTPUT:=/dev/stdout}"
: "${SWIFT_HAS_BUILD_ARTIFACTS:?SWIFT_HAS_BUILD_ARTIFACTS is required}"

IS_PRERELEASE="${IS_PRERELEASE:-"false"}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-"artifacts"}"

die() {
  echo "::error::${*}"
  exit 1
}

emit() {
  echo "${1}=${2}"
  echo "${1}=${2}" >> "${GITHUB_OUTPUT}"
}

if ! RELEASE_STATE="$(release_state "${VERSION}")"; then
  die "Could not determine whether ${VERSION} is already released"
fi

# Release runs are serialized, but a queued run can still find the version published by the
# run ahead of it. That version is immutable, so this run has nothing left to do.
if [[ ${RELEASE_STATE} == "published" ]]; then
  echo "Version ${VERSION} is already published, nothing to do"
  emit created false
  exit 0
fi

# A draft left behind by an earlier attempt holds stale assets and cannot be added to
# selectively, so it is replaced rather than reused.
if [[ ${RELEASE_STATE} == "draft" ]]; then
  echo "Deleting the leftover draft release for ${VERSION}"
  gh release delete "${VERSION}" --yes
fi

# The .sha256 sidecars stay out of the release: GitHub already shows each asset's own SHA-256
# digest, and attest-build-provenance below covers provenance. The sidecars are still used
# above to verify the archives downloaded from the Build run before they get here.
ASSETS=()
if [[ ${SWIFT_HAS_BUILD_ARTIFACTS} == "true" ]]; then
  while IFS= read -r ASSET; do
    ASSETS+=("${ASSET}")
  done < <(find "${ARTIFACTS_DIR}" -type f -name '*.zip' | sort)

  if [[ ${#ASSETS[@]} -eq 0 ]]; then
    die "No release assets found in ${ARTIFACTS_DIR}"
  fi
fi

CREATE_ARGS=(
  "${VERSION}"
  "--draft"
  "--target=${HEAD_SHA}"
  "--title=${VERSION}"
  "--generate-notes"
)

if [[ ${IS_PRERELEASE} == "true" ]]; then
  CREATE_ARGS+=("--prerelease" "--latest=false")
fi

echo "Creating the draft release ${VERSION} for ${HEAD_SHA}"
gh release create "${CREATE_ARGS[@]}"

if [[ ${SWIFT_HAS_BUILD_ARTIFACTS} == "true" ]]; then
  echo "Uploading ${#ASSETS[@]} assets"
  gh release upload "${VERSION}" "${ASSETS[@]}" --clobber
fi

RELEASE_ID="$(gh release view "${VERSION}" --json databaseId --jq '.databaseId')"

emit created true
emit tag-name "${VERSION}"
emit release-id "${RELEASE_ID}"
