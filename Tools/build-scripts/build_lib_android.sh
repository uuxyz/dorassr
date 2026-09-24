#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_MODE="${1:-debug}"

case "$BUILD_MODE" in
	debug|--debug|-d)
		BUILD_MODE="debug"
		CARGO_PROFILE="debug"
		CARGO_ARGS=()
		;;
	release|--release|-r)
		BUILD_MODE="release"
		CARGO_PROFILE="release"
		CARGO_ARGS=(--release)
		;;
	*)
		echo "Usage: $0 [debug|release]" >&2
		exit 1
		;;
esac

"$SCRIPT_DIR/check_build_env.sh" android lib

# 五个第三方库互不依赖，并行构建（各自独立的项目目录与日志）；
# 任一失败即整体失败。
LOG_DIR="$(mktemp -d)"
"$SCRIPT_DIR/build_lib_sdl3.sh" android "--$BUILD_MODE" > "$LOG_DIR/sdl3.log" 2>&1 &
P_SDL3=$!
"$SCRIPT_DIR/build_lib_bgfx.sh" android "--$BUILD_MODE" > "$LOG_DIR/bgfx.log" 2>&1 &
P_BGPUX=$!
"$SCRIPT_DIR/build_lib_love.sh" android "--$BUILD_MODE" > "$LOG_DIR/love.log" 2>&1 &
P_LOVE=$!
"$SCRIPT_DIR/build_lib_theora.sh" android "--$BUILD_MODE" > "$LOG_DIR/theora.log" 2>&1 &
P_THEORA=$!
"$SCRIPT_DIR/build_lib_wa.sh" android "$BUILD_MODE" > "$LOG_DIR/wa.log" 2>&1 &
P_WA=$!

FAIL=0
for pair in "$P_SDL3:sdl3" "$P_BGPUX:bgfx" "$P_LOVE:love" "$P_THEORA:theora" "$P_WA:wa"; do
	P=${pair%%:*}; NAME=${pair##*:}
	if ! wait "$P"; then
		echo "=== $NAME build failed, log tail: ===" >&2
		grep -n -B3 -A3 -iE "error|failed" "$LOG_DIR/$NAME.log" >&2 | tail -120 || true
		tail -120 "$LOG_DIR/$NAME.log" >&2
		FAIL=1
	fi
done
[ "$FAIL" -eq 0 ] || exit 1

cd "$SCRIPT_DIR/../../Source/Rust"

rustup target add aarch64-linux-android
rustup target add armv7-linux-androideabi
rustup target add x86_64-linux-android

NDK_PATH="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-${NDK_ROOT:-}}}"
if [ -z "$NDK_PATH" ]; then
	echo "Android NDK path is required to compile the Jolt C++ runtime." >&2
	exit 1
fi
TOOLCHAIN_DIRS=("$NDK_PATH/toolchains/llvm/prebuilt/"*)
TOOLCHAIN_BIN="${TOOLCHAIN_DIRS[0]}/bin"
ANDROID_API="${ANDROID_API:-28}"

build_rust_target() { # target env_target compiler_prefix out_dir
	local target="$1" env_target="$2" compiler_prefix="$3" out_dir="$4"
	env \
		"CC_$env_target=$TOOLCHAIN_BIN/${compiler_prefix}${ANDROID_API}-clang" \
		"CXX_$env_target=$TOOLCHAIN_BIN/${compiler_prefix}${ANDROID_API}-clang++" \
		"AR_$env_target=$TOOLCHAIN_BIN/llvm-ar" \
		"CARGO_TARGET_DIR=target/$out_dir" \
		cargo build "${CARGO_ARGS[@]}" --target "$target"
	# CARGO_TARGET_DIR + --target 并用时产物位于 TARGET_DIR/TRIPLE/PROFILE/
	cp "target/$out_dir/$target/$CARGO_PROFILE/libdora_runtime.a" "lib/Android/$out_dir/libdora_runtime.a"
}

# 三个 target 的构建目录互不相交，可并行
build_rust_target aarch64-linux-android aarch64_linux_android aarch64-linux-android arm64-v8a &
P1=$!
build_rust_target armv7-linux-androideabi armv7_linux_androideabi armv7a-linux-androideabi armeabi-v7a &
P2=$!
build_rust_target x86_64-linux-android x86_64_linux_android x86_64-linux-android x86_64 &
P3=$!
FAIL=0
for P in $P1 $P2 $P3; do wait "$P" || FAIL=1; done
[ "$FAIL" -eq 0 ] || { echo "Rust runtime build failed" >&2; exit 1; }
