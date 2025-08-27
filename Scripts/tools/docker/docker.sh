#!/bin/sh

set -Eeo pipefail

REPOSITORY_ROOT_DIR="${REPOSITORY_ROOT_DIR:-"$(git rev-parse --show-toplevel 2>/dev/null || pwd)"}"

docker_run_tests() {

  SWIFT_VERSION="${SWIFT_VERSION:-"$(tr -d '[:space:]' <.swift-version || echo '6.1.2')"}"

  docker run \
    --rm \
    --cap-add sys_ptrace \
    --volume "${REPOSITORY_ROOT_DIR}:/package:ro" \
    --workdir /package \
    --entrypoint /bin/sh \
    "swift:${SWIFT_VERSION}" \
    Scripts/linux-tests/test.sh
}

die() {
  echo "${*}" >&2
  exit 2
} # complain to STDERR and exit with error
needs_arg() { if [ -z "$OPTARG" ]; then die "No arg for --${OPTSPEC} option"; fi; }

while getopts "t:-:" OPTSPEC; do

  # support long options: https://stackoverflow.com/a/28466267/519360
  if [ "$OPTSPEC" = "-" ]; then   # long option: reformulate OPT and OPTARG
    OPTSPEC="${OPTARG%%=*}"       # extract long option name
    OPTARG="${OPTARG#"$OPTSPEC"}" # extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"          # if long option argument, remove assigning `=`
  fi

  case "${OPTSPEC}" in
    t | test)
      docker_run_tests
      ;;
    *)
      echo "Unknown option: ${OPTSPEC}" >&2
      echo "Supported options: --test, -t" >&2
      exit 1
      ;;
  esac
done
