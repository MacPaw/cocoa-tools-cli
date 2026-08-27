#!/usr/bin/env bash

set -Eeo pipefail

# The workflow calls this script by its path from the workspace root, so the sibling is sourced
# relative to this file, not to the working directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.github/workflows/scripts/load-env/container-image.bash
source "${SCRIPT_DIR}/container-image.bash"

PROJECT_SPECS_YAML="${PROJECT_SPECS_YAML:-".github/project_specs.yaml"}"
echo "PROJECT_SPECS_YAML=${PROJECT_SPECS_YAML}"
WORKFLOW_INPUTS_JSON="${WORKFLOW_INPUTS_JSON:-"{}"}"
echo "WORKFLOW_INPUTS_JSON=${WORKFLOW_INPUTS_JSON}"

export PROJECT_SPECS
PROJECT_SPECS=$(yq --output-format json 'map_values(. |= tostring) | . // {}' "${PROJECT_SPECS_YAML}" 2> /dev/null)
PROJECT_SPECS="${PROJECT_SPECS:-"{}"}"
export WORKFLOW_INPUTS
# Unset workflow inputs arrive as empty strings and must not override project specs.
WORKFLOW_INPUTS=$(jq '(. // {}) | with_entries(select(.value != null and .value != ""))' <<< "${WORKFLOW_INPUTS_JSON}" 2> /dev/null)
WORKFLOW_INPUTS="${WORKFLOW_INPUTS:-"{}"}"

echo "PROJECT_SPECS=${PROJECT_SPECS}"
echo "WORKFLOW_INPUTS=${WORKFLOW_INPUTS}"

echo "MERGING PROJECT_SPECS AND WORKFLOW_INPUTS"
MERGED_ENV="$(yq --output-format json --input-format json --null-input 'env(PROJECT_SPECS) * env(WORKFLOW_INPUTS)')"
echo "MERGED_ENV=${MERGED_ENV}"

function env_value() {
  local key="$1"
  local default="$2"
  local value
  value=$(jq -r --arg key "$key" '.[$key] // empty' <<< "${MERGED_ENV}")
  echo "${value:-${default}}"
}

export SWIFT_PACKAGE_NAME SWIFT_PACKAGE_BINARY_NAME SWIFT_VERSION SWIFT_HAS_BUILD_ARTIFACTS
SWIFT_PACKAGE_NAME=$(env_value "swift-package-name")
SWIFT_PACKAGE_BINARY_NAME=$(env_value "swift-package-binary-name")
SWIFT_VERSION=$(env_value "swift-version")
SWIFT_HAS_BUILD_ARTIFACTS=$(env_value "swift-has-build-artifacts")

# Version number out of `swift -version` output, read from standard input. Apple prints
# `Apple Swift version 6.3 (…)`, Linux prints `Swift version 6.3.3 (…)`.
function swift_version_number() {
  grep -m1 -oE '[Ss]wift version [0-9]+(\.[0-9]+)*' | awk '{print $3}'
}

function resolve_swift_version() {
  local VERSION_IS_XCODE=false
  echo "Resolving Swift Version"

  if [ -f .swift-version ]; then
    echo "  Resolving Swift Version from .swift-version"
    SWIFT_VERSION=${SWIFT_VERSION:-"$(cat .swift-version)"}
  fi

  # `xcode` names the toolchain the selected Xcode ships, which only a machine with Xcode can
  # answer. Anywhere else it has to be cleared, so the step below can name a real version.
  if [[ ${SWIFT_VERSION} == "xcode" ]]; then
    if which xcrun > /dev/null; then
      echo "  Resolving Swift Version from Xcode"
      SWIFT_VERSION="$(xcrun swift -version 2> /dev/null | swift_version_number)" || SWIFT_VERSION=""
    else
      echo "  .swift-version selects Xcode, which this runner does not have"
      VERSION_IS_XCODE=true
      SWIFT_VERSION=""
    fi
  fi
  if [[ -z ${SWIFT_VERSION} ]] && which swift > /dev/null; then
    echo "  Resolving Swift Version from swift"
    SWIFT_VERSION="$(swift -version 2> /dev/null | swift_version_number)" || SWIFT_VERSION=""
  fi
  SWIFT_VERSION="$(echo "${SWIFT_VERSION}" | tr -d '[:space:]')"
  # A two-component version such as 6.4 is neither a Docker Hub tag nor a swiftly toolchain.
  if [[ ${SWIFT_VERSION} =~ ^[0-9]+\.[0-9]+$ ]]; then
    echo "  SWIFT_VERSION is short, setting to ${SWIFT_VERSION}.0"
    SWIFT_VERSION="${SWIFT_VERSION}.0"
  fi
  SWIFT_VERSION="${SWIFT_VERSION:-"6.3.3"}"

  if [[ ${VERSION_IS_XCODE} == true ]]; then
    echo "::warning::.swift-version selects the Xcode toolchain, which this runner does not provide. Using Swift ${SWIFT_VERSION} instead."
  fi

  echo "  Updating MERGED_ENV with the new values"
  # Update MERGED_ENV with the new values
  MERGED_ENV="$(yq --output-format json --input-format json '. * {  "swift-version": strenv(SWIFT_VERSION) }' <<< "${MERGED_ENV}")"
  echo "MERGED_ENV=${MERGED_ENV}"
}

function resolve_swift_dynamic_env() {
  if [ ! -f Package.swift ]; then
    return 0
  fi

  echo "Resolving Swift Dynamic Env"

  echo "  Dumping Swift Package"
  SWIFT_PACKAGE_DUMP_JSON="${SWIFT_PACKAGE_DUMP_JSON:-"$(swift package dump-package)"}"
  if [[ -z ${SWIFT_PACKAGE_DUMP_JSON} ]]; then
    echo "  Failed to dump Swift package"
    return 1
  fi

  echo "  Resolving Swift Package Name"
  SWIFT_PACKAGE_NAME="${SWIFT_PACKAGE_NAME:-"$(jq -r '.name // empty' <<< "${SWIFT_PACKAGE_DUMP_JSON}")"}"

  # Library-only packages have no executable product, so this stays empty.
  echo "  Resolving Swift Package Binary Name"
  SWIFT_PACKAGE_BINARY_NAME=${SWIFT_PACKAGE_BINARY_NAME:-"$(jq -r '[.products[] | select(.type | has("executable")) | .name] | first // empty' <<< "${SWIFT_PACKAGE_DUMP_JSON}")"}

  if [[ -n ${SWIFT_PACKAGE_BINARY_NAME} ]]; then
    SWIFT_HAS_BUILD_ARTIFACTS="true"
  else
    SWIFT_HAS_BUILD_ARTIFACTS="false"
  fi

  echo "  Updating MERGED_ENV with the new values"
  # Update MERGED_ENV with the new values
  MERGED_ENV="$(yq --output-format json --input-format json '. * { "swift-package-name": strenv(SWIFT_PACKAGE_NAME), "swift-package-binary-name": strenv(SWIFT_PACKAGE_BINARY_NAME), "swift-has-build-artifacts": env(SWIFT_HAS_BUILD_ARTIFACTS) }' <<< "${MERGED_ENV}")"
  echo "MERGED_ENV=${MERGED_ENV}"
}

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

function resolve_package_version() {
  echo "Resolving Package Version"
  local version_file
  version_file=$(version_filename)
  if [ -z "${version_file}" ]; then
    echo "Can't find version file"
    return 0
  fi

  export PACKAGE_VERSION PACKAGE_VERSION_IS_PRERELEASE
  PACKAGE_VERSION="$(tr -d '[:space:]' < "${version_file}")"
  if [[ -z ${PACKAGE_VERSION} ]]; then
    return 0
  fi

  if [[ ${PACKAGE_VERSION} == *"-"* ]]; then
    PACKAGE_VERSION_IS_PRERELEASE=true
  else
    PACKAGE_VERSION_IS_PRERELEASE=false
  fi

  echo "  Updating MERGED_ENV with the new values"
  # Update MERGED_ENV with the new values
  MERGED_ENV="$(yq --output-format json --input-format json '. * { "package-version": strenv(PACKAGE_VERSION), "package-version-is-prerelease": env(PACKAGE_VERSION_IS_PRERELEASE) }' <<< "${MERGED_ENV}")"
  echo "MERGED_ENV=${MERGED_ENV}"
}

function resolve_container_image() {
  echo "Resolving Container Image"

  export CONTAINER_IMAGE_NAME CONTAINER_IMAGE_TAG SWIFT_TOOLCHAIN_SELECTOR
  # An image that is named already is a pin, which the resolver keeps.
  CONTAINER_IMAGE_NAME="$(env_value "container-image-name")"
  CONTAINER_IMAGE_TAG="$(env_value "container-image-tag")"

  # The merged environment, not the shell variable, is what becomes the `swift-version` output, so
  # reading the version from there keeps the image and the version from disagreeing.
  local VERSION
  VERSION="$(env_value "swift-version")"

  # A bare call would end the job with the stderr line of the resolver as its only trace.
  if ! resolve_swift_container_image "${VERSION}"; then
    echo "::error::Cannot resolve a Linux container image for Swift '${VERSION}'"
    exit 1
  fi

  if [[ ${CONTAINER_IMAGE_NAME} == "swiftlang/swift" ]]; then
    echo "::warning::Swift ${VERSION} has no released container image. Using ${CONTAINER_IMAGE_NAME}:${CONTAINER_IMAGE_TAG}."
  fi

  SWIFT_TOOLCHAIN_SELECTOR="$(swift_toolchain_selector "${VERSION}" "${CONTAINER_IMAGE_NAME}" "${CONTAINER_IMAGE_TAG}")"

  echo "  Container image: ${CONTAINER_IMAGE_NAME}:${CONTAINER_IMAGE_TAG}"
  echo "  Swift toolchain selector: ${SWIFT_TOOLCHAIN_SELECTOR}"

  echo "  Updating MERGED_ENV with the new values"
  # Update MERGED_ENV with the new values
  MERGED_ENV="$(yq --output-format json --input-format json '. * { "container-image-name": strenv(CONTAINER_IMAGE_NAME), "container-image-tag": strenv(CONTAINER_IMAGE_TAG), "swift-toolchain-selector": strenv(SWIFT_TOOLCHAIN_SELECTOR) }' <<< "${MERGED_ENV}")"
  echo "MERGED_ENV=${MERGED_ENV}"
}

resolve_package_version
if [ -z "${SWIFT_VERSION}" ]; then
  resolve_swift_version
fi
resolve_container_image
if [[ -z ${SWIFT_PACKAGE_NAME} || -z ${SWIFT_PACKAGE_BINARY_NAME} || -z ${SWIFT_HAS_BUILD_ARTIFACTS} ]]; then
  resolve_swift_dynamic_env
fi

echo "Filtering out empty values"
MERGED_ENV="$(jq 'with_entries(select(.value != null and .value != "" and .value != [] and .value != {}))' <<< "${MERGED_ENV}")"
echo "MERGED_ENV=${MERGED_ENV}"

# Do echo of keys and values to GITHUB_OUTPUT from MERGED_ENV
ENV_OUTPUT=$(jq -r '
  to_entries[]
  | .key as $k
  | .value as $v
  | ($v | tostring)
  | if test("\n") then
      "\($k)<<EOF\n\(.)\nEOF"
    else
      "\($k)=\(.)"
    end
' <<< "${MERGED_ENV}")

echo "${ENV_OUTPUT}" >> "${GITHUB_OUTPUT}"
