#!/usr/bin/env bash
# Create symlinks for AI agent configuration.
set -Eeo pipefail

REPOSITORY_ROOT_DIR="${REPOSITORY_ROOT_DIR:-"$(git rev-parse --show-toplevel 2> /dev/null || pwd)"}"

die() {
  echo "${*}" >&2
  exit 2
}

create_symlink() {
  local target="${1}"
  local link="${2}"

  if [[ ! -d "${REPOSITORY_ROOT_DIR}/${target}" ]]; then
    if [[ ! -f "${REPOSITORY_ROOT_DIR}/${target}" ]]; then
      return 0
    fi
  fi

  if [[ -L "${REPOSITORY_ROOT_DIR}/${link}" ]]; then
    local current_target
    current_target="$(readlink "${REPOSITORY_ROOT_DIR}/${link}")"
    if [[ ${current_target} == "${target}" ]]; then
      echo "Symlink already correct: ${link} -> ${target}"
      return
    else
      echo "Repointing symlink: ${link} -> ${target} (was ${current_target})"
      ln -snf "${target}" "${REPOSITORY_ROOT_DIR}/${link}"
    fi
  elif [[ -e "${REPOSITORY_ROOT_DIR}/${link}" ]]; then
    die "Path exists and is not a symlink: ${link}"
  else
    echo "Creating symlink: ${link} -> ${target}"
    ln -snf "${target}" "${REPOSITORY_ROOT_DIR}/${link}"
  fi
}

create_symlink ".config/agents" ".agents"
create_symlink ".config/claude" ".claude"
create_symlink "AGENTS.md" "CLAUDE.md"
