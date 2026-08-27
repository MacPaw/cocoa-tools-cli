#!/usr/bin/env bash

set -Eeo pipefail

REPOSITORY_ROOT_DIR="${REPOSITORY_ROOT_DIR:-"$(git rev-parse --show-toplevel 2> /dev/null || pwd)"}"
source "${REPOSITORY_ROOT_DIR}/scripts/linux-container-actions/_common-source.bash"
source "${REPOSITORY_ROOT_DIR}/scripts/tools/swift/static-sdk.bash"

docker_run() {

  local SCRIPT_TO_RUN SWIFT_RELEASE_DIRECTORY

  SCRIPT_TO_RUN="${1}"

  SWIFT_VERSION="${SWIFT_VERSION:-"$(tr -d '[:space:]' < .swift-version || echo '6.1.2')"}"
  echo "Using Swift version: ${SWIFT_VERSION}"

  resolve_swift_container_image "${SWIFT_VERSION}"
  echo "Using container image: ${CONTAINER_IMAGE_NAME}:${CONTAINER_IMAGE_TAG}"

  if [ ! -d "${REPOSITORY_ROOT_DIR}/.build/prebuilts" ]; then
    mkdir -p "${REPOSITORY_ROOT_DIR}/.build/prebuilts"
  fi

  # The Build workflow cross-compiles musl on macOS, so the container builds the gnu binary the
  # container image itself provides.
  SWIFT_LIBC_IMPLEMENTATION="${SWIFT_LIBC_IMPLEMENTATION:-"gnu"}"
  ARCH="$(swift_linux_arch "${ARCH:-"$(uname -m)"}")"
  SWIFT_RELEASE_DIRECTORY="$(swift_release_directory "${SWIFT_LIBC_IMPLEMENTATION}" "${ARCH}")"

  # Keep host mount paths present for tools that require them (e.g. Apple's `container`).
  mkdir -p "${REPOSITORY_ROOT_DIR}/.build/${SWIFT_RELEASE_DIRECTORY}"

  # Trun off exit on error to catch errors from the container
  set +Ee

  docker run \
    --rm \
    --cpus "${CONTAINER_BUILD_CPUS}" \
    --memory "${CONTAINER_BUILD_MEMORY}" \
    --volume "${HOME}/.swiftpm/swift-sdks:/root/.swiftpm/swift-sdks:rw" \
    --volume "${REPOSITORY_ROOT_DIR}/.build/prebuilts:/package/.build/prebuilts:rw" \
    --volume "${REPOSITORY_ROOT_DIR}/.build/${SWIFT_RELEASE_DIRECTORY}:/package/.build/${SWIFT_RELEASE_DIRECTORY}:rw" \
    --volume "${REPOSITORY_ROOT_DIR}:/package:ro" \
    --workdir /package \
    --env "SWIFT_LIBC_IMPLEMENTATION=${SWIFT_LIBC_IMPLEMENTATION}" \
    --env "ARCH=${ARCH}" \
    --env "SWIFT_RELEASE_DIRECTORY=${SWIFT_RELEASE_DIRECTORY}" \
    --env "SWIFT_VERSION=${SWIFT_VERSION}" \
    --env "SWIFT_PACKAGE_NAME=${SWIFT_PACKAGE_NAME}" \
    --env "SWIFT_PACKAGE_BINARY_NAME=${SWIFT_PACKAGE_BINARY_NAME}" \
    --entrypoint /bin/sh \
    "${CONTAINER_IMAGE_NAME}:${CONTAINER_IMAGE_TAG}" \
    "${SCRIPT_TO_RUN}"

  CONTAINER_EXIT_CODE=$?

  # Turn on exit on error
  set -Ee

  if [ "${CONTAINER_EXIT_CODE}" != "0" ]; then
    echo "Container exit code: ${CONTAINER_EXIT_CODE}" >&2
    echo "If you see error above: 'error: compile command failed due to signal 9 (use -v to see invocation)', it's because the container ran out of memory. Please increase the memory limit in the .config/mise/env/container.toml file." >&2
    exit "${CONTAINER_EXIT_CODE}"
  fi
}

docker_run_build() {
  docker_run "./scripts/linux-container-actions/build.bash"
}

docker_run_tests() {
  docker_run "./scripts/linux-container-actions/test.bash"
}

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
      docker_run_tests
      ;;
    b | build)
      docker_run_build
      ;;
    *)
      echo "Unknown option: ${OPTSPEC}" >&2
      echo "Supported options: --test" >&2
      exit 1
      ;;
  esac
done
