#!/usr/bin/env bash

set -Eeo pipefail

swift_run() {
  local DEFAULT_ARGS=(
    "--disable-automatic-resolution"
    "--enable-experimental-prebuilts"
    "--configuration" "${CONFIGURATION}"
  )

  SWIFT_BINARY="${SWIFT_BINARY:-"$(which swift || echo '/usr/bin/swift')"}"
  echo "${SWIFT_BINARY} ${ACTION} ${DEFAULT_ARGS[*]} ${*}"
  "$SWIFT_BINARY" "${ACTION}" "${DEFAULT_ARGS[@]}" "${@}"
}

die() {
  echo "${*}" >&2
  exit 2
} # complain to STDERR and exit with error
needs_arg() { if [ -z "$OPTARG" ]; then die "No arg for --${OPTSPEC} option"; fi; }

while getopts "a:c:-:" OPTSPEC; do

  # support long options: https://stackoverflow.com/a/28466267/519360
  if [ "$OPTSPEC" = "-" ]; then   # long option: reformulate OPT and OPTARG
    OPTSPEC="${OPTARG%%=*}"       # extract long option name
    OPTARG="${OPTARG#"$OPTSPEC"}" # extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"          # if long option argument, remove assigning `=`
  fi

  case "${OPTSPEC}" in
    a | action)
      needs_arg
      ACTION=$OPTARG
      ;;
    c | configuration)
      needs_arg
      CONFIGURATION=$OPTARG
      ;;
    *) ;;
  esac
done

ACTION="${ACTION:?"ENV var ACTION is unset or empty, or -a --action= argument is not passed"}"
CONFIGURATION="${CONFIGURATION:-"debug"}"

for ARG in "${@}"; do
  if [ "${IS_EXTRA_ARGS}" == "true" ]; then
    EXTRA_ARGS+=("${ARG}")
  fi

  if [[ ${ARG} == '--' ]]; then
    IS_EXTRA_ARGS=true
  fi
done

swift_run "${EXTRA_ARGS[@]}"
