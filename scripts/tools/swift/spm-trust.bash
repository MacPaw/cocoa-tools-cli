#!/usr/bin/env bash

set -Eeo pipefail

PLATFORM="${PLATFORM:-"$(uname -s)"}"

SOURCE_TRUST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/security"

if [ "$PLATFORM" == "Darwin" ]; then
  SPM_CACHE_DIR="${HOME}/Library/org.swift.swiftpm"
else
  SPM_CACHE_DIR="${HOME}/.cache/org.swift.swiftpm"
fi

SPM_TRUST_DIR="${SPM_CACHE_DIR}/security"

function update_trust_info() {
  echo "Getting trust info for ${1}" >&2

  if [ ! -f "${SOURCE_TRUST_DIR}/${1}" ]; then
    echo "  File ${SOURCE_TRUST_DIR}/${1} does not exist, skipping..." >&2
    return
  fi

  local TRUSTED_INFO LENGTH INDEX INDICES_TO_REMOVE
  INDICES_TO_REMOVE=()
  TRUSTED_INFO="$(jq '.' < "${SOURCE_TRUST_DIR}/${1}")"
  LENGTH=$(jq '. | length' < "${SOURCE_TRUST_DIR}/${1}" | tr -d '[:space:]')
  echo "  Element count: $LENGTH" >&2

  for ((INDEX = 0; INDEX < LENGTH; INDEX++)); do
    echo "  Index: ${INDEX}" >&2
    local TARGET_NAME PACKAGE_NAME FINGERPRINT EXISTING_FINGERPRINT PACKAGE_FINGERPRINT TRUSTED_INFO_ITEM EXISTING_TRUSTED_INFO_ITEM

    TARGET_NAME="$(jq -r ".[${INDEX}].targetName" <<< "${TRUSTED_INFO}" | tr -d '[:space:]')"
    echo "    Target name: $TARGET_NAME" >&2

    PACKAGE_NAME="$(jq -r ".[${INDEX}].packageIdentity" <<< "${TRUSTED_INFO}" | tr -d '[:space:]')"
    echo "    Package name: $PACKAGE_NAME" >&2

    # Get fingerprint from source file, if not found, get it from Package.resolved.
    EXISTING_FINGERPRINT="$(jq -r ".[${INDEX}].fingerprint" <<< "${TRUSTED_INFO}" | tr -d '[:space:]')"

    PACKAGE_FINGERPRINT=$(jq -r ".pins[] | select(.identity==\"${PACKAGE_NAME}\") | .state.revision" < Package.resolved | tr -d '[:space:]')
    if [ -z "$PACKAGE_FINGERPRINT" ]; then
      echo "    Fingerprint for target ${TARGET_NAME} in package ${PACKAGE_NAME} is empty, skipping..." >&2
      INDICES_TO_REMOVE+=("${INDEX}")
      continue
    else
      echo "    Fingerprint: ${PACKAGE_FINGERPRINT}" >&2
    fi

    if [[ ${EXISTING_FINGERPRINT} != "${PACKAGE_FINGERPRINT}" ]]; then
      echo "    Fingerprint for target ${TARGET_NAME} in package ${PACKAGE_NAME} is different, updating..." >&2
      FINGERPRINT="$PACKAGE_FINGERPRINT"
      INDICES_TO_REMOVE+=("${INDEX}")
    else
      echo "    Fingerprint for target ${TARGET_NAME} in package ${PACKAGE_NAME} is the same, skipping..." >&2
      continue
    fi

    EXISTING_TRUSTED_INFO_ITEM="$(jq -r ".[] | select((.fingerprint==\"${FINGERPRINT}\") and (.packageIdentity==\"${PACKAGE_NAME}\") and (.targetName==\"${TARGET_NAME}\"))" <<< "${TRUSTED_INFO}" | tr -d '[:space:]')"

    if [ -z "${EXISTING_TRUSTED_INFO_ITEM}" ]; then
      echo "    Adding trust info item for target ${TARGET_NAME} in package ${PACKAGE_NAME}..." >&2
    else
      echo "    Trusted info item for target ${TARGET_NAME} in package ${PACKAGE_NAME} is already in the list, skipping..." >&2
      continue
    fi

    TRUSTED_INFO_ITEM="{\"fingerprint\": \"${FINGERPRINT}\", \"packageIdentity\": \"${PACKAGE_NAME}\", \"targetName\": \"${TARGET_NAME}\"}"

    TRUSTED_INFO="$(jq ". += [${TRUSTED_INFO_ITEM}]" <<< "${TRUSTED_INFO}")"

  done

  REMOVED_COUNT=0
  for INDEX in "${INDICES_TO_REMOVE[@]}"; do
    echo "  Removing outdated trust info item at index: ${INDEX}" >&2
    # Adjust index for removed items
    INDEX=$((INDEX - REMOVED_COUNT))
    TRUSTED_INFO="$(jq "del(.[${INDEX}])" <<< "${TRUSTED_INFO}")"
    REMOVED_COUNT=$((REMOVED_COUNT + 1))
  done
  echo "  Removed ${REMOVED_COUNT} outdated trust info items" >&2

  jq "." <<< "${TRUSTED_INFO}" > "${SOURCE_TRUST_DIR}/${1}"
}

function merge_trust_info() {
  local FILE="${1}"
  local DEST_FILE="${SPM_TRUST_DIR}/${FILE}"
  local SOURCE_FILE="${SOURCE_TRUST_DIR}/${FILE}"

  if [ ! -f "${SOURCE_FILE}" ]; then
    echo "  File ${SOURCE_FILE} does not exist, skipping..." >&2
    return
  fi

  if [ ! -f "${DEST_FILE}" ]; then
    echo "  Destination ${DEST_FILE} does not exist yet, creating from source..." >&2
    cp "${SOURCE_FILE}" "${DEST_FILE}"
    return
  fi

  echo "  Merging ${FILE}..." >&2
  local SOURCE_TRUSTED_INFO DEST_TRUSTED_INFO LENGTH INDEX
  SOURCE_TRUSTED_INFO="$(jq '.' < "${SOURCE_FILE}")"
  DEST_TRUSTED_INFO="$(jq '.' < "${DEST_FILE}")"
  LENGTH=$(jq '. | length' <<< "${SOURCE_TRUSTED_INFO}" | tr -d '[:space:]')
  echo "    Source element count: $LENGTH" >&2

  for ((INDEX = 0; INDEX < LENGTH; INDEX++)); do
    local TARGET_NAME PACKAGE_NAME FINGERPRINT EXISTING_TRUSTED_INFO_ITEM TRUSTED_INFO_ITEM

    TARGET_NAME="$(jq -r ".[${INDEX}].targetName" <<< "${SOURCE_TRUSTED_INFO}" | tr -d '[:space:]')"
    PACKAGE_NAME="$(jq -r ".[${INDEX}].packageIdentity" <<< "${SOURCE_TRUSTED_INFO}" | tr -d '[:space:]')"
    FINGERPRINT="$(jq -r ".[${INDEX}].fingerprint" <<< "${SOURCE_TRUSTED_INFO}" | tr -d '[:space:]')"

    EXISTING_TRUSTED_INFO_ITEM="$(jq -r ".[] | select((.fingerprint==\"${FINGERPRINT}\") and (.packageIdentity==\"${PACKAGE_NAME}\") and (.targetName==\"${TARGET_NAME}\"))" <<< "${DEST_TRUSTED_INFO}" | tr -d '[:space:]')"

    if [ -z "${EXISTING_TRUSTED_INFO_ITEM}" ]; then
      echo "    Adding trust info item for target ${TARGET_NAME} in package ${PACKAGE_NAME}..." >&2
      TRUSTED_INFO_ITEM="{\"fingerprint\": \"${FINGERPRINT}\", \"packageIdentity\": \"${PACKAGE_NAME}\", \"targetName\": \"${TARGET_NAME}\"}"
      DEST_TRUSTED_INFO="$(jq ". += [${TRUSTED_INFO_ITEM}]" <<< "${DEST_TRUSTED_INFO}")"
    else
      echo "    Trusted info item for target ${TARGET_NAME} in package ${PACKAGE_NAME} already in destination, skipping..." >&2
    fi
  done

  jq "." <<< "${DEST_TRUSTED_INFO}" > "${DEST_FILE}"
}

function spm_trust() {
  echo "Trusting Swift Package Macros and Plugins..."
  mkdir -p "${SPM_TRUST_DIR}"
  merge_trust_info "macros.json"
  merge_trust_info "plugins.json"
}

function spm_update_trust() {
  echo "Updating trust for Swift Package Macros and Plugins..."

  update_trust_info "macros.json"
  update_trust_info "plugins.json"
}
