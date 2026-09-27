#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_MODE="${1:-debug}"

case "$BUILD_MODE" in
	debug|--debug|-d)
		BUILD_MODE="debug"
		CARGO_ARGS=()
		;;
	release|--release|-r)
		BUILD_MODE="release"
		CARGO_ARGS=(--release)
		;;
	*)
		echo "Usage: $0 [debug|release]" >&2
		exit 1
		;;
esac

case "${DORA_WITH_SPINE:-0}" in
	1|ON|on|TRUE|true) CARGO_ARGS+=(--features spine) ;;
esac

cd "$SCRIPT_DIR/../../Source/Rust"

rustup target add i686-pc-windows-msvc
cargo build "${CARGO_ARGS[@]}" --target i686-pc-windows-msvc
cp "target/i686-pc-windows-msvc/$BUILD_MODE/dora_runtime.lib" lib/Windows/dora_runtime.lib
