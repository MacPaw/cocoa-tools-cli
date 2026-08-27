#!/usr/bin/env bash

set -Eeo pipefail

# Fails unless every job in the calling job's `needs` concluded successfully.
#
# The sentinel jobs this backs are required status checks, and a job skipped by its own `if:`
# reports as green to branch protection. Expressing the gate as `if: needs.<job>.result ==
# 'success'` would therefore skip the sentinel when a dependency goes red and let the pull
# request merge anyway. The sentinel runs on `!cancelled()` instead, and this script turns a
# non-success dependency into a real failure.
#
# Reading the whole `needs` context rather than named results keeps the sentinel in step with
# its own `needs:` list: adding a dependency there is enough to gate on it.

: "${NEEDS_JSON:?NEEDS_JSON is required}"

die() {
  echo "::error::${*}"
  exit 1
}

if ! jq -e 'type == "object"' <<< "${NEEDS_JSON}" > /dev/null; then
  die "NEEDS_JSON is not a JSON object: ${NEEDS_JSON}"
fi

# An empty object means the caller passed toJSON(needs) from a job without `needs:`, which
# would make this check pass no matter what the workflow did.
if jq -e 'length == 0' <<< "${NEEDS_JSON}" > /dev/null; then
  die "The calling job declares no needs, so this check would pass unconditionally"
fi

FAILED=0

while IFS=$'\t' read -r JOB RESULT; do
  if [[ ${RESULT} == "success" ]]; then
    echo "${JOB} succeeded"
    continue
  fi

  echo "::error::${JOB} concluded as ${RESULT}"
  FAILED=1
done < <(jq -r 'to_entries[] | "\(.key)\t\(.value.result // "unknown")"' <<< "${NEEDS_JSON}")

if [[ ${FAILED} -ne 0 ]]; then
  exit 1
fi

echo "Every needed job succeeded"
