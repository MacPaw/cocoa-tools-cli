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

container_run() {
  local SCRIPT_TO_RUN SWIFT_VERSION CONTAINER_WAS_RUNNING
  SCRIPT_TO_RUN="${1}"

  SWIFT_VERSION="${SWIFT_VERSION:-"$(tr -d '[:space:]' < .swift-version || echo '6.1.2')"}"
  echo "Using Swift version: ${SWIFT_VERSION}"

  if [ ! -d "${REPOSITORY_ROOT_DIR}/.build/prebuilts" ]; then
    mkdir -p "${REPOSITORY_ROOT_DIR}/.build/prebuilts"
  fi

  CONTAINER_WAS_RUNNING=false
  if container_status; then
    CONTAINER_WAS_RUNNING=true
  fi

  if [ "${CONTAINER_WAS_RUNNING}" != "true" ]; then
    container_start
  fi

  SWIFT_SDK="${SWIFT_SDK:-"x86_64-swift-linux-musl"}"

  "${CONTAINER_BINARY}" run \
    --rm \
    --volume "${HOME}/.swiftpm/swift-sdks:/root/.swiftpm/swift-sdks:rw" \
    --volume "${REPOSITORY_ROOT_DIR}/.build/prebuilts:/package/.build/prebuilts:rw" \
    --volume "${REPOSITORY_ROOT_DIR}/.build/${SWIFT_SDK}/release:/package/.build/${SWIFT_SDK}/release:rw" \
    --volume "${REPOSITORY_ROOT_DIR}:/package:ro" \
    --workdir /package \
    --env "SWIFT_SDK=${SWIFT_SDK}" \
    --env "SWIFT_VERSION=${SWIFT_VERSION}" \
    --entrypoint /bin/sh \
    "swift:${SWIFT_VERSION}" \
    "${SCRIPT_TO_RUN}"

  if [ "${CONTAINER_WAS_RUNNING}" != "true" ]; then
    container_stop
  fi

}

container_run_tests() {
  container_run "./scripts/linux-container-actions/test.sh"
}

container_run_build() {
  container_run "./scripts/linux-container-actions/build.sh"
}

OPTIND=

die() {
  echo "${*}" >&2
  exit 2
} # complain to STDERR and exit with error
needs_arg() { if [ -z "$OPTARG" ]; then die "No arg for --${OPTSPEC} option"; fi; }

while getopts "t:b:-:" OPTSPEC; do

  # support long options: https://stackoverflow.com/a/28466267/519360
  if [ "$OPTSPEC" = "-" ]; then   # long option: reformulate OPT and OPTARG
    OPTSPEC="${OPTARG%%=*}"       # extract long option name
    OPTARG="${OPTARG#"$OPTSPEC"}" # extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"          # if long option argument, remove assigning `=`
  fi

  case "${OPTSPEC}" in
    t | test)
      container_run_tests
      ;;
    b | build)
      container_run_build
      ;;
    *)
      echo "Unknown option: ${OPTSPEC}" >&2
      exit 1
      ;;
  esac
done
