#!/usr/bin/env bash

set -Euo pipefail

# Posts a commit status to the GitHub Commit Statuses API.
#
# Context is always the workflow name ($GITHUB_WORKFLOW), so each workflow
# reports under its own name and statuses from different workflows never collide.
# The target URL links to the current workflow run so "Details" goes to the right run.

: "${COMMIT_STATUS_SHA:?COMMIT_STATUS_SHA is required}"

# The Commit Statuses API only accepts pending/success/error/failure — there is no
# cancelled state — so cancelled jobs are reported as failure.
# https://docs.github.com/en/rest/commits/statuses
if [[ -z ${COMMIT_STATUS_STATE:-} ]]; then
  case "${JOB_STATUS:-}" in
    success) COMMIT_STATUS_STATE=success ;;
    *) COMMIT_STATUS_STATE=failure ;;
  esac
fi

ARGS=(
  "/repos/${GITHUB_REPOSITORY}/statuses/${COMMIT_STATUS_SHA}"
  -f "state=${COMMIT_STATUS_STATE}"
  -f "context=${GITHUB_WORKFLOW}"
  -f "target_url=${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"
)

[[ -n ${COMMIT_STATUS_DESCRIPTION:-} ]] && ARGS+=(-f "description=${COMMIT_STATUS_DESCRIPTION}")

gh api "${ARGS[@]}"
