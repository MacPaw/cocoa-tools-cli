#!/usr/bin/env bash

set -Eeo pipefail

swift_format_format() {
  echo "Formatting Swift source code with swift-format..."
  # Calling swift ... swift-format doesn't format Package.swift 🤷.
  # Copy Package.swift to Sources so it is formatted too.
  cp Package*.swift Sources/Dummy

  # Format .swift files.
  swift package plugin --allow-writing-to-package-directory --package swift-format format-source-code

  # Move formatted Package.swift back to the root folder.
  mv Sources/Dummy/Package*.swift .
}

swift_format_lint() {
  echo "Linting Swift source code with swift-format..."
  swift package plugin --allow-writing-to-package-directory --package swift-format lint-source-code
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
    format)
      swift_format_format
      ;;
    lint)
      swift_format_lint
      ;;
    *)
      echo "Unknown option: ${OPTSPEC}" >&2
      echo "Supported options: --format, --lint" >&2
      exit 1
      ;;
  esac
done
