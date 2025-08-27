#!/bin/sh

set -Eeo pipefail

swift_format_format() {
  echo "Formatting source code..."
  swift package plugin --allow-writing-to-package-directory format-source-code
}

swift_format_lint() {
  echo "Linting source code..."
  swift package plugin --allow-writing-to-package-directory lint-source-code
}

die() {
  echo "${*}" >&2
  exit 2
} # complain to STDERR and exit with error
needs_arg() { if [ -z "$OPTARG" ]; then die "No arg for --${OPT} option"; fi; }

while getopts "f:l:-:" OPTSPEC; do

  # support long options: https://stackoverflow.com/a/28466267/519360
  if [ "$OPTSPEC" = "-" ]; then   # long option: reformulate OPT and OPTARG
    OPTSPEC="${OPTARG%%=*}"       # extract long option name
    OPTARG="${OPTARG#"$OPTSPEC"}" # extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"          # if long option argument, remove assigning `=`
  fi

  case "${OPTSPEC}" in
    f | format)
      swift_format_format
      ;;
    l | lint)
      swift_format_lint
      ;;
    *)
      echo "Unknown option: ${OPTSPEC}" >&2
      echo "Supported options: --format, -f, --lint, -l" >&2
      exit 1
      ;;
  esac
done
