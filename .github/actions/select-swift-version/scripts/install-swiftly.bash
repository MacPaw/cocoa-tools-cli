#!/usr/bin/env bash

set -Eeo pipefail

PLATFORM="$(uname -s | tr '[:upper:]' '[:lower:]')"

if [[ ${PLATFORM} == "darwin" ]]; then
  echo "Downloading Swiftly"
  curl -L "https://download.swift.org/swiftly/${PLATFORM}/swiftly.pkg" > swiftly.pkg

  echo "Installing Swiftly"
  installer -pkg swiftly.pkg -target CurrentUserHomeDirectory

  SWIFTLY_BIN="${HOME}/.swiftly/bin/swiftly"
  SWIFTLY_ENV_PATH="${HOME}/.swiftly/env.sh"
elif [[ ${PLATFORM} == "linux" ]]; then
  echo "Downloading Swiftly"
  curl -L "https://download.swift.org/swiftly/${PLATFORM}/swiftly-$(uname -m).tar.gz" > "swiftly-$(uname -m).tar.gz"

  echo "Extracting Swiftly"
  tar zxf "swiftly-$(uname -m).tar.gz"

  SWIFTLY_BIN="$(pwd)/swiftly"

  SWIFTLY_ENV_RELATIVE_PATH=".local/share/swiftly/env.sh"
  if [[ "$(id -un)" == 'root' ]]; then
    SWIFTLY_ENV_PATH="/root/${SWIFTLY_ENV_RELATIVE_PATH}"
  else
    SWIFTLY_ENV_PATH="${HOME}/${SWIFTLY_ENV_RELATIVE_PATH}"
  fi
else
  echo "Unsupported platform: ${PLATFORM}"
  exit 1
fi

if [[ ! -f ${SWIFTLY_BIN} ]]; then
  echo "Swiftly binary not found at ${SWIFTLY_BIN}"
  exit 1
fi

echo "Initializing Swiftly"
"${SWIFTLY_BIN}" init --assume-yes --skip-install --no-modify-profile --quiet-shell-followup

if [[ ! -f ${SWIFTLY_ENV_PATH} ]]; then
  echo "Swiftly environment file not found at ${SWIFTLY_ENV_PATH}"
  exit 1
fi

echo "Sourcing Swiftly environment"
# shellcheck source=/dev/null
. "${SWIFTLY_ENV_PATH}"

echo "Setting environment variables"
echo "SWIFTLY_HOME_DIR=${SWIFTLY_HOME_DIR}"
echo "SWIFTLY_BIN_DIR=${SWIFTLY_BIN_DIR}"
echo "SWIFTLY_TOOLCHAINS_DIR=${SWIFTLY_TOOLCHAINS_DIR}"

if [[ -n ${GITHUB_ENV} ]]; then
  {
    echo "SWIFTLY_HOME_DIR=${SWIFTLY_HOME_DIR}"
    echo "SWIFTLY_BIN_DIR=${SWIFTLY_BIN_DIR}"
    echo "SWIFTLY_TOOLCHAINS_DIR=${SWIFTLY_TOOLCHAINS_DIR}"
  } >> "${GITHUB_ENV}"
fi

if [[ -n ${GITHUB_PATH} ]]; then
  echo "Adding Swiftly bin directory to PATH"
  echo "${SWIFTLY_BIN_DIR}" >> "${GITHUB_PATH}"
fi
