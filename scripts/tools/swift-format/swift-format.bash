#!/usr/bin/env bash

set -Eeo pipefail

SWIFT_FORMAT_COMMON_ARGS=(
  --configuration .config/swift-format/swift-format.json
  --parallel
  --color-diagnostics
)

die() {
  echo "${*}" >&2
  exit 2
}

resolve_files() {
  if [[ ${ALL_FILES} != true ]]; then
    return 0
  fi

  local file
  while IFS= read -r -d '' file; do
    FILES+=("${file}")
  done < <(git ls-files -z --cached --others --exclude-standard -- '*.swift')

  if ((${#FILES[@]} == 0)); then
    die "No Swift files found"
  fi
}

swift_format_format() {
  echo "Formatting Swift source code with swift-format..."
  resolve_files
  swift run swift-format format \
    "${SWIFT_FORMAT_COMMON_ARGS[@]}" \
    --in-place \
    "${FILES[@]}"
}

swift_format_lint() {
  echo "Linting Swift source code with swift-format..."
  resolve_files
  swift run swift-format lint \
    "${SWIFT_FORMAT_COMMON_ARGS[@]}" \
    --strict \
    "${FILES[@]}"
}

MODE=""
ALL_FILES=false
FILES=()

while [[ $# -gt 0 ]]; do
  case "${1}" in
    --format)
      MODE=format
      shift
      ;;
    --lint)
      MODE=lint
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
Supported options: --format, --lint"
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
  format)
    swift_format_format
    ;;
  lint)
    swift_format_lint
    ;;
  *)
    die "Missing mode.
Supported options: --format, --lint"
    ;;
esac
