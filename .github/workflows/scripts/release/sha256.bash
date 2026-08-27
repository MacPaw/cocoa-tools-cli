#!/usr/bin/env bash

# Shared SHA-256 helpers for the release scripts.
#
# Archives are built on macOS and Linux but always verified on Linux, so the sidecars are
# written with the plain `<hash>  <name>` format both `sha256sum` and `shasum` understand,
# and store only the file name so verification works from the containing directory.

sha256_sidecar_path() {
  echo "${1}.sha256"
}

sha256_write_sidecar() {
  local ARCHIVE_PATH="${1}" ARCHIVE_DIR ARCHIVE_NAME
  ARCHIVE_DIR="$(dirname "${ARCHIVE_PATH}")"
  ARCHIVE_NAME="$(basename "${ARCHIVE_PATH}")"

  if command -v sha256sum > /dev/null 2>&1; then
    (cd "${ARCHIVE_DIR}" && sha256sum "${ARCHIVE_NAME}" > "${ARCHIVE_NAME}.sha256")
  else
    (cd "${ARCHIVE_DIR}" && shasum -a 256 "${ARCHIVE_NAME}" > "${ARCHIVE_NAME}.sha256")
  fi
}

sha256_verify_sidecar() {
  local ARCHIVE_PATH="${1}" ARCHIVE_DIR ARCHIVE_NAME
  ARCHIVE_DIR="$(dirname "${ARCHIVE_PATH}")"
  ARCHIVE_NAME="$(basename "${ARCHIVE_PATH}")"

  if command -v sha256sum > /dev/null 2>&1; then
    (cd "${ARCHIVE_DIR}" && sha256sum --check --strict "${ARCHIVE_NAME}.sha256")
  else
    (cd "${ARCHIVE_DIR}" && shasum -a 256 --check --strict "${ARCHIVE_NAME}.sha256")
  fi
}
