#!/usr/bin/env bash

set -Eeo pipefail

YAML_DIRS=(
  ./.config
  ./.github
)

YAMLFMT_CONF=".config/yamlfmt/yamlfmt.yaml"

YAMLFMT_COMMON_ARGS=(
  -conf "${YAMLFMT_CONF}"
)

die() {
  echo "${*}" >&2
  exit 2
}

collect_all_yaml_files() {
  local dir file
  local -a files=()

  for dir in "${YAML_DIRS[@]}"; do
    while IFS= read -r -d '' file; do
      files+=("${file}")
    done < <(
      find "${dir}" -type f \( \
        -name '*.yml' -o -name '*.yaml' \
        \) -print0
    )
  done

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
  done < <(collect_all_yaml_files)
  FILES=("${discovered[@]}")
}

yamlfmt_lint() {
  echo "Linting YAML files with yamlfmt..."
  resolve_files

  if ((${#FILES[@]} == 0)); then
    return 0
  fi

  yamlfmt "${YAMLFMT_COMMON_ARGS[@]}" -lint "${FILES[@]}"
}

yamlfmt_format() {
  echo "Formatting YAML files with yamlfmt..."
  resolve_files

  if ((${#FILES[@]} == 0)); then
    return 0
  fi

  yamlfmt "${YAMLFMT_COMMON_ARGS[@]}" "${FILES[@]}"
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
    yamlfmt_lint
    ;;
  format)
    yamlfmt_format
    ;;
  *)
    die "Missing mode.
Supported options: --lint, --format"
    ;;
esac
