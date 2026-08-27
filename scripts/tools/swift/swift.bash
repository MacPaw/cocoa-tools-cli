#!/usr/bin/env bash

# Usage: swift.bash [SCRIPT OPTIONS] -- [SWIFTPM ARGS]
#
# Script options (long options take their value with `=`):
#   -a, --action=<action>            build | test | trust | update-trust
#   -c, --configuration=<config>     debug | release (default: debug)
#   -p, --product=<product>          product to build, required by --output
#       --libc-implementation=<libc> musl | gnu, target libc of the built binary
#       --arch=<arch>                target architecture, required by musl
#       --output=<directory>         directory the built product is copied into
#
# Arguments after `--` are forwarded to SwiftPM as-is. Target selection is a script option so
# that it can be expanded into the matching SwiftPM flags, so passing `--arch`,
# `--libc-implementation`, `--product` or `-p` after `--` is rejected.

set -Eeo pipefail

PLATFORM="${PLATFORM:-"$(uname -s)"}"

if command -v swiftly > /dev/null 2>&1; then
  SWIFT_COMMAND="swiftly run swift"
else
  if command -v swift > /dev/null 2>&1; then
    SWIFT_COMMAND="swift"
  elif [[ -f /usr/bin/swift ]]; then
    SWIFT_COMMAND="/usr/bin/swift"
  else
    echo "Swift binary not found"
    exit 1
  fi
fi

# shellcheck source=./scripts/tools/swift/spm-trust.bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/spm-trust.bash"
# shellcheck source=./scripts/tools/swift/static-sdk.bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/static-sdk.bash"

die() {
  echo "${*}" >&2
  exit 2
} # complain to STDERR and exit with error
needs_arg() { if [ -z "$OPTARG" ]; then die "No arg for --${OPTSPEC} option"; fi; }

swift_install_musl_sdk() {
  local ARTIFACT_BUNDLE_FILE SWIFT_SDK_FOLDER SWIFT_VERSION_SHORT SDK_URL
  SWIFT_VERSION_SHORT="$(swift_pinned_version)"

  echo "SWIFT_VERSION_SHORT: ${SWIFT_VERSION_SHORT}"

  SWIFT_SDK_FOLDER="$(swift_static_sdk_bundle_id)"
  ARTIFACT_BUNDLE_FILE="${SWIFT_SDK_FOLDER}.artifactbundle"

  if ! ${SWIFT_COMMAND} sdk list | grep "${SWIFT_SDK_FOLDER}" > /dev/null; then
    if ! which curl > /dev/null 2>&1; then
      echo "Installing curl..."
      if [ "${PLATFORM}" == "Linux" ]; then
        apt-get update && apt-get install -y curl
      else
        brew install curl
      fi
    fi

    SDK_URL="https://download.swift.org/swift-${SWIFT_VERSION_SHORT}-release/static-sdk/swift-${SWIFT_VERSION_SHORT}-RELEASE/${ARTIFACT_BUNDLE_FILE}.tar.gz"
    echo "SDK URL:        ${SDK_URL}"

    echo "Downloading Swift SDK..."
    curl --output "/tmp/${ARTIFACT_BUNDLE_FILE}.tar.gz" "${SDK_URL}"

    echo "Computing checksum..."
    local CHECKSUM
    if [[ ${SWIFT_VERSION_SHORT} == "6.3.3" ]]; then
      CHECKSUM="87c3eaf908e67c0e13a84367119e12273cec1d2cd3d81f7d74bb36722d6b607b"
    else
      echo "Computing checksum with Swift..."
      CHECKSUM="$(swift package compute-checksum "/tmp/${ARTIFACT_BUNDLE_FILE}.tar.gz")"
    fi

    echo "Installing Swift SDK..."
    ${SWIFT_COMMAND} sdk install "/tmp/${ARTIFACT_BUNDLE_FILE}.tar.gz" --checksum "${CHECKSUM}"

    rm -rf "/tmp/${ARTIFACT_BUNDLE_FILE}.tar.gz"
  fi

  ${SWIFT_COMMAND} sdk list
  echo "Swift SDK installed"
}

# Directories `swift sdk install` keeps its bundles in, Linux first, then Darwin.
SWIFT_SDK_STORES=(
  "${HOME}/.swiftpm/swift-sdks"
  "${HOME}/Library/org.swift.swiftpm/swift-sdks"
)

# `--swift-sdk` filters by artifact ID or by target triple, and both are ambiguous on their own:
# the static Linux SDK ships one artifact with a sysroot per architecture, so its ID matches both
# of them, while its triples are also provided by the bundles of every other installed toolchain
# version. Filtering by triple within a store holding only the bundle for `.swift-version` is
# unambiguous in both directions. Sets PINNED_SWIFT_SDKS_PATH.
swift_pin_static_sdk_store() {
  local BUNDLE_NAME STORE CANDIDATE
  BUNDLE_NAME="$(swift_static_sdk_bundle_id).artifactbundle"
  STORE=""

  for CANDIDATE in "${SWIFT_SDK_STORES[@]}"; do
    if [ -d "${CANDIDATE}/${BUNDLE_NAME}" ]; then
      STORE="${CANDIDATE}"
      break
    fi
  done

  if [ -z "${STORE}" ]; then
    die "Swift SDK bundle ${BUNDLE_NAME} not found in ${SWIFT_SDK_STORES[*]}"
  fi

  PINNED_SWIFT_SDKS_PATH="${PWD}/.build/pinned-swift-sdks"

  rm -rf "${PINNED_SWIFT_SDKS_PATH}"
  mkdir -p "${PINNED_SWIFT_SDKS_PATH}"
  ln -s "${STORE}/${BUNDLE_NAME}" "${PINNED_SWIFT_SDKS_PATH}/${BUNDLE_NAME}"
}

swift_validate_options() {
  case "${LIBC_IMPLEMENTATION}" in
    "" | musl | gnu) ;;
    *)
      die "Unsupported --libc-implementation: ${LIBC_IMPLEMENTATION}. Supported values: musl, gnu"
      ;;
  esac

  if [ "${LIBC_IMPLEMENTATION}" == "musl" ] && [ -z "${ARCH}" ]; then
    die "--libc-implementation=musl requires --arch, the static Linux SDK is always cross-compiled"
  fi

  if [ -n "${PRODUCT}" ] && [ "${ACTION}" != "build" ]; then
    die "--product is only supported by --action=build"
  fi

  if [ -n "${OUTPUT}" ]; then
    if [ "${ACTION}" != "build" ]; then
      die "--output is only supported by --action=build"
    fi

    if [ -z "${PRODUCT}" ]; then
      die "--output requires --product to know which binary to copy"
    fi

    if [ -e "${OUTPUT}" ] && [ ! -d "${OUTPUT}" ]; then
      die "--output must be a directory, but ${OUTPUT} is an existing file"
    fi
  fi

  local ARG
  for ARG in "${EXTRA_ARGS[@]}"; do
    case "${ARG}" in
      -p | --arch | --arch=* | --libc-implementation | --libc-implementation=* | --product | --product=*)
        die "Pass ${ARG%%=*} as a script option before \`--\`, not as a SwiftPM argument"
        ;;
    esac
  done
}

swift_run_build_or_tests() {
  local EXTRA_SWIFTPM_ARGS=("${@}")
  local DEFAULT_ARGS TARGET_ARGS BIN_DIR USE_STATIC_SWIFT_STDLIB

  DEFAULT_ARGS=(
    "--enable-experimental-prebuilts"
    "--configuration" "${CONFIGURATION}"
    "-debug-info-format" "none"
    "--manifest-cache" "local"
  )

  TARGET_ARGS=()
  USE_STATIC_SWIFT_STDLIB=false

  if [ "${LIBC_IMPLEMENTATION}" == "musl" ]; then
    swift_install_musl_sdk
    swift_pin_static_sdk_store

    TARGET_ARGS+=(
      "--swift-sdks-path" "${PINNED_SWIFT_SDKS_PATH}"
      "--swift-sdk" "$(swift_linux_triple musl "${ARCH}")"
    )
    USE_STATIC_SWIFT_STDLIB=true
  elif [ -n "${ARCH}" ]; then
    TARGET_ARGS+=("--arch" "${ARCH}")
  fi

  if [ "${PLATFORM}" == "Linux" ]; then
    USE_STATIC_SWIFT_STDLIB=true
  fi

  if [ "${ACTION}" == "build" ]; then
    if [ "${CONFIGURATION}" == "release" ]; then
      DEFAULT_ARGS+=(
        "--disable-code-coverage"
        "--disable-xctest"
        "--disable-swift-testing"
      )

      if [ "${USE_STATIC_SWIFT_STDLIB}" == "true" ]; then
        DEFAULT_ARGS+=("--static-swift-stdlib")
      fi
    fi

    if [ "${LIBC_IMPLEMENTATION}" == "musl" ]; then
      # The static Linux SDK ships its archives with debug info, which the linker copies in and
      # `-debug-info-format none` does not affect: it is around half of the linked binary. `-S`
      # makes the linker drop those sections instead.
      DEFAULT_ARGS+=("-Xlinker" "-S")
    fi

    if [ -n "${PRODUCT}" ]; then
      DEFAULT_ARGS+=("--product" "${PRODUCT}")
    fi
  elif [ "${ACTION}" == "test" ]; then
    DEFAULT_ARGS+=(
      "--enable-code-coverage"
    )

    if [ "${PLATFORM}" == "Linux" ]; then
      DEFAULT_ARGS+=(
        "--enable-swift-testing"
        "--enable-xctest"
      )
    fi
  fi

  echo "${SWIFT_COMMAND} ${ACTION} ${DEFAULT_ARGS[*]} ${TARGET_ARGS[*]} ${EXTRA_SWIFTPM_ARGS[*]}"
  ${SWIFT_COMMAND} "${ACTION}" "${DEFAULT_ARGS[@]}" "${TARGET_ARGS[@]}" "${EXTRA_SWIFTPM_ARGS[@]}"

  if [ -n "${OUTPUT}" ]; then
    echo "${SWIFT_COMMAND} build --configuration ${CONFIGURATION} ${TARGET_ARGS[*]} --show-bin-path"
    BIN_DIR="$(${SWIFT_COMMAND} build --configuration "${CONFIGURATION}" "${TARGET_ARGS[@]}" --show-bin-path | tr -d '[:space:]')"

    if [[ "$(realpath "${BIN_DIR}/${PRODUCT}")" != "$(realpath "${OUTPUT}/${PRODUCT}")" ]]; then
      echo "Copying ${PRODUCT} from ${BIN_DIR} to ${OUTPUT}..."
      mkdir -p "${OUTPUT}"
      cp "${BIN_DIR}/${PRODUCT}" "${OUTPUT}/${PRODUCT}"
      chmod +x "${OUTPUT}/${PRODUCT}"
    fi
  fi
}

# Target selection is intentionally not read from the environment: `ARCH` and friends are set
# for other purposes by the container tooling that also runs this script.
LIBC_IMPLEMENTATION=""
ARCH=""
PRODUCT=""
OUTPUT=""

while getopts "a:c:p:-:" OPTSPEC; do

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
    p | product)
      needs_arg
      PRODUCT=$OPTARG
      ;;
    libc-implementation)
      needs_arg
      LIBC_IMPLEMENTATION=$OPTARG
      ;;
    arch)
      needs_arg
      ARCH=$OPTARG
      ;;
    output)
      needs_arg
      OUTPUT=$OPTARG
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

swift_validate_options

case "${ACTION}" in
  build | test)
    swift_run_build_or_tests "${EXTRA_ARGS[@]}"
    ;;
  trust)
    spm_trust
    ;;
  update-trust)
    spm_update_trust
    ;;
  *)
    die "Unknown action: ${ACTION}"
    ;;
esac
