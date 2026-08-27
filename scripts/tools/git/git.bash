#!/usr/bin/env bash

set -Eeo pipefail

REPOSITORY_ROOT_DIR="${REPOSITORY_ROOT_DIR:-"$(git rev-parse --show-toplevel 2> /dev/null || pwd)"}"

function git_configure_gitconfig() {
  echo "Changing directory to the repository root directory: ${REPOSITORY_ROOT_DIR}"
  cd "${REPOSITORY_ROOT_DIR}"

  echo "Updating git config to include the .gitconfig from the repository root"
  git config --local include.path ../.gitconfig

  echo "Verifying the git config inclues the .gitconfig from the repository root"
  git config --local include.path | (grep -q "../.gitconfig" && echo "  ✅ git config inclues the .gitconfig from the repository root") || {
    echo "Failed to include the .gitconfig from the repository root"
    exit 1
  }
}

function git_configure_lfs_sshtransfer() {

  echo "Verifying lfs.sshtransfer is disabled"
  # An unset key makes `git config --get` exit non-zero, which would abort the script before the
  # diagnostic below under `set -e`.
  LFS_SSH_TRANSFER=$(git config --show-origin --get lfs.sshtransfer | grep "file:.git/../.gitconfig" | awk '{ print $2 }' || true)
  if [[ ${LFS_SSH_TRANSFER} != 'never' ]]; then
    echo "Unfortunately LFS SSH transfer is enabled and looks like local config file is not set correctly."
    exit 1
  else
    echo "  ✅ LFS SSH transfer is disabled."
  fi
}

die() {
  echo "${*}" >&2
  exit 2
} # complain to STDERR and exit with error
needs_arg() { if [ -z "$OPTARG" ]; then die "No arg for --${OPTSPEC} option"; fi; }

while getopts "a:-:" OPTSPEC; do

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
    *)
      die "Invalid action: ${OPTSPEC}"
      ;;
  esac
done

if [[ ${ACTION} == "bootstrap" ]]; then
  git_configure_gitconfig
  git_configure_lfs_sshtransfer
fi
