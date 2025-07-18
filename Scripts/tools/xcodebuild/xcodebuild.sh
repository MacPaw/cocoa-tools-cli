#!/usr/bin/env bash

set -Eeo pipefail

xcodebuild_run() {
  local DEFAULT_ARGS=(
    # Scheme and configuration
    "-scheme" "${PACKAGE_NAME}-Package"
    "-configuration" "${CONFIGURATION}"

    # Destination
    "-destination" "platform=macOS"

    # Custom derived data path
    "-derivedDataPath" "DerivedData"

    # Allow third-party macros
    "-skipMacroValidation"

    # Don't update packages to newer versions, and use Package.resolved file
    "-skipPackageUpdates"
    "-disableAutomaticPackageResolution"

    # Build speed-up
    "RUN_CLANG_STATIC_ANALYZER=NO"
    "COMPILER_INDEX_STORE_ENABLE=NO"

    # Tests speed-up
    "-collect-test-diagnostics" "never"
  )

  echo "xcodebuild ${DEFAULT_ARGS[*]} ${*}"
  xcodebuild "${DEFAULT_ARGS[@]}" "${@}"
}

ACTION=
EXTRA_ARGS=()
die() {
  echo "${*}" >&2
  exit 2
} # complain to STDERR and exit with error
needs_arg() { if [ -z "$OPTARG" ]; then die "No arg for --${OPTSPEC} option"; fi; }

while getopts "a:p:c:-:" OPTSPEC; do

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
    p | package-name)
      needs_arg
      PACKAGE_NAME=$OPTARG
      ;;
    c | configuration)
      needs_arg
      CONFIGURATION=$OPTARG
      ;;
    *) ;;
  esac
done

PACKAGE_NAME="${PACKAGE_NAME:?"ENV var PACKAGE_NAME is unset or empty, or -p --package-name= argument is not passed"}"
CONFIGURATION="${CONFIGURATION:-"Debug"}"
ACTION="${ACTION:?"ENV var ACTION is unset or empty, or -a --action= argument is not passed"}"

for ARG in "${@}"; do
  if [ "${IS_EXTRA_ARGS}" == "true" ]; then
    EXTRA_ARGS+=("${ARG}")
  fi

  if [[ ${ARG} == '--' ]]; then
    IS_EXTRA_ARGS=true
  fi
done

xcodebuild_run "${EXTRA_ARGS[@]}" "${ACTION}"
