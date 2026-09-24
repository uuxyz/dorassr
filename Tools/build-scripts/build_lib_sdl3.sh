#!/bin/bash
# SDL3 multi-platform build script (official CMake build).
# Usage: ./build_lib_sdl3.sh [macos|ios|android|linux|all] [--debug] [arm64|x86_64|universal]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SDL_DIR="$SCRIPT_DIR/../../Source/3rdParty/SDL3"
cd "$SDL_DIR"

BUILD_MODE="release"
MACOS_ARCH="universal"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
	echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
	echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
	echo -e "${RED}[ERROR]${NC} $1"
}

while [ $# -gt 0 ]; do
	case "$1" in
	--debug|-d)
		BUILD_MODE="debug"
		;;
	--release|-r)
		BUILD_MODE="release"
		;;
	macos|ios|android|linux|all)
		TARGET_PLATFORM="$1"
		;;
	arm64|x86_64|universal)
		MACOS_ARCH="$1"
		;;
	*)
		log_error "Unknown argument: $1"
		echo "Usage: $0 [macos|ios|android|linux|all] [--debug] [arm64|x86_64|universal]" >&2
		exit 1
		;;
	esac
	shift
done

TARGET_PLATFORM=${TARGET_PLATFORM:-all}

CMAKE_MODE=Release
if [ "$BUILD_MODE" = "debug" ]; then
	CMAKE_MODE=Debug
fi

clean_build() {
	rm -rf "$1"
}

# 通用配置：静态库 + PIC，与旧 SDL2 产物形态保持一致
common_cmake_opts=(
	-DCMAKE_BUILD_TYPE="$CMAKE_MODE"
	-DCMAKE_POSITION_INDEPENDENT_CODE=ON
	-DSDL_SHARED=OFF
	-DSDL_STATIC=ON
	-DSDL_TEST_LIBRARY=OFF
	-DSDL_TESTS=OFF
	-DSDL_EXAMPLES=OFF
	-DSDL_DISABLE_INSTALL_DOCS=ON
)

build_macos() {
	local archs
	if [ "$MACOS_ARCH" = "universal" ]; then
		archs="arm64 x86_64"
	else
		archs="$MACOS_ARCH"
	fi

	log_info "=== Building SDL3 macOS ($MACOS_ARCH) ==="
	local libs=()
	for arch in $archs; do
		local build_dir="build/cmake-macos-$arch-$BUILD_MODE"
		clean_build "$build_dir"
		cmake -S . -B "$build_dir" \
			-DCMAKE_OSX_ARCHITECTURES="$arch" \
			"${common_cmake_opts[@]}"
		cmake --build "$build_dir" -j 8
		libs+=("$build_dir/libSDL3.a")
	done

	mkdir -p Lib/macOS
	if [ "${#libs[@]}" -gt 1 ]; then
		lipo -create "${libs[@]}" -output Lib/macOS/libSDL3.a
	else
		cp "${libs[0]}" Lib/macOS/libSDL3.a
	fi

	log_info "Created Lib/macOS/libSDL3.a"
	file Lib/macOS/libSDL3.a
}

build_ios() {
	log_info "=== Building SDL3 iOS (Device + Simulator) ==="

	local device_dir="build/cmake-ios-device-$BUILD_MODE"
	clean_build "$device_dir"
	cmake -S . -B "$device_dir" \
		-DCMAKE_SYSTEM_NAME=iOS \
		-DCMAKE_OSX_SYSROOT=iphoneos \
		-DCMAKE_OSX_ARCHITECTURES=arm64 \
		"${common_cmake_opts[@]}"
	cmake --build "$device_dir" -j 8

	local sim_dir="build/cmake-ios-sim-$BUILD_MODE"
	clean_build "$sim_dir"
	cmake -S . -B "$sim_dir" \
		-DCMAKE_SYSTEM_NAME=iOS \
		-DCMAKE_OSX_SYSROOT=iphonesimulator \
		-DCMAKE_OSX_ARCHITECTURES="x86_64;arm64" \
		"${common_cmake_opts[@]}"
	cmake --build "$sim_dir" -j 8

	mkdir -p Lib/iOS Lib/iOS-Simulator
	cp "$device_dir/libSDL3.a" Lib/iOS/libSDL3.a
	cp "$sim_dir/libSDL3.a" Lib/iOS-Simulator/libSDL3.a

	log_info "Created Lib/iOS/libSDL3.a and Lib/iOS-Simulator/libSDL3.a"
	file Lib/iOS/libSDL3.a Lib/iOS-Simulator/libSDL3.a
}

build_android() {
	log_info "=== Building SDL3 Android (arm64-v8a + armeabi-v7a + x86_64) ==="

	local ndk="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-${NDK_ROOT:-}}}"
	if [ -z "$ndk" ]; then
		log_error "ANDROID_NDK_HOME or NDK_ROOT must point to the Android NDK"
		exit 1
	fi
	local toolchain="$ndk/build/cmake/android.toolchain.cmake"
	if [ ! -f "$toolchain" ]; then
		log_error "NDK toolchain not found at $toolchain"
		exit 1
	fi

	for abi in arm64-v8a armeabi-v7a x86_64; do
		local build_dir="build/cmake-android-$abi-$BUILD_MODE"
		clean_build "$build_dir"
		cmake -S . -B "$build_dir" \
			-DCMAKE_TOOLCHAIN_FILE="$toolchain" \
			-DANDROID_ABI="$abi" \
			-DANDROID_PLATFORM=android-21 \
			"${common_cmake_opts[@]}"
		cmake --build "$build_dir" -j 8
		mkdir -p "Lib/Android/$abi"
		local so
		so=$(find "$build_dir" -name "libSDL3.so" | head -n 1)
		if [ -n "$so" ]; then
			cp "$so" "Lib/Android/$abi/libSDL3.so"
		else
			# 纯静态配置时回退拷贝静态库
			cp "$build_dir/libSDL3.a" "Lib/Android/$abi/libSDL3.a"
		fi
	done

	log_info "Created Android SDL3 libraries under Lib/Android/"
	find Lib/Android -name "libSDL3.*" -exec file {} \;
}

build_linux() {
	local host_arch arch
	if [ "$(uname -s)" != "Linux" ]; then
		log_error "Linux SDL3 build must run on a Linux host"
		exit 1
	fi

	host_arch="$(uname -m)"
	case "$host_arch" in
	x86_64 | amd64) arch=x86_64 ;;
	aarch64 | arm64) arch=aarch64 ;;
	*)
		log_error "Unsupported Linux architecture: $host_arch"
		exit 1
		;;
	esac

	log_info "=== Building SDL3 Linux ($arch) ==="
	local build_dir="build/cmake-linux-$arch-$BUILD_MODE"
	clean_build "$build_dir"
	cmake -S . -B "$build_dir" \
		-DCMAKE_POSITION_INDEPENDENT_CODE=ON \
		"${common_cmake_opts[@]}"
	cmake --build "$build_dir" -j 8
	cmake --install "$build_dir" --prefix "/usr/local" --config "$CMAKE_MODE"

	log_info "Installed SDL3 to /usr/local"
}

case "$TARGET_PLATFORM" in
macos)
	build_macos
	;;
ios)
	build_ios
	;;
android)
	build_android
	;;
linux)
	build_linux
	;;
all)
	build_macos
	build_ios
	build_android
	;;
*)
	log_error "Unsupported platform: $TARGET_PLATFORM"
	exit 1
	;;
esac
