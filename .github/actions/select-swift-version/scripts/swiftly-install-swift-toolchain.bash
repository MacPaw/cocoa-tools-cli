#!/usr/bin/env bash

set -Eeo pipefail

# swiftly has no release toolchain for a version that is not released yet, so a job that runs a
# nightly image passes the matching snapshot selector instead of the version.
TOOLCHAIN="${SWIFT_TOOLCHAIN_SELECTOR:-${SWIFT_VERSION}}"

echo "Installing Swift ${TOOLCHAIN}"
POST_INSTALL_FILE="post-install-swift.bash"

"${SWIFTLY_BIN_DIR}/swiftly" install \
  --verify \
  --use \
  --post-install-file "${POST_INSTALL_FILE}" \
  --assume-yes \
  "${TOOLCHAIN}"

if [[ -f ${POST_INSTALL_FILE} ]]; then
  echo "  Post-install file found"
  if [[ "$(id -un)" == 'root' ]]; then
    echo "  Running post-install file as root"
    env DEBIAN_FRONTEND=noninteractive bash "${POST_INSTALL_FILE}"
  else
    echo "  Running post-install file as user"
    sudo env DEBIAN_FRONTEND=noninteractive bash "${POST_INSTALL_FILE}" # use the current value of HOME, not root's
  fi
  rm "${POST_INSTALL_FILE}"
else
  echo "  Post-install file not found"
fi

echo "Swift ${TOOLCHAIN} toolchain installed"
