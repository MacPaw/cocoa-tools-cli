#!/usr/bin/env bash

set -Eeo pipefail

PLATFORM="$(uname -s | tr '[:upper:]' '[:lower:]')"

if [[ ${PLATFORM} == "darwin" ]]; then
  echo "Swiftly dependencies already installed on macOS"
  exit 0
fi

if [[ "$(id -un)" != 'root' ]]; then
  SUDO=sudo
fi
if command -v apt-get > /dev/null; then
  # use DEBIAN_FRONTEND to prevent Debian/Ubuntu installs from hanging on tzdata
  CMD='env DEBIAN_FRONTEND=noninteractive apt-get -qy'
  # shellcheck disable=SC2086
  ${SUDO} ${CMD} update
elif command -v dnf > /dev/null; then
  CMD='dnf -y'
  # shellcheck disable=SC2086
  ${SUDO} ${CMD} --refresh mc
elif command -v yum > /dev/null; then
  CMD='yum -y'
  # shellcheck disable=SC2086
  ${SUDO} ${CMD} makecache
elif command -v brew > /dev/null; then
  CMD='brew'
  CMD_OPTIONS='--yes'
  # shellcheck disable=SC2086
  ${SUDO} ${CMD} update --yes
else
  echo "Couldn't figure out how to run the system package manager."
  exit 1
fi

REQUIRED_DEPENDENCIES=(
  "curl"
  "gpg"
)

for DEPENDENCY in "${REQUIRED_DEPENDENCIES[@]}"; do
  command -v "${DEPENDENCY}" > /dev/null || {
    echo "Installing ${DEPENDENCY}"
    # shellcheck disable=SC2086
    ${SUDO} ${CMD} install ${CMD_OPTIONS} "${DEPENDENCY}"
  }
done
