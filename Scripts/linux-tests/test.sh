#!/bin/sh

set -Eeo

echo "Removing copy..."
rm -rf /package-copy

mkdir -p /package-copy/.build

echo "Trusting Swift Package Macros and Plugins..."
./.github/workflows/scripts/spm-trust/spm-trust.sh

echo "Copying sources..."
cp -r Sources Tests Package.swift Package.resolved /package-copy

echo "Copying SPM package cache..."
# cp -r .build/checkouts .build/repositories .build/plugins .build/workspace-state.json /package-copy/.build || true

echo "Changing directory..."
cd /package-copy

echo "Current directory:"
pwd

echo "Removing previous build..."
rm -rf .build/*-linux-* || true

# echo "Cleaning..."
# /usr/bin/swift package clean

# echo "Resolving packages..."
# /usr/bin/swift package resolve

echo "Building..."
/usr/bin/swift build

echo "Testing..."
/usr/bin/swift test

echo "Removing copy..."
rm -rf /package-copy
