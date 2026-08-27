#!/usr/bin/env bash

set -Eeo pipefail

# Fails unless the workflow run that triggered this one succeeded for the expected event.
#
# This has to fail rather than skip: a run whose jobs all skip is reported as successful,
# which would advertise a green Build to the Release workflow even though the upstream
# workflow was red.

: "${UPSTREAM_WORKFLOW:?UPSTREAM_WORKFLOW is required}"
: "${UPSTREAM_CONCLUSION:?UPSTREAM_CONCLUSION is required}"
: "${UPSTREAM_REQUIRED_EVENT:?UPSTREAM_REQUIRED_EVENT is required}"

UPSTREAM_EVENT="${UPSTREAM_EVENT:-""}"

die() {
  echo "::error::${*}"
  exit 1
}

if [[ ${UPSTREAM_CONCLUSION} != "success" ]]; then
  die "${UPSTREAM_WORKFLOW} concluded as ${UPSTREAM_CONCLUSION}; not building."
fi

if [[ ${UPSTREAM_EVENT} != "${UPSTREAM_REQUIRED_EVENT}" ]]; then
  die "${UPSTREAM_WORKFLOW} ran for ${UPSTREAM_EVENT:-"an unknown event"}, not ${UPSTREAM_REQUIRED_EVENT}; not building."
fi

echo "${UPSTREAM_WORKFLOW} succeeded for ${UPSTREAM_EVENT}"
