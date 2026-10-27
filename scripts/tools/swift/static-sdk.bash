#!/usr/bin/env bash

set -Eeo pipefail

STATIC_LINUX_SDK_VERSION="${STATIC_LINUX_SDK_VERSION:-"0.1.0"}"

# Release version of the toolchain, spelled the way download.swift.org names its release, which is
# the version in `.swift-version` (`6.4.0`, not `6.4`).
swift_pinned_version() {
  local SWIFT_VERSION
  SWIFT_VERSION="$(tr -d '[:space:]' < .swift-version)"
  if [[ ${SWIFT_VERSION} == "xcode" ]]; then
    SWIFT_VERSION="$(swift -version 2> /dev/null | grep 'Apple Swift version' | awk '{print $4}' | tr -d '[:space:]')"
  fi
  # `swift -version` omits the patch component of a `.0` release.
  if [[ ${SWIFT_VERSION} =~ ^[0-9]+\.[0-9]+$ ]]; then
    SWIFT_VERSION="${SWIFT_VERSION}.0"
  fi
  echo "${SWIFT_VERSION}"
}

swift_static_sdk_bundle_id() {
  echo "swift-$(swift_pinned_version)-RELEASE_static-linux-${STATIC_LINUX_SDK_VERSION}"
}

# Architecture name Linux toolchains use, accepting both the Darwin (`arm64`) and Linux
# (`aarch64`) spelling of the same architecture.
swift_linux_arch() {
  local ARCH="${1}"

  case "${ARCH}" in
    arm64 | aarch64)
      echo "aarch64"
      ;;
    x86_64 | amd64)
      echo "x86_64"
      ;;
    *)
      echo "Unsupported Linux architecture: ${ARCH}" >&2
      return 1
      ;;
  esac
}

# Target triple of a Linux target, e.g. `aarch64-swift-linux-musl`.
swift_linux_triple() {
  local LIBC_IMPLEMENTATION="${1}" ARCH="${2}" NORMALIZED_ARCH
  NORMALIZED_ARCH="$(swift_linux_arch "${ARCH}")" || return 1

  case "${LIBC_IMPLEMENTATION}" in
    musl)
      echo "${NORMALIZED_ARCH}-swift-linux-musl"
      ;;
    gnu)
      echo "${NORMALIZED_ARCH}-unknown-linux-gnu"
      ;;
    *)
      echo "Unsupported libc implementation: ${LIBC_IMPLEMENTATION}. Supported values: musl, gnu" >&2
      return 1
      ;;
  esac
}

# Directory, relative to `.build`, that release binaries of a Linux target are staged in. The
# container tooling mounts it read-write into the otherwise read-only package mount, so it is
# kept per triple: `.build/release` is a symlink SwiftPM owns for host builds.
swift_release_directory() {
  local LIBC_IMPLEMENTATION="${1}" ARCH="${2}" TRIPLE
  TRIPLE="$(swift_linux_triple "${LIBC_IMPLEMENTATION}" "${ARCH}")" || return 1

  echo "${TRIPLE}/release"
}
