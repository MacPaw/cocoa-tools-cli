#!/usr/bin/env sh

# Running test on a package copy to avoid modifying files in the original package folder (.build, .swiftpm, etc.).
prepare_package_copy() {
  echo "Removing copy..."
rm -rf /package-copy

mkdir -p /package-copy/.build

echo "Trusting Swift Package Macros and Plugins..."
./.github/workflows/scripts/spm-trust/spm-trust.sh

echo "Copying sources with Plugins..."
cp -r Plugins Sources Tests Package.swift Package.resolved .version /package-copy

echo "Copying resolved packages..."
cp -r .build/checkouts \
  .build/repositories \
  .build/plugins \
  .build/workspace-state.json \
  .build/prebuilts \
  \
  /package-copy/.build \
  || true

echo "Copying necessary scripts..."
mkdir -p /package-copy/scripts/tools/swift
cp -r ./scripts/tools/swift/swift.sh /package-copy/scripts/tools/swift/swift.sh

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
