#!/usr/bin/env bash

set -Eeo pipefail

sudo xcode-select -s "/Applications/Xcode_${XCODE_VERSION}.app"

defaults write com.apple.dt.Xcode IDEPackageEnablePrebuilts YES
