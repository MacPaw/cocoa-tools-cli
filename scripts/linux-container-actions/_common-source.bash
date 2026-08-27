#!/usr/bin/env bash

# HTTP status code of a tag lookup on Docker Hub, e.g. `200` or `404`. Prints `000` if the request
# does not complete, because a failed lookup must not read as a missing tag.
docker_hub_tag_status() {
  local REPOSITORY="${1}" TAG="${2}" STATUS

  STATUS="$(
    curl \
      --silent \
      --location \
      --max-time 10 \
      --output /dev/null \
      --write-out '%{http_code}' \
      "https://hub.docker.com/v2/repositories/${REPOSITORY}/tags/${TAG}" \
      2> /dev/null
  )" || true

  echo "${STATUS:-000}"
}

# Sets `CONTAINER_IMAGE_NAME` and `CONTAINER_IMAGE_TAG` to the container image that carries a Swift
# version. Values that are set already are kept, which lets the caller pin an image.
#
# Released versions come from the official `swift` repository on Docker Hub. That repository carries
# no tag for a version that is not released yet, so those versions come from the nightly images of
# their development branch, which `swiftlang/swift` tags with a literal `x` in place of the patch
# version: `nightly-6.4.x-noble`. The patch version of the requested version is therefore dropped.
# A version that has no development branch yet, because it comes after the branch in development,
# comes from `nightly-noble`, the nightly image of the `main` branch.
#
# If the lookup of the official image fails, for example because the machine is offline, that image
# stays the answer. A nightly image is a deliberate downgrade, not a default.
resolve_swift_container_image() {
  local VERSION="${1:-"${SWIFT_VERSION:-}"}" MAJOR MINOR MAJOR_MINOR STATUS

  export CONTAINER_IMAGE_NAME CONTAINER_IMAGE_TAG

  if [ -n "${CONTAINER_IMAGE_NAME:-}" ] && [ -n "${CONTAINER_IMAGE_TAG:-}" ]; then
    echo "Container image is pinned to ${CONTAINER_IMAGE_NAME}:${CONTAINER_IMAGE_TAG}"
    return 0
  fi

  if [[ ! ${VERSION} =~ ^[0-9]+\.[0-9]+ ]]; then
    echo "Unsupported Swift version: '${VERSION}'. Give a version such as 6.4 or 6.4.0." >&2
    return 1
  fi

  # Keep the major and the minor version, drop the patch version. `BASH_REMATCH` is not used
  # because this file is also sourced by shells that do not fill it.
  MAJOR="${VERSION%%.*}"
  MINOR="${VERSION#*.}"
  MINOR="${MINOR%%.*}"
  MAJOR_MINOR="${MAJOR}.${MINOR}"

  STATUS="$(docker_hub_tag_status "library/swift" "${VERSION}")"

  if [[ ${STATUS} != "404" ]]; then
    if [[ ${STATUS} != "200" ]]; then
      echo "Cannot read the tags of the official Swift image (HTTP ${STATUS}). Using the official image for Swift ${VERSION}." >&2
    fi
    CONTAINER_IMAGE_NAME="swift"
    CONTAINER_IMAGE_TAG="${VERSION}"
    return 0
  fi

  echo "Docker Hub has no official image for Swift ${VERSION}. Looking for a nightly image..."

  CONTAINER_IMAGE_NAME="swiftlang/swift"
  CONTAINER_IMAGE_TAG="nightly-${MAJOR_MINOR}.x-noble"

  STATUS="$(docker_hub_tag_status "${CONTAINER_IMAGE_NAME}" "${CONTAINER_IMAGE_TAG}")"
  if [[ ${STATUS} != "200" ]]; then
    echo "  No ${MAJOR_MINOR} nightly image (HTTP ${STATUS}). Using the nightly image of the main branch."
    CONTAINER_IMAGE_TAG="nightly-noble"
  fi
}

# Running test on a package copy to avoid modifying files in the original package folder (.build, .swiftpm, etc.).
prepare_package_copy() {

  echo "Removing copy..."
  rm -rf /package-copy

  mkdir -p /package-copy/.build

  echo "Trusting Swift Package Macros and Plugins..."
  if [ -x ./scripts/tools/swift/swift.bash ]; then
    ./scripts/tools/swift/swift.bash --action=trust
  else
    echo "  swift.bash not found, skipping..."
  fi

  echo "Copying sources..."
  for SOURCE in Plugins Sources Tests Package*.swift Package.resolved .swift-version .config/semantic-version/version; do
    echo "  Copying ${SOURCE}..."
    if [ -d "${SOURCE}" ]; then
      cp -r "${SOURCE}" /package-copy
    elif [ -f "${SOURCE}" ]; then
      DIR="/package-copy/$(dirname "${SOURCE}")"
      if [ ! -d "${DIR}" ]; then
        echo "    Creating ${DIR}..."
        mkdir -p "${DIR}"
      fi
      echo "    Copying ${SOURCE} to ${DIR}..."
      cp "${SOURCE}" "${DIR}"
    else
      echo "    Skipping missing ${SOURCE}"
    fi
  done

  echo "Copying resolved packages..."
  for SOURCE in .build/checkouts .build/repositories .build/workspace-state.json .build/prebuilts .build/manifest.*; do
    echo "  Copying ${SOURCE}..."
    if [ -d "${SOURCE}" ]; then
      cp -r "${SOURCE}" /package-copy
    elif [ -f "${SOURCE}" ]; then
      DIR="/package-copy/$(dirname "${SOURCE}")"
      if [ ! -d "${DIR}" ]; then
        echo "    Creating ${DIR}..."
        mkdir -p "${DIR}"
      fi
      echo "    Copying ${SOURCE} to ${DIR}..."
      cp "${SOURCE}" "${DIR}"
    else
      echo "    Skipping missing ${SOURCE}"
    fi
  done

  echo "Copying necessary scripts..."
  mkdir -p /package-copy/scripts/tools
  cp -R ./scripts/tools/swift /package-copy/scripts/tools

  echo "Changing directory..."
  cd /package-copy || exit 1

  echo "Current directory:"
  pwd

  echo "Removing previous build..."
  rm -rf .build/*-linux-* || true

  # echo "Cleaning..."
  # /usr/bin/swift package clean

  # echo "Resolving packages..."
  # /usr/bin/swift package resolve

}

finish() {
  echo "Copying prebuilts back..."
  cp -r .build/prebuilts \
    \
    /package/.build \
    || true # Workaround for read-only mount when using the container binary.

  echo "Removing copy..."
  rm -rf /package-copy
}

CONTAINER_BINARY="${CONTAINER_BINARY:-"$(which container || printf '')"}"

container_start() {
  "${CONTAINER_BINARY}" system start --enable-kernel-install
}

container_stop() {
  "${CONTAINER_BINARY}" system stop
}

container_status() {
  "${CONTAINER_BINARY}" system status
}
