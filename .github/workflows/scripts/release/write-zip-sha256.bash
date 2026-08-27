#!/usr/bin/env bash

set -Eeo pipefail

# Writes a `<archive>.zip.sha256` sidecar next to every archive built by build-binary.bash,
# so the Release workflow can verify the artifacts it downloads from this build.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.github/workflows/scripts/release/sha256.bash
source "${SCRIPT_DIR}/sha256.bash"

ARCHIVES_DIR="${ARCHIVES_DIR:-"${PWD}"}"

ARCHIVES=()
while IFS= read -r ARCHIVE; do
  ARCHIVES+=("${ARCHIVE}")
done < <(find "${ARCHIVES_DIR}" -maxdepth 1 -type f -name '*.zip' | sort)

if [[ ${#ARCHIVES[@]} -eq 0 ]]; then
  echo "::error::No archives found in ${ARCHIVES_DIR}"
  exit 1
fi

for ARCHIVE in "${ARCHIVES[@]}"; do
  sha256_write_sidecar "${ARCHIVE}"
  echo "Wrote $(cat "$(sha256_sidecar_path "${ARCHIVE}")")"
done
