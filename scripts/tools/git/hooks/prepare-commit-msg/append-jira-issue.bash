#!/usr/bin/env bash
# Appends JIRA issue IDs from the current branch name to the commit message footer.
# Invoked by hk prepare-commit-msg (migrated from pre-commit commit-msg-add-jira-issue).

set -Eeo pipefail

COMMIT_MESSAGE_SOURCE="${2:-}"

case "${COMMIT_MESSAGE_SOURCE}" in
  merge | squash)
    # merge  – commit is a merge or .git/MERGE_MSG exists
    # squash – .git/SQUASH_MSG exists
    echo "[✅ PREPARE COMMIT MESSAGE] Merging or squashing - skipping JIRA issue appending."
    exit 0
    ;;
  *)
    echo "[ℹ️ PREPARE COMMIT MESSAGE] Message source: ${COMMIT_MESSAGE_SOURCE:-<unset>}."
    # message  – -m or -F was given
    # template – -t or commit.template is set
    # commit   – -c, -C, or --amend
    ;;
esac

REPOSITORY_ROOT_DIR="${REPOSITORY_ROOT_DIR:-"$(git rev-parse --show-toplevel 2> /dev/null || pwd)"}"

COMMIT_MESSAGE_FILE="${1:-"${REPOSITORY_ROOT_DIR}/.git/COMMIT_EDITMSG"}"
if [[ ! -f ${COMMIT_MESSAGE_FILE} ]]; then
  echo "[❌ PREPARE COMMIT MESSAGE] Can't find commit message file '${COMMIT_MESSAGE_FILE}'." >&2
  exit 1
fi
COMMIT_MESSAGE=$(sed '$ s/\n$//' < "${COMMIT_MESSAGE_FILE}")

# Get JIRA issue IDs from the branch name.
ISSUE_NUMBERS="$(
  (
    git rev-parse --abbrev-ref HEAD 2> /dev/null \
      | grep -oE "[A-Za-z0-9]+-[0-9]+" \
      | awk '{ printf "%s%s",sep,$0; sep=", " } END { print "" }' \
      | tr '[:lower:]' '[:upper:]'
  ) || printf ''
)"

if [[ -n ${ISSUE_NUMBERS} && ${COMMIT_MESSAGE} != *"${ISSUE_NUMBERS}"* ]]; then
  # Let signed-off commits keep a single blank line before the trailer.
  LINES="$(echo "${COMMIT_MESSAGE}" | wc -l | tr -d ' ')"
  NEW_LINE=$'\n'
  if [[ ${LINES} -lt 3 ]]; then
    NEW_LINE="${NEW_LINE}"$'\n'
  fi

  echo "[✅ PREPARE COMMIT MESSAGE] Appending ${ISSUE_NUMBERS} JIRA issues to the message footer."
  echo "${COMMIT_MESSAGE}${NEW_LINE}JIRA-issues: ${ISSUE_NUMBERS}" > "${COMMIT_MESSAGE_FILE}"
else
  echo "[🫥 PREPARE COMMIT MESSAGE] Nothing to append."
fi
