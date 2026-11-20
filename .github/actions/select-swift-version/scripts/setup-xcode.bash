#!/usr/bin/env bash

set -Eeo pipefail

sudo xcode-select -s "/Applications/Xcode_${XCODE_VERSION}.app"

echo "  Enable prebuilt Swift packages"
defaults write com.apple.dt.Xcode IDEPackageEnablePrebuilts YES

echo "  Skip macro fingerprint validation"
defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES
