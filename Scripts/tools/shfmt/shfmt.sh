#!/usr/bin/env bash

set -Eeo pipefail

shfmt_format() {
  echo "Formatting shell scripts with shfmt..."
  shfmt \
    --indent 2 \
    --language-dialect bash \
    --simplify \
    --case-indent \
    --binary-next-line \
    --space-redirects \
    --write \
    Scripts/**/*.sh \
    Scripts/**/**/*.sh \
    .github/workflows/scripts/**/*.sh
}

die() {
  echo "${*}" >&2
  exit 2
} # complain to STDERR and exit with error
needs_arg() { if [ -z "$OPTARG" ]; then die "No arg for --${OPTSPEC} option"; fi; }

while getopts "f:-:" OPTSPEC; do

  # support long options: https://stackoverflow.com/a/28466267/519360
  if [ "$OPTSPEC" = "-" ]; then   # long option: reformulate OPT and OPTARG
    OPTSPEC="${OPTARG%%=*}"       # extract long option name
    OPTARG="${OPTARG#"$OPTSPEC"}" # extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"          # if long option argument, remove assigning `=`
  fi

  case "${OPTSPEC}" in
    format)
      shfmt_format
      ;;
    *)
      echo "Unknown option: ${OPTSPEC}" >&2
      echo "Supported options: --format" >&2
      exit 1
      ;;
  esac
done
