#!/bin/bash

PLATFORM=$(uname -s)

SOURCE_TRUST_DIR=".github/workflows/scripts/spm-trust/assets"

if [ "$PLATFORM" == "Darwin" ]; then
  SPM_CACHE_DIR="${HOME}/Library/org.swift.swiftpm"
else
  SPM_CACHE_DIR="${HOME}/.cache/org.swift.swiftpm"
fi

SPM_TRUST_DIR="${SPM_CACHE_DIR}/security"

mkdir -p "${SPM_TRUST_DIR}"

echo "Copying macros.json to ${SPM_TRUST_DIR}/macros.json"
cp -r "${SOURCE_TRUST_DIR}/macros.json" "${SPM_TRUST_DIR}/macros.json"

echo "Copying plugins.json to ${SPM_TRUST_DIR}/plugins.json"
cp -r "${SOURCE_TRUST_DIR}/plugins.json" "${SPM_TRUST_DIR}/plugins.json"

echo "Done"
