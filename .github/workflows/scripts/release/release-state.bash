#!/usr/bin/env bash

# Shared release lookup for the release scripts.
#
# Prints `missing`, `draft` or `published` for a version. Drafts are reported separately
# because a failed release attempt leaves one behind: it must never be mistaken for a
# shipped version, and it must never block a retry.
#
# A lookup that fails for any reason other than a missing release is an error rather than
# a `missing`, so a bad token cannot be read as "nothing has been released yet".
release_state() {
  local VERSION="${1}" OUTPUT EXIT_CODE

  set +e
  OUTPUT="$(gh release view "${VERSION}" --json isDraft 2>&1)"
  EXIT_CODE=$?
  set -e

  if [[ ${EXIT_CODE} -ne 0 ]]; then
    if grep -qi "release not found" <<< "${OUTPUT}"; then
      echo "missing"
      return 0
    fi

    # Reported plainly: whether a failed lookup is fatal is up to the caller.
    echo "Failed to look up release ${VERSION}: ${OUTPUT}" >&2
    return 1
  fi

  if [[ "$(jq -r '.isDraft' <<< "${OUTPUT}")" == "true" ]]; then
    echo "draft"
  else
    echo "published"
  fi
}
