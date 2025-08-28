#!/usr/bin/env bash

set -Eeo pipefail

shellcheck_lint() {
  echo "Linting shell scripts with shellcheck..."
  shellcheck \
    --shell=bash \
    --check-sourced \
    --extended-analysis=true \
    ./scripts/**/*.sh \
    ./scripts/**/**/*.sh \
    ./.github/workflows/scripts/**/*.sh
}

shellcheck_format() {
  echo "Formatting shell scripts with shellcheck..."
  (shellcheck \
    --shell=bash \
    --format=diff \
    --check-sourced \
    --extended-analysis=true \
    ./scripts/**/*.sh \
    ./scripts/**/**/*.sh \
    ./.github/workflows/scripts/**/*.sh \
    | git apply --allow-empty) || true
}

die() {
  echo "${*}" >&2
  exit 2
} # complain to STDERR and exit with error
needs_arg() { if [ -z "$OPTARG" ]; then die "No arg for --${OPTSPEC} option"; fi; }

while getopts "f:l:-:" OPTSPEC; do

  # support long options: https://stackoverflow.com/a/28466267/519360
  if [ "$OPTSPEC" = "-" ]; then   # long option: reformulate OPT and OPTARG
    OPTSPEC="${OPTARG%%=*}"       # extract long option name
    OPTARG="${OPTARG#"$OPTSPEC"}" # extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"          # if long option argument, remove assigning `=`
  fi

  case "${OPTSPEC}" in
    lint)
      shellcheck_lint
      ;;
    format)
      shellcheck_format
      ;;
    *)
      echo "Unknown option: ${OPTSPEC}" >&2
      echo "Supported options: --lint, --format" >&2
      exit 1
      ;;
  esac
done
