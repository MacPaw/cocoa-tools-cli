#!/usr/bin/env bash

set -Eeo pipefail

SHELL_SCRIPT_DIRS=(
  ./scripts
  ./.github
)

MISE_TASKS_DIR="./.config/mise/tasks"

SHELLCHECK_COMMON_ARGS=()

die() {
  echo "${*}" >&2
  exit 2
}

ensure_shellcheck_env() {
  # SHELLCHECK_RCFILE is set via mise env (.config/mise/env/shellcheck.toml).
  : "${SHELLCHECK_RCFILE:?SHELLCHECK_RCFILE is not set (activate mise or run via mise task)}"
  SHELLCHECK_COMMON_ARGS=(
    --rcfile="${SHELLCHECK_RCFILE}"
    # Not supported in .shellcheckrc; keep as a CLI flag.
    --check-sourced
  )
}

collect_all_shell_files() {
  local dir file
  local -a files=()

  for dir in "${SHELL_SCRIPT_DIRS[@]}"; do
    while IFS= read -r -d '' file; do
      files+=("${file}")
    done < <(
      find "${dir}" -type f \( \
        -name '*.sh' -o -name '*.bash' \
        \) -print0
    )
  done

  while IFS= read -r -d '' file; do
    files+=("${file}")
  done < <(find "${MISE_TASKS_DIR}" -type f ! -name '*.*' -print0)

  printf '%s\0' "${files[@]}"
}

resolve_files() {
  if [[ ${ALL_FILES} != true ]]; then
    return 0
  fi

  local -a discovered=()
  local file
  while IFS= read -r -d '' file; do
    discovered+=("${file}")
  done < <(collect_all_shell_files)
  FILES=("${discovered[@]}")
}

run_shellcheck() {
  local -a extra_args=("${@}")

  ensure_shellcheck_env

  if ((${#FILES[@]} == 0)); then
    return 0
  fi

  printf '%s\0' "${FILES[@]}" \
    | xargs -0 shellcheck "${SHELLCHECK_COMMON_ARGS[@]}" "${extra_args[@]}"
}

shellcheck_lint() {
  echo "Linting shell scripts with shellcheck..."
  resolve_files
  run_shellcheck
}

shellcheck_format() {
  echo "Formatting shell scripts with shellcheck..."
  resolve_files
  if ((${#FILES[@]} == 0)); then
    return 0
  fi

  if ! run_shellcheck --format=diff | git apply --allow-empty; then
    echo "Shellcheck formatting failed. Running in lint mode..."
    run_shellcheck
  fi
}

MODE=""
ALL_FILES=false
FILES=()

while [[ $# -gt 0 ]]; do
  case "${1}" in
    --lint)
      MODE=lint
      shift
      ;;
    --format)
      MODE=format
      shift
      ;;
    --all)
      ALL_FILES=true
      shift
      ;;
    --)
      shift
      FILES+=("${@}")
      break
      ;;
    -*)
      die "Unknown option: ${1}
Supported options: --lint, --format"
      ;;
    *)
      FILES+=("${1}")
      shift
      ;;
  esac
done

if [[ ${ALL_FILES} == true && ${#FILES[@]} -gt 0 ]]; then
  die "Pass either --all or explicit files, not both"
fi

if [[ ${ALL_FILES} != true && ${#FILES[@]} -eq 0 ]]; then
  die "Pass --all or at least one file"
fi

case "${MODE}" in
  lint)
    shellcheck_lint
    ;;
  format)
    shellcheck_format
    ;;
  *)
    die "Missing mode.
Supported options: --lint, --format"
    ;;
esac
