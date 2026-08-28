#!/usr/bin/env bash

set -Euo pipefail

# swiftly installs an unreleased version by snapshot selector, not by number, so a job that runs a
# nightly image passes one. Everything else links by version.
TOOLCHAIN="${SWIFT_TOOLCHAIN_SELECTOR:-${SWIFT_VERSION}}"

swiftly link --assume-yes --verbose
swiftly list
swiftly list "${TOOLCHAIN}" --format json

# `.swift-version` can hold `xcode`, which names a toolchain only a machine with Xcode has. On Linux
# `swiftly use` writes the toolchain in use into that file, so the rest of the job reads a real
# version. macOS keeps the `xcode` selector, where it is the correct answer.
if [[ "$(uname -s | tr '[:upper:]' '[:lower:]')" == "linux" ]]; then
  swiftly use --assume-yes "${TOOLCHAIN}"
fi
