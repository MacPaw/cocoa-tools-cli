#!/usr/bin/env bash

set -Eeo pipefail

# Decides whether the current commit should be released.
#
# A release is attempted when version file changed since the latest tag and that version
# has not been published yet. Version bumps and tags are expected to be linear on main:
# the latest tag reachable from HEAD is treated as the previous release, so hotfix tags
# on older versions are not supported.
#
# Draft releases are treated as absent: a failed release attempt leaves a draft behind and
# must not block retries. Only the Release workflow deletes drafts, so this script needs
# no write access.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.github/workflows/scripts/release/release-state.bash
source "${SCRIPT_DIR}/release-state.bash"

: "${GITHUB_OUTPUT:=/dev/stdout}"

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

VERSION="${VERSION:-""}"
VERSION_FILE="$(version_filename)"
if [[ -z ${VERSION} ]] && [[ -f ${VERSION_FILE} ]]; then
  VERSION="$(tr -d '[:space:]' < "${VERSION_FILE}")"
fi
VERSION="${VERSION#v}"

die() {
  echo "::error::${*}"
  exit 1
}

emit() {
  echo "${1}=${2}"
  echo "${1}=${2}" >> "${GITHUB_OUTPUT}"
}

skip() {
  echo "Not releasing: ${*}"
  emit should-proceed false
  exit 0
}

if [[ -z ${VERSION} ]]; then
  skip "no package version resolved (missing or empty version file)"
fi

echo "Assessing release for version ${VERSION}"

# `git describe` walks the history of HEAD, which is what the linear tagging expectation
# relies on: the newest tag on this branch is the previous release.
LAST_TAG="$(git describe --tags --abbrev=0 HEAD 2> /dev/null || true)"
emit last-tag "${LAST_TAG}"

if [[ -z ${LAST_TAG} ]]; then
  # Nothing has ever been released, so the presence of a version is the whole signal.
  VERSION_CHANGED=true
else
  if [[ -n "$(git diff --name-only "${LAST_TAG}..HEAD" -- "${VERSION_FILE}")" ]]; then
    VERSION_CHANGED=true
  else
    VERSION_CHANGED=false
  fi
fi
emit files-changed "${VERSION_CHANGED}"

if git rev-parse --quiet --verify "refs/tags/${VERSION}" > /dev/null 2>&1; then
  TAG_EXISTS=true
else
  TAG_EXISTS=false
fi
emit tag-exists "${TAG_EXISTS}"

if ! RELEASE_STATE="$(release_state "${VERSION}")"; then
  die "Could not determine whether ${VERSION} is already released"
fi

case "${RELEASE_STATE}" in
  missing)
    RELEASE_EXISTS=false
    RELEASE_IS_DRAFT=false
    RELEASE_PUBLISHED=false
    ;;
  draft)
    echo "Release ${VERSION} exists as a draft, treating it as not released"
    RELEASE_EXISTS=true
    RELEASE_IS_DRAFT=true
    RELEASE_PUBLISHED=false
    ;;
  *)
    RELEASE_EXISTS=true
    RELEASE_IS_DRAFT=false
    RELEASE_PUBLISHED=true
    ;;
esac
emit release-exists "${RELEASE_EXISTS}"
emit release-is-draft "${RELEASE_IS_DRAFT}"

# Publishing a release also creates its tag, so a published release is decided on its own:
# the tag it implies may simply not have reached this clone yet.
if [[ ${RELEASE_PUBLISHED} == "true" ]]; then
  skip "version ${VERSION} is already published. Bump \"${VERSION_FILE}\" to release again."
fi

# A tag without a published release means an earlier attempt left the repository
# half-released. Publishing over it would be ambiguous, and releases are immutable, so this
# needs a human.
if [[ ${TAG_EXISTS} == "true" ]]; then
  die "Tag ${VERSION} exists but has no published release. Resolve this by hand."
fi

if [[ ${VERSION_CHANGED} == "false" ]]; then
  skip "Version file \"${VERSION_FILE}\" did not change since ${LAST_TAG}"
fi

echo "Releasing version ${VERSION}"
emit should-proceed true
