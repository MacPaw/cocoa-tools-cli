#!/usr/bin/env bash

set -Euo pipefail

if command -v xcrun > /dev/null; then
  echo "xcrun swift --version:"
  xcrun swift --version
  echo "xcrun swift sdk list:"
  xcrun swift sdk list || echo "No Swift SDKs found"
  echo "--------------------------------"
fi

if command -v swiftly > /dev/null; then
  echo "swiftly run swift --version:"
  swiftly run swift --version || echo "No Swift version found"
  echo "swiftly run swift sdk list:"
  swiftly run swift sdk list || echo "No Swift SDKs found"
  echo "--------------------------------"
fi

if command -v swift > /dev/null; then
  echo "swift --version:"
  swift --version
  echo "swift sdk list:"
  swift sdk list || echo "No Swift SDKs found"
  echo "--------------------------------"
fi
