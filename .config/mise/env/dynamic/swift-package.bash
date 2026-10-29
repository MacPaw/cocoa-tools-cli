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

set SWIFT_PACKAGE_DUMP_JSON
echo "Dumping swift package"

if [[ "$(uname -s)" == "Darwin" ]] && command -v swiftly > /dev/null 2>&1 && command -v xcrun > /dev/null 2>&1; then
  SWIFT_PACKAGE_DUMP_JSON="$(swiftly run +xcode swift package dump-package)"
else
  SWIFT_PACKAGE_DUMP_JSON="$(swift package dump-package)"
fi

export SWIFT_PACKAGE_NAME
echo "Getting package name"
SWIFT_PACKAGE_NAME="$(jq -r .name <<< "${SWIFT_PACKAGE_DUMP_JSON}")"
echo "  SWIFT_PACKAGE_NAME=${SWIFT_PACKAGE_NAME}"

# First executable product name, or empty when the package has none.
export SWIFT_PACKAGE_BINARY_NAME
echo "Getting package binary name"
SWIFT_PACKAGE_BINARY_NAME="$(
  jq -r '[.products[] | select(.type | has("executable")) | .name] | first // empty' \
    <<< "${SWIFT_PACKAGE_DUMP_JSON}"
)"
if [ -z "${SWIFT_PACKAGE_BINARY_NAME}" ]; then
  unset SWIFT_PACKAGE_BINARY_NAME
fi
echo "  SWIFT_PACKAGE_BINARY_NAME=${SWIFT_PACKAGE_BINARY_NAME}"

export SWIFT_HAS_BUILD_ARTIFACTS
if [ -n "${SWIFT_PACKAGE_BINARY_NAME}" ]; then
  SWIFT_HAS_BUILD_ARTIFACTS="true"
else
  SWIFT_HAS_BUILD_ARTIFACTS="false"
fi
echo "  SWIFT_HAS_BUILD_ARTIFACTS=${SWIFT_HAS_BUILD_ARTIFACTS}"
unset MPCT_MISE_ENV_RESOLVING
