#!/usr/bin/env bash

set -Eeo pipefail

# Writes the release gate file that the Release workflow consumes.
#
# The gate is uploaded as an artifact only when a green build should be released, so its
# presence is what tells the Release workflow to run. It also carries everything Release
# needs about this build, which keeps that workflow from resolving the environment again.

: "${VERSION:?VERSION is required}"
: "${HEAD_SHA:?HEAD_SHA is required}"
: "${EXPECTED_ZIP_COUNT:?EXPECTED_ZIP_COUNT is required}"
: "${SWIFT_HAS_BUILD_ARTIFACTS:?SWIFT_HAS_BUILD_ARTIFACTS is required}"

SWIFT_PACKAGE_BINARY_NAME=""
if [[ ${SWIFT_HAS_BUILD_ARTIFACTS} == "true" ]]; then
  : "${SWIFT_PACKAGE_BINARY_NAME:?SWIFT_PACKAGE_BINARY_NAME is required}"
fi

GATE_PATH="${GATE_PATH:-"release-gate.json"}"

# Normalized to a JSON boolean so the gate always parses, whatever the workflow passed in.
if [[ ${IS_PRERELEASE:-} == "true" ]]; then
  IS_PRERELEASE=true
else
  IS_PRERELEASE=false
fi

# build-binary.bash drops a leading `v` when naming archives, so dropping it here too keeps
# the tag, the archive names and the assessed version from drifting apart.
VERSION="${VERSION#v}"

jq --null-input \
  --arg version "${VERSION}" \
  --arg headSha "${HEAD_SHA}" \
  --arg binaryName "${SWIFT_PACKAGE_BINARY_NAME}" \
  --argjson isPrerelease "${IS_PRERELEASE}" \
  --argjson expectedZipCount "${EXPECTED_ZIP_COUNT}" \
  --argjson swiftHasBuildArtifacts "${SWIFT_HAS_BUILD_ARTIFACTS}" \
  '{
    "should-proceed": true,
    "package-version": $version,
    "package-version-is-prerelease": $isPrerelease,
    "swift-package-binary-name": $binaryName,
    "expected-zip-count": $expectedZipCount,
    "head-sha": $headSha,
    "swift-has-build-artifacts": $swiftHasBuildArtifacts
  }' > "${GATE_PATH}"

echo "Wrote ${GATE_PATH}:"
cat "${GATE_PATH}"
