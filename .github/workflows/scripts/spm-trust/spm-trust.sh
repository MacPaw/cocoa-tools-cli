#!/usr/bin/env bash

set -Eeo pipefail

PLATFORM=$(uname -s)

SOURCE_TRUST_DIR="$(dirname "${0}")/security"

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

  for INDEX in "${INDICES_TO_REMOVE[@]}"; do
    echo "  Removing outdated trust info item at index: ${INDEX}" >&2
    TRUSTED_INFO="$(jq "del(.[${INDEX}])" <<< "${TRUSTED_INFO}")"
  done

  jq "." <<< "${TRUSTED_INFO}" > "${SOURCE_TRUST_DIR}/${1}"
}

function spm_trust() {
  echo "Trusting Swift Package Macros and Plugins..."
  mkdir -p "${SPM_TRUST_DIR}"
  cp -r "${SOURCE_TRUST_DIR}/macros.json" "${SPM_TRUST_DIR}/macros.json"
  cp -r "${SOURCE_TRUST_DIR}/plugins.json" "${SPM_TRUST_DIR}/plugins.json"
}

function spm_update_trust() {
  echo "Updating trust for Swift Package Macros and Plugins..."

  update_trust_info "macros.json"
  update_trust_info "plugins.json"
}

die() {
  echo "${*}" >&2
  exit 2
} # complain to STDERR and exit with error
needs_arg() { if [ -z "${OPTARG}" ]; then die "No arg for --${OPTSPEC} option"; fi; }

while getopts "t:u:-:" OPTSPEC; do

  # support long options: https://stackoverflow.com/a/28466267/519360
  if [ "${OPTSPEC}" = "-" ]; then # long option: reformulate OPT and OPTARG
    OPTSPEC="${OPTARG%%=*}"       # extract long option name
    OPTARG="${OPTARG#"$OPTSPEC"}" # extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"          # if long option argument, remove assigning `=`
  fi

  case "${OPTSPEC}" in
    update-trust)
      spm_update_trust
      ;;
    trust)
      spm_trust
      ;;
    *)
      echo "Unknown option: ${OPTSPEC}" >&2
      echo "Supported options: --update-trust, --trust" >&2
      exit 1
      ;;
  esac
done
