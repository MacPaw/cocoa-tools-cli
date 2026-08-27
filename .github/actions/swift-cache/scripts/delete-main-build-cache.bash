#!/usr/bin/env bash

set -Euo pipefail

: "${GITHUB_TOKEN:?GITHUB_TOKEN is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
: "${CACHE_KEY:?CACHE_KEY is required}"
: "${GITHUB_STEP_SUMMARY:=/dev/null}"

REF="refs/heads/main"

# GitHub Actions cache keys are immutable, so main must delete its existing build cache
# before a fresh one can be saved under the same key. This call is intentionally
# non-fatal: any failure here just means the old cache is reused for this run instead
# of breaking CI.
set +e
RESPONSE="$(
  curl --silent --show-error --location --request DELETE \
    --header "Accept: application/vnd.github+json" \
    --header "Authorization: Bearer ${GITHUB_TOKEN}" \
    --header "X-GitHub-Api-Version: 2022-11-28" \
    --write-out $'\n%{http_code}' \
    "https://api.github.com/repos/${GITHUB_REPOSITORY}/actions/caches?key=$(printf '%s' "${CACHE_KEY}" | jq -sRr @uri)&ref=$(printf '%s' "${REF}" | jq -sRr @uri)"
)"
CURL_EXIT_CODE=$?
set -e

HTTP_CODE="$(tail -n1 <<< "${RESPONSE}")"
BODY="$(sed '$d' <<< "${RESPONSE}")"

if [[ ${CURL_EXIT_CODE} -ne 0 ]]; then
  echo "::warning::Failed to delete build cache for key '${CACHE_KEY}': curl exited with code ${CURL_EXIT_CODE}"
  echo "⚠️ Failed to delete existing main build cache for key \`${CACHE_KEY}\` (curl exit code ${CURL_EXIT_CODE}). Reusing the existing cache for this run." >> "${GITHUB_STEP_SUMMARY}"
  exit 0
fi

case "${HTTP_CODE}" in
  200)
    echo "Deleted existing build cache for key '${CACHE_KEY}'"
    ;;
  404)
    echo "No existing build cache found for key '${CACHE_KEY}'; nothing to delete"
    ;;
  *)
    echo "::warning::Failed to delete build cache for key '${CACHE_KEY}' (HTTP ${HTTP_CODE}): ${BODY}"
    echo "⚠️ Failed to delete existing main build cache for key \`${CACHE_KEY}\` (HTTP ${HTTP_CODE}). Reusing the existing cache for this run." >> "${GITHUB_STEP_SUMMARY}"
    ;;
esac

exit 0
