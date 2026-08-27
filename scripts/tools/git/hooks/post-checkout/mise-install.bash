#!/usr/bin/env bash
# Installs mise tools when tool/version config changes across a checkout.
# Invoked by hk post-checkout (migrated from pre-commit mise-install).
#
# Matches when any of these change between prev and new HEAD:
#   .config/mise/mise.toml, .config/mise/mise.lock,
#   mise.toml, .mise.toml, mise.lock, .mise.lock,
#   .ruby-version, .swift-version
# (toml is included because the lock file alone may not bump min_version;
#  idiomatic version files are not listed in the lock file.)

set -Eeo pipefail

PREV_HEAD="${1:-}"
NEW_HEAD="${2:-}"

REPOSITORY_ROOT_DIR="${REPOSITORY_ROOT_DIR:-"$(git rev-parse --show-toplevel 2> /dev/null || pwd)"}"
MISE_BASH="${REPOSITORY_ROOT_DIR}/scripts/tools/mise/mise.bash"

# Same commit (e.g. file checkout) — nothing to install.
if [[ -z ${PREV_HEAD} || -z ${NEW_HEAD} || ${PREV_HEAD} == "${NEW_HEAD}" ]]; then
  exit 0
fi

# Initial clone / orphan checkout (prev is the zero SHA) — always install.
if [[ ${PREV_HEAD} =~ ^0+$ ]]; then
  echo "[ 🧰   mise ] Initial checkout — installing tools"
  "${MISE_BASH}" --install
  exit 0
fi

CHANGED_FILES="$(git diff --name-only "${PREV_HEAD}" "${NEW_HEAD}" || true)"
if echo "${CHANGED_FILES}" | grep -qE '(^|/)\.config/mise/mise\.(toml|lock)$|(^|/)\.?mise\.(toml|lock)$|(^|/)\.(ruby|swift)-version$'; then
  echo "[ 🧰   mise ] Tool config changed — installing tools"
  "${MISE_BASH}" --install
else
  echo "[ 🧰   mise ] No mise/version file changes — skipping install"
fi
