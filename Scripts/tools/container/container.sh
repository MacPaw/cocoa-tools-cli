#!/bin/sh

set -Eeo pipefail

REPOSITORY_ROOT_DIR="${REPOSITORY_ROOT_DIR:-"$(git rev-parse --show-toplevel 2>/dev/null || pwd)"}"

container_start() {
  container system start --enable-kernel-install
}

container_stop() {
  container system stop
}

container_status() {
  container system status
}

container_run_tests() {
  CONTAINER_WAS_RUNNING=false
  if container_status; then
    CONTAINER_WAS_RUNNING=true
  fi

  if [ "${CONTAINER_WAS_RUNNING}" != "true" ]; then
    container_start
  fi

  SWIFT_VERSION="${SWIFT_VERSION:-"$(tr -d '[:space:]' <.swift-version || echo '6.1.2')"}"

  container run \
    --no-dns \
    --remove \
    --volume "${REPOSITORY_ROOT_DIR}:/package:ro" \
    --workdir /package \
    --entrypoint /bin/sh \
    "swift:${SWIFT_VERSION}" \
    Scripts/linux-tests/test.sh

  if [ "${CONTAINER_WAS_RUNNING}" != "true" ]; then
    container_stop
  fi
}

OPTIND=

die() {
  echo "${*}" >&2
  exit 2
} # complain to STDERR and exit with error
needs_arg() { if [ -z "$OPTARG" ]; then die "No arg for --${OPT} option"; fi; }

while getopts "t:s:-:" OPTSPEC; do

  # support long options: https://stackoverflow.com/a/28466267/519360
  if [ "$OPTSPEC" = "-" ]; then   # long option: reformulate OPT and OPTARG
    OPTSPEC="${OPTARG%%=*}"       # extract long option name
    OPTARG="${OPTARG#"$OPTSPEC"}" # extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"          # if long option argument, remove assigning `=`
  fi

  case "${OPTSPEC}" in
    start)
      container_start
      ;;
    stop)
      container_stop
      ;;
    t | test)
      container_run_tests
      ;;
    *)
      echo "Unknown option: ${OPTSPEC}" >&2
      exit 1
      ;;
  esac
done
