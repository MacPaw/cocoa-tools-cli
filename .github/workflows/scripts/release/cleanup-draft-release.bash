#!/usr/bin/env bash

set -Euo pipefail

# Removes the draft release left behind by a failed or cancelled release attempt, so the
# next attempt starts clean.
#
# Deliberately never fails: it runs while the job is already failing, and create-release.bash
# deletes any surviving draft anyway.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.github/workflows/scripts/release/release-state.bash
source "${SCRIPT_DIR}/release-state.bash"

VERSION="${VERSION:-""}"

if [[ -z ${VERSION} ]]; then
  echo "No version to clean up"
  exit 0
fi

if ! RELEASE_STATE="$(release_state "${VERSION}")"; then
  echo "::warning::Could not determine the release state of ${VERSION}; leaving it as is"
  exit 0
fi

if [[ ${RELEASE_STATE} != "draft" ]]; then
  echo "No draft release to clean up for ${VERSION} (state: ${RELEASE_STATE})"
  exit 0
fi

echo "Deleting the draft release for ${VERSION}"
if ! gh release delete "${VERSION}" --yes; then
  echo "::warning::Failed to delete the draft release for ${VERSION}; delete it by hand if the next run does not"
fi

exit 0
