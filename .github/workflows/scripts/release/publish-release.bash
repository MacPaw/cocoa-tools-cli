#!/usr/bin/env bash

set -Eeo pipefail

# Publishes the draft release, which is also what creates the git tag.
#
# Runs last, after the assets are uploaded and attested, because publishing is the point of
# no return for an immutable release.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.github/workflows/scripts/release/release-state.bash
source "${SCRIPT_DIR}/release-state.bash"

: "${VERSION:?VERSION is required}"

IS_PRERELEASE="${IS_PRERELEASE:-"false"}"

die() {
  echo "::error::${*}"
  exit 1
}

if ! RELEASE_STATE="$(release_state "${VERSION}")"; then
  die "Could not determine the state of release ${VERSION}"
fi

case "${RELEASE_STATE}" in
  draft) ;;
  published)
    echo "Version ${VERSION} is already published, nothing to do"
    exit 0
    ;;
  *)
    die "There is no draft release to publish for ${VERSION}"
    ;;
esac

EDIT_ARGS=("${VERSION}" "--draft=false")

# A prerelease must not become the version users are pointed at by default.
if [[ ${IS_PRERELEASE} == "true" ]]; then
  EDIT_ARGS+=("--prerelease" "--latest=false")
fi

echo "Publishing release ${VERSION}"
gh release edit "${EDIT_ARGS[@]}"

RELEASE_JSON="$(gh release view "${VERSION}" --json isDraft,tagName,url)"
echo "Published: ${RELEASE_JSON}"

if [[ "$(jq -r '.isDraft' <<< "${RELEASE_JSON}")" != "false" ]]; then
  die "Release ${VERSION} is still a draft after publishing"
fi

echo "Release ${VERSION} published: $(jq -r '.url' <<< "${RELEASE_JSON}")"
