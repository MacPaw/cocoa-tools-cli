#!/usr/bin/env bash
# Swift package metadata from `swift package dump-package`.
# Sourced by mise with tools = true so `swift` / `jq` are on PATH.

# Re-entrancy guard: `swift` is a mise shim, so calling it from here makes mise
# re-evaluate this env script, which calls `swift` again, forking forever (hangs git hooks).
# The guard is unset again at the end so it never leaks into the resolved environment.
if [[ -n ${MPCT_MISE_ENV_RESOLVING:-} ]]; then
  return 0
fi
export MPCT_MISE_ENV_RESOLVING=1

export SWIFT_VERSION

# Derive the root from this file (.config/mise/env/dynamic), not cwd or git: hooks run from other dirs.
REPOSITORY_ROOT_DIR="${REPOSITORY_ROOT_DIR:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"}"

echo "Resolving Swift Version"
if [[ -f "${REPOSITORY_ROOT_DIR}/.swift-version" ]]; then
  echo "  Resolving Swift Version from .swift-version"
  SWIFT_VERSION="$(cat "${REPOSITORY_ROOT_DIR}/.swift-version")"
  echo "    SWIFT_VERSION=${SWIFT_VERSION}"
fi
if [[ ${SWIFT_VERSION} == "xcode" ]] && which xcrun > /dev/null; then
  echo "  Resolving Swift Version from xcrun"
  SWIFT_VERSION="$(xcrun swift -version 2> /dev/null | grep 'Apple Swift version' | awk '{print $4}')"
  echo "    SWIFT_VERSION=${SWIFT_VERSION}"
fi

if [[ -z ${SWIFT_VERSION} ]]; then
  echo "  Resolving Swift Version from swift"
  SWIFT_VERSION="$(swift -version 2> /dev/null | grep 'Apple Swift version' | awk '{print $4}')"
  echo "    SWIFT_VERSION=${SWIFT_VERSION}"
fi

SWIFT_VERSION="$(echo "${SWIFT_VERSION}" | tr -d '[:space:]')"
# if SWIFT_VERSION is short e.g. 6.4 (one dot), set it to 6.4.0.
# Check the dot count
if [[ $(echo "${SWIFT_VERSION}" | grep -o '\.' | wc -l) -eq 1 ]]; then
  echo "  SWIFT_VERSION is short, setting to ${SWIFT_VERSION}.0"
  SWIFT_VERSION="${SWIFT_VERSION}.0"
  echo "    SWIFT_VERSION=${SWIFT_VERSION}"
fi
SWIFT_VERSION="${SWIFT_VERSION:-"6.3.3"}"
echo "SWIFT_VERSION=${SWIFT_VERSION}"
export SWIFT_VERSION
unset MPCT_MISE_ENV_RESOLVING
