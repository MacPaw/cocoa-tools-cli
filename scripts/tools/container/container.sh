#!/usr/bin/env bash

set -Eeo pipefail

REPOSITORY_ROOT_DIR="${REPOSITORY_ROOT_DIR:-"$(git rev-parse --show-toplevel 2> /dev/null || pwd)"}"

CONTAINER_BINARY="${CONTAINER_BINARY:-"$(which container)"}"

container_start() {
  "${CONTAINER_BINARY}" system start --enable-kernel-install
}

container_stop() {
  "${CONTAINER_BINARY}" system stop
}

container_status() {
  "${CONTAINER_BINARY}" system status
}

container_run_tests() {
  CONTAINER_WAS_RUNNING=false
  if container_status; then
    CONTAINER_WAS_RUNNING=true
  fi

  if [ "${CONTAINER_WAS_RUNNING}" != "true" ]; then
    container_start
  fi

  SWIFT_VERSION="${SWIFT_VERSION:-"$(tr -d '[:space:]' < .swift-version || echo '6.1.2')"}"
  echo "Using Swift version: ${SWIFT_VERSION}"

  if [ ! -d "${REPOSITORY_ROOT_DIR}/.build/prebuilts" ]; then
    mkdir -p "${REPOSITORY_ROOT_DIR}/.build/prebuilts"
  fi

  "${CONTAINER_BINARY}" run \
    --remove \
    --volume "${REPOSITORY_ROOT_DIR}/.build/prebuilts:/package/.build/prebuilts:rw" \
    --volume "${REPOSITORY_ROOT_DIR}:/package:ro" \
    --workdir /package \
    --entrypoint /bin/sh \
    "swift:${SWIFT_VERSION}" \
    ./scripts/container-tests/test.sh

  if [ "${CONTAINER_WAS_RUNNING}" != "true" ]; then
    container_stop
  fi
}

OPTIND=

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
    test)
      container_run_tests
      ;;
    *)
      echo "Unknown option: ${OPTSPEC}" >&2
      exit 1
      ;;
  esac
done
