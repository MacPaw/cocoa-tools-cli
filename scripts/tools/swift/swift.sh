#!/usr/bin/env bash

set -Eeo pipefail

PLATFORM="${PLATFORM:-"$(uname -s)"}"

swift_install_sdk() {
  local ARTIFACT_BUNDLE_FILE SWIFT_VERSION SDKS_DIR PLATFORM
  SWIFT_VERSION="$(cat .swift-version | tr -d '[:space:]')"

  echo "Using Swift version: ${SWIFT_VERSION}"

  ARTIFACT_BUNDLE_FILE="swift-${SWIFT_VERSION}-RELEASE_static-linux-0.0.1.artifactbundle"

  if [ "${PLATFORM}" == "Linux" ]; then
    SDKS_DIR="/root/.swiftpm/swift-sdks"
  else
    SDKS_DIR="${HOME}/.swiftpm/swift-sdks"
  fi
  echo "SDKS_DIR: ${SDKS_DIR}"

  if [ ! swift sdk list | grep "${ARTIFACT_BUNDLE_FILE}" > /dev/null ]; then
    echo "Installing curl..."
    if ! which curl > /dev/null 2>&1; then
      if [ "${PLATFORM}" == "Linux" ]; then
        apt-get update && apt-get install -y curl
      else
        brew install curl
      fi
    fi

    echo "Downloading Swift SDK..."
    curl --output "/tmp/${ARTIFACT_BUNDLE_FILE}.tar.gz" \
      "https://download.swift.org/swift-${SWIFT_VERSION}-release/static-sdk/swift-${SWIFT_VERSION}-RELEASE/${ARTIFACT_BUNDLE_FILE}.tar.gz"

    echo "Computing checksum..."
    local CHECKSUM
    CHECKSUM="$(swift package compute-checksum "/tmp/${ARTIFACT_BUNDLE_FILE}.tar.gz")"

    echo "Installing Swift SDK..."
    swift sdk install "/tmp/${ARTIFACT_BUNDLE_FILE}.tar.gz" --checksum "${CHECKSUM}"

    rm -rf "/tmp/${ARTIFACT_BUNDLE_FILE}.tar.gz"
  fi

  echo "Swift SDK installed"
}

swift_run() {
  local DEFAULT_ARGS=(
    "--disable-automatic-resolution"
    "--enable-experimental-prebuilts"
    "--configuration" "${CONFIGURATION}"
    "--disable-index-store"
    "-debug-info-format" "none"
  )

  PLATFORM="${PLATFORM:-"$(uname -s)"}"
  if [ "${PLATFORM}" == "Linux" ]; then
    DEFAULT_ARGS+=("--static-swift-stdlib")
    DEFAULT_ARGS+=("--swift-sdk" "${SWIFT_SDK:-"x86_64-swift-linux-musl"}")
  fi

  if [ "${ACTION}" == "build" ]; then
    DEFAULT_ARGS+=("--disable-code-coverage")
    DEFAULT_ARGS+=("--disable-xctest")
  fi

  if [ "${PLATFORM}" == "Linux" ]; then
    swift_install_sdk
  fi

  SWIFT_BINARY="${SWIFT_BINARY:-"$(which swift || echo '/usr/bin/swift')"}"
  echo "${SWIFT_BINARY} ${ACTION} ${DEFAULT_ARGS[*]} ${*}"
  "$SWIFT_BINARY" "${ACTION}" "${DEFAULT_ARGS[@]}" "${@}"
}

die() {
  echo "${*}" >&2
  exit 2
} # complain to STDERR and exit with error
needs_arg() { if [ -z "$OPTARG" ]; then die "No arg for --${OPTSPEC} option"; fi; }

while getopts "a:c:-:" OPTSPEC; do

  # support long options: https://stackoverflow.com/a/28466267/519360
  if [ "$OPTSPEC" = "-" ]; then   # long option: reformulate OPT and OPTARG
    OPTSPEC="${OPTARG%%=*}"       # extract long option name
    OPTARG="${OPTARG#"$OPTSPEC"}" # extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"          # if long option argument, remove assigning `=`
  fi

  case "${OPTSPEC}" in
    a | action)
      needs_arg
      ACTION=$OPTARG
      ;;
    c | configuration)
      needs_arg
      CONFIGURATION=$OPTARG
      ;;
    *) ;;
  esac
done

ACTION="${ACTION:?"ENV var ACTION is unset or empty, or -a --action= argument is not passed"}"
CONFIGURATION="${CONFIGURATION:-"debug"}"

for ARG in "${@}"; do
  if [ "${IS_EXTRA_ARGS}" == "true" ]; then
    EXTRA_ARGS+=("${ARG}")
  fi

  if [[ ${ARG} == '--' ]]; then
    IS_EXTRA_ARGS=true
  fi
done

swift_run "${EXTRA_ARGS[@]}"
