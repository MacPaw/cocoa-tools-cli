#!/bin/sh

set -Eeo pipefail

REPOSITORY_ROOT_DIR="${REPOSITORY_ROOT_DIR:-"$(git rev-parse --show-toplevel 2>/dev/null || pwd)"}"

mise_get_bin_path() {
  if [ -n "${MISE_BIN_PATH}" ]; then
    return
  fi

  MISE_BIN_NAME="mise"

  export MISE_BIN_PATH
  export MISE_IS_BREWED
  export MISE_IS_SELF_UPDATE_AVAILABLE

  if [ -f "${HOME}/.local/bin/${MISE_BIN_NAME}" ]; then
    # Installed with "curl https://mise.run | sh"
    MISE_BIN_PATH="${HOME}/.local/bin/${MISE_BIN_NAME}"
    MISE_IS_BREWED=false
    MISE_IS_SELF_UPDATE_AVAILABLE=true
  elif [ -f "/opt/homebrew/bin/${MISE_BIN_NAME}" ]; then
    # Installed with "brew install mise" on arm64
    MISE_BIN_PATH="/opt/homebrew/bin/${MISE_BIN_NAME}"
    MISE_IS_BREWED=true
    MISE_IS_SELF_UPDATE_AVAILABLE=false
  elif [ -f "/usr/local/bin/${MISE_BIN_NAME}" ]; then
    # Installed with "brew install mise" on x86_64
    MISE_BIN_PATH="/usr/local/bin/${MISE_BIN_NAME}"
    MISE_IS_BREWED=true
    MISE_IS_SELF_UPDATE_AVAILABLE=false
  elif which "${MISE_BIN_NAME}" >/dev/null 2>&1; then
    # mise not installed, or installation source is unknown
    MISE_BIN_PATH="$(which "${MISE_BIN_NAME}")"
    MISE_IS_BREWED=false
    MISE_IS_SELF_UPDATE_AVAILABLE=false
  else
    echo "❌ mise is not installed" >&2
    return 1
  fi

  return 0
}

mise_activate() {
  mise_install_if_needed

  if [[ -n ${MISE_BIN_PATH} ]]; then
    eval "$("${MISE_BIN_PATH}" activate --shims)"
  else
    echo "❌ Mise not found" >&2
  fi
}

mise_trust() {
  cd "${REPOSITORY_ROOT_DIR}"

  "${MISE_BIN_PATH}" trust --all --quiet --yes

  cd "${OLDPWD}"
}

mise_install_if_needed() {
  if mise_get_bin_path >/dev/null 2>&1; then
    return 0
  fi

  echo "[ 🧰   mise ] Installing mise..."
  curl -Ls https://mise.jdx.dev/install.sh | sh

  mise_get_bin_path
  mise_trust
}

mise_config_file() {
  if [ -f "${REPOSITORY_ROOT_DIR}/mise.toml" ]; then
    MISE_CONFIG_FILE="${REPOSITORY_ROOT_DIR}/mise.toml"
  elif [ -f "${REPOSITORY_ROOT_DIR}/.mise.toml" ]; then
    MISE_CONFIG_FILE="${REPOSITORY_ROOT_DIR}/.mise.toml"
  else
    MISE_CONFIG_FILE="${REPOSITORY_ROOT_DIR}/mise.local.toml"
  fi
}

mise_check_version() {
  mise_install_if_needed
  mise_config_file

  # Check if mise version is compatible with the required in .mise.toml
  MISE_VERSION="$("${MISE_BIN_PATH}" --version | awk '{ print $1 }')"
  NEEDED_MISE_VERSION="$(grep "min_version" "${MISE_CONFIG_FILE}" | sed "s/[^0-9.]*//g")"
  MAX_VERSION="$(printf '%s\n' "${MISE_VERSION}" "${NEEDED_MISE_VERSION}" | sort -rV | head -n1)"

  if [[ ${MISE_VERSION} == "${MAX_VERSION}" ]]; then
    return 0
  fi

  echo "mise version is ${MISE_VERSION}, needed version is ${NEEDED_MISE_VERSION}"
  if [ "${IS_BREWED_MISE}" == true ]; then
    echo "Updating brewed mise"
    brew upgrade mise || true
  elif [ "${MISE_IS_SELF_UPDATE_AVAILABLE}" == true ]; then
    echo "Self-updating mise"
    "${MISE_BIN_PATH}" self-update --yes || true
  else
    echo "mise self update is not available and it's not brewed. 🤷 how to upgrade it" >&2
  fi
}

mise_install_tools() {
  mise_check_version

  echo "[ 🧰   mise ] Installing tools"
  if ! "${MISE_BIN_PATH}" install --yes; then
    echo "[ 🧰   mise ] Updating plugins"
    "${MISE_BIN_PATH}" plugins update --yes || true

    echo "[ 🧰   mise ] Installing tools"
    "${MISE_BIN_PATH}" install --yes
  fi
}

OPTIND=

die() {
  echo "${*}" >&2
  exit 2
} # complain to STDERR and exit with error
needs_arg() { if [ -z "$OPTARG" ]; then die "No arg for --${OPTSPEC} option"; fi; }

while getopts "i:-:" OPTSPEC; do

  # support long options: https://stackoverflow.com/a/28466267/519360
  if [ "$OPTSPEC" = "-" ]; then   # long option: reformulate OPT and OPTARG
    OPTSPEC="${OPTARG%%=*}"       # extract long option name
    OPTARG="${OPTARG#"$OPTSPEC"}" # extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"          # if long option argument, remove assigning `=`
  fi

  case "${OPTSPEC}" in
    i | install)
      mise_install_tools
      ;;
    *)
      echo "Unknown option: ${OPTSPEC}" >&2
      echo "Available option: --install, -i  - install mise tools " >&2
      exit 1
      ;;
  esac
done
