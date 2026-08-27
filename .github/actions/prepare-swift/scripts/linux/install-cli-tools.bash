#!/usr/bin/env bash

set -Euo pipefail

# List of required packages
REQUIRED_PACKAGES=("curl" "zip" "jq")
PACKAGES_TO_INSTALL=()

# Check which packages are missing
for package in "${REQUIRED_PACKAGES[@]}"; do
  if ! command -v "$package" &> /dev/null; then
    PACKAGES_TO_INSTALL+=("$package")
  fi
done

# Only update apt and install if there are packages to install
if [[ ${#PACKAGES_TO_INSTALL[@]} -gt 0 ]]; then
  echo "Updating apt"
  apt-get update

  for package in "${PACKAGES_TO_INSTALL[@]}"; do
    echo "Installing $package"
    apt-get install -y "$package"
  done
else
  echo "All required packages are already installed"
fi
