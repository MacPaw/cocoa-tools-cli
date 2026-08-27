#!/usr/bin/env bash

# Container image resolution for the `load-env` workflow.
#
# This is a copy of the same two functions in `scripts/linux-container-actions/_common-source.bash`,
# which the mise tasks source. The copy exists because the `load-env` job checks out only the paths
# its step reads, and `scripts/` is not one of them. Keep the two in step.

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

# Toolchain selector swiftly understands for a resolved image. A released version installs by
# number. A nightly image has no release toolchain, so the matching development snapshot installs
# instead: `6.4-snapshot` for a development branch, `main-snapshot` for the `main` branch.
swift_toolchain_selector() {
  local VERSION="${1}" IMAGE_NAME="${2}" IMAGE_TAG="${3}" MAJOR MINOR

  if [[ ${IMAGE_NAME} != "swiftlang/swift" ]]; then
    echo "${VERSION}"
    return 0
  fi

  if [[ ${IMAGE_TAG} == "nightly-noble" ]]; then
    echo "main-snapshot"
    return 0
  fi

  MAJOR="${VERSION%%.*}"
  MINOR="${VERSION#*.}"
  MINOR="${MINOR%%.*}"
  echo "${MAJOR}.${MINOR}-snapshot"
}
