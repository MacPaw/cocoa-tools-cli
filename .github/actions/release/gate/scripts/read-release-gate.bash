#!/usr/bin/env bash

set -Eeo pipefail

# Reads the release gate artifact written by the Build workflow run that triggered this
# Release run.
#
# A missing gate is the normal "this build is not a release" signal and must stay quiet.
# Anything else — an unreachable run, a rejected token — has to fail loudly, otherwise a
# broken setup would look exactly like a build that simply should not be released.

: "${GITHUB_TOKEN:?GITHUB_TOKEN is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
: "${RUN_ID:?RUN_ID is required}"
: "${GITHUB_OUTPUT:=/dev/stdout}"

GATE_ARTIFACT_NAME="${GATE_ARTIFACT_NAME:-"release-gate"}"
GATE_FILE_NAME="${GATE_FILE_NAME:-"release-gate.json"}"
API_URL="${GITHUB_API_URL:-"https://api.github.com"}"

die() {
  echo "::error::${*}"
  exit 1
}

emit() {
  echo "${1}=${2}"
  echo "${1}=${2}" >> "${GITHUB_OUTPUT}"
}

no_release() {
  echo "Not releasing: ${*}"
  emit should-proceed false
  exit 0
}

github_api() {
  curl --silent --show-error --location \
    --header "Accept: application/vnd.github+json" \
    --header "Authorization: Bearer ${GITHUB_TOKEN}" \
    --header "X-GitHub-Api-Version: 2022-11-28" \
    --write-out $'\n%{http_code}' \
    "${@}"
}

echo "Looking for the ${GATE_ARTIFACT_NAME} artifact of run ${RUN_ID}"

RESPONSE="$(github_api "${API_URL}/repos/${GITHUB_REPOSITORY}/actions/runs/${RUN_ID}/artifacts?per_page=100")"
HTTP_CODE="$(tail -n1 <<< "${RESPONSE}")"
BODY="$(sed '$d' <<< "${RESPONSE}")"

if [[ ${HTTP_CODE} != "200" ]]; then
  die "Failed to list artifacts of run ${RUN_ID} (HTTP ${HTTP_CODE}): ${BODY}"
fi

ARTIFACT_ID="$(jq -r --arg name "${GATE_ARTIFACT_NAME}" \
  'first(.artifacts[]? | select(.name == $name and (.expired | not)) | .id) // empty' <<< "${BODY}")"

if [[ -z ${ARTIFACT_ID} ]]; then
  no_release "run ${RUN_ID} has no ${GATE_ARTIFACT_NAME} artifact"
fi

GATE_DIR="$(mktemp -d)"
trap 'rm -rf "${GATE_DIR}"' EXIT

# The artifact is fetched with `gh` rather than curl: the download endpoint redirects to a
# signed storage URL that rejects a forwarded Authorization header. By now the artifact is
# known to exist, so any failure here is a real one.
if ! gh run download "${RUN_ID}" \
  --repo "${GITHUB_REPOSITORY}" \
  --name "${GATE_ARTIFACT_NAME}" \
  --dir "${GATE_DIR}"; then
  die "Failed to download the ${GATE_ARTIFACT_NAME} artifact of run ${RUN_ID}"
fi

GATE_PATH="${GATE_DIR}/${GATE_FILE_NAME}"
if [[ ! -f ${GATE_PATH} ]]; then
  die "The ${GATE_ARTIFACT_NAME} artifact does not contain ${GATE_FILE_NAME}"
fi

echo "Release gate:"
cat "${GATE_PATH}"

# `false` is a meaningful value here, so an absent key is distinguished explicitly rather
# than with jq's `//`, which treats `false` as missing.
gate_value() {
  jq -r --arg key "${1}" 'if has($key) and .[$key] != null then .[$key] | tostring else "" end' "${GATE_PATH}"
}

SHOULD_PROCEED="$(gate_value should-proceed)"
if [[ ${SHOULD_PROCEED} != "true" ]]; then
  no_release "the release gate says should-proceed=${SHOULD_PROCEED:-"<missing>"}"
fi

VERSION="$(gate_value package-version)"
SWIFT_PACKAGE_BINARY_NAME="$(gate_value swift-package-binary-name)"
EXPECTED_ZIP_COUNT="$(gate_value expected-zip-count)"
HEAD_SHA="$(gate_value head-sha)"
IS_PRERELEASE="$(gate_value package-version-is-prerelease)"
SWIFT_HAS_BUILD_ARTIFACTS="$(gate_value swift-has-build-artifacts)"

# The commit is taken from the gate rather than from the triggering run: Build is itself
# started by a workflow_run, whose run-level head sha is the default branch head rather than
# the commit that was built. The gate comes from the same run as the archives, so it is what
# ties the release to the commit those archives were built from.
for REQUIRED in VERSION HEAD_SHA SWIFT_HAS_BUILD_ARTIFACTS; do
  if [[ -z ${!REQUIRED} ]]; then
    die "The release gate is missing a value for ${REQUIRED}"
  fi
done

if [[ ${SWIFT_HAS_BUILD_ARTIFACTS} == "true" ]]; then
  for REQUIRED in SWIFT_PACKAGE_BINARY_NAME EXPECTED_ZIP_COUNT; do
    if [[ -z ${!REQUIRED} ]]; then
      die "The release gate is missing a value for ${REQUIRED}"
    fi
  done
fi

emit package-version "${VERSION}"
emit swift-package-binary-name "${SWIFT_PACKAGE_BINARY_NAME}"
emit expected-zip-count "${EXPECTED_ZIP_COUNT}"
emit head-sha "${HEAD_SHA}"
emit package-version-is-prerelease "${IS_PRERELEASE:-"false"}"
emit should-proceed true
emit swift-has-build-artifacts "${SWIFT_HAS_BUILD_ARTIFACTS}"
