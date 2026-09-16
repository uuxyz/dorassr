#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_MODE="${1:-debug}"

case "$BUILD_MODE" in
	debug|--debug|-d)
		BUILD_MODE="debug"
		XCODE_CONFIGURATION="Debug"
		;;
	release|--release|-r)
		BUILD_MODE="release"
		XCODE_CONFIGURATION="Release"
		;;
	*)
		echo "Usage: $0 [debug|release]" >&2
		exit 1
		;;
esac

"$SCRIPT_DIR/build_lib_ios.sh" "$BUILD_MODE"

cd "$SCRIPT_DIR/../.."

# Xcode 工程由 CMake 生成（单一构建约定来源，见 Projects/apple/AppleApp.cmake）
cmake -S Projects/iOS -B Projects/iOS/build-cmake -G Xcode \
	-DCMAKE_SYSTEM_NAME=iOS \
	-DCMAKE_OSX_SYSROOT=iphonesimulator \
	-DCMAKE_OSX_ARCHITECTURES=arm64 \
	-DCMAKE_BUILD_TYPE="$XCODE_CONFIGURATION" \
	-DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO
cmake --build Projects/iOS/build-cmake --config "$XCODE_CONFIGURATION" -j 8

echo "Built APP for iOS Simulator ($XCODE_CONFIGURATION)"
