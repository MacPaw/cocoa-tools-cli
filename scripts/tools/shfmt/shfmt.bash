#!/usr/bin/env bash

set -Eeo pipefail

SHELL_SCRIPT_DIRS=(
  ./scripts
  ./.github
)

MISE_TASKS_DIR="./.config/mise/tasks"

# Formatting options come from .editorconfig (any parser/printer CLI flag disables it).
SHFMT_COMMON_ARGS=(
  --apply-ignore
)

die() {
  echo "${*}" >&2
  exit 2
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

run_shfmt() {
  local -a extra_args=("${@}")

  if ((${#FILES[@]} == 0)); then
    return 0
  fi

  printf '%s\0' "${FILES[@]}" \
    | xargs -0 shfmt "${SHFMT_COMMON_ARGS[@]}" "${extra_args[@]}"
}

shfmt_lint() {
  echo "Checking shell scripts with shfmt..."
  resolve_files
  run_shfmt --diff
}

shfmt_format() {
  echo "Formatting shell scripts with shfmt..."
  resolve_files
  run_shfmt --write
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
    shfmt_lint
    ;;
  format)
    shfmt_format
    ;;
  *)
    die "Missing mode.
Supported options: --lint, --format"
    ;;
esac
