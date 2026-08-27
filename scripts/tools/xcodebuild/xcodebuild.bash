#!/usr/bin/env bash

set -Eeo pipefail

# `xcodebuild` compiles with the toolchain Xcode ships, which can differ from the one `.swift-version` pins.
# A different compiler also selects a different version-specific manifest, which resolves different
# swift-syntax majors and rewrites `Package.resolved`. `TOOLCHAINS` keeps it on the pinned toolchain, but it
# takes a bundle identifier that no string operation derives from a version number (Swift 6.3 is
# `org.swift.630202603201a`), so the identifier is read from the toolchain bundle itself. Both
# swiftly-installed and Xcode-installed toolchains live in the same folder. An answer of nothing means the
# version has no installed toolchain, and Xcode's own is used.
resolve_toolchain_identifier() {
  local VERSION="${1}" TOOLCHAINS_DIR CANDIDATE IDENTIFIER

  if [[ -z ${VERSION} || ${VERSION} == "xcode" ]]; then
    return 0
  fi

  TOOLCHAINS_DIR="${HOME}/Library/Developer/Toolchains"
  for CANDIDATE in \
    "${TOOLCHAINS_DIR}/swift-${VERSION}-RELEASE.xctoolchain" \
    "${TOOLCHAINS_DIR}/swift-${VERSION%.0}-RELEASE.xctoolchain" \
    "${TOOLCHAINS_DIR}/swift-${VERSION}"*.xctoolchain; do
    if [[ ! -f "${CANDIDATE}/Info.plist" ]]; then
      continue
    fi
    # A standalone Swift toolchain ships `clang` but no linker, and under `TOOLCHAINS` that `clang` looks for
    # `ld` beside itself instead of falling back to Xcode's. SwiftPM compiles *and links* the manifest before
    # anything else, so the whole run dies at package resolution with
    # `clang: error: unable to execute command: posix_spawn failed: No such file or directory`. Measured with
    # swift-6.3-RELEASE.xctoolchain, which has `clang` and `ld64.lld` but no `ld`. Xcode's own toolchain is used
    # instead, which is a version difference; a run that cannot resolve its packages is no version at all.
    if [[ ! -x "${CANDIDATE}/usr/bin/ld" ]]; then
      echo "Toolchain ${CANDIDATE##*/} ships no linker, so xcodebuild uses the toolchain of Xcode." >&2
      return 0
    fi
    IDENTIFIER="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "${CANDIDATE}/Info.plist" 2> /dev/null)"
    if [[ -n ${IDENTIFIER} ]]; then
      echo "${IDENTIFIER}"
      return 0
    fi
  done

  echo "No installed toolchain for Swift ${VERSION}. xcodebuild uses the toolchain of Xcode." >&2
}

xcodebuild_run() {
  local DEFAULT_ARGS=(
    # Scheme and configuration
    "-scheme" "${SWIFT_PACKAGE_NAME}-Package"
    "-configuration" "${CONFIGURATION}"

    # Destination
    "-destination" "platform=macOS"

    # Allow third-party macros
    "-skipMacroValidation"

    # Build speed-up
    "RUN_CLANG_STATIC_ANALYZER=NO"
    "COMPILER_INDEX_STORE_ENABLE=NO"

    # Tests speed-up
    "-collect-test-diagnostics" "never"
  )

  if [[ -n ${DERIVED_DATA_PATH} ]]; then
    DEFAULT_ARGS+=("-derivedDataPath" "${DERIVED_DATA_PATH}")
  fi

  local TOOLCHAIN_IDENTIFIER
  TOOLCHAIN_IDENTIFIER="$(resolve_toolchain_identifier "${SWIFT_VERSION:-}")"

  if [[ -n ${TOOLCHAIN_IDENTIFIER} ]]; then
    echo "TOOLCHAINS=${TOOLCHAIN_IDENTIFIER} xcodebuild ${DEFAULT_ARGS[*]} ${*}"
    TOOLCHAINS="${TOOLCHAIN_IDENTIFIER}" xcodebuild "${DEFAULT_ARGS[@]}" "${@}"
    return
  fi

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
      SWIFT_PACKAGE_NAME=$OPTARG
      ;;
    c | configuration)
      needs_arg
      CONFIGURATION=$OPTARG
      ;;
    *) ;;
  esac
done

SWIFT_PACKAGE_NAME="${SWIFT_PACKAGE_NAME:?"ENV var SWIFT_PACKAGE_NAME is unset or empty, or -p --package-name= argument is not passed"}"
CONFIGURATION="${CONFIGURATION:-"Debug"}"
ACTION="${ACTION:?"ENV var ACTION is unset or empty, or -a --action= argument is not passed"}"

for ARG in "${@}"; do
  if [[ ${IS_EXTRA_ARGS} == "true" ]]; then
    EXTRA_ARGS+=("${ARG}")
  fi

  if [[ ${ARG} == '--' ]]; then
    IS_EXTRA_ARGS=true
  fi
done

xcodebuild_run "${EXTRA_ARGS[@]}" "${ACTION}"
