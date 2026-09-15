#!/bin/bash
# 渲染边界检查：验证渲染设备依赖没有被重新泄漏到引擎全局。
#
# 规则:
#   1. 预编译头 Const/Header.h 不得包含任何 bgfx 头
#      （只允许 bx/platform.h 提供平台宏）
#   2. bgfx 头只允许出现在白名单目录（渲染模块及其适配器）中
#
# 用法: Tools/build-scripts/check_render_boundary.sh
# 退出码: 0 = 通过, 1 = 存在越界引用

set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SOURCE="$ROOT/Source"

fail=0

# --- 规则 1: 预编译头不得包含渲染设备 ---
if grep -qE 'include.*"(bgfx|bimg)/' "$SOURCE/Const/Header.h"; then
	echo "FAIL: Const/Header.h includes a render device header."
	grep -nE 'include.*"(bgfx|bimg)/' "$SOURCE/Const/Header.h"
	fail=1
fi

# --- 规则 2: bgfx 包含仅限白名单目录 ---
# 渲染模块本体、渲染器适配器、以及 3rdParty 中与渲染直接对接的库。
ALLOWED_DIRS=(
	"$SOURCE/Render"
	"$SOURCE/Shader"
	"$SOURCE/Cache"
	"$SOURCE/Node"
	"$SOURCE/Effect"
	"$SOURCE/GUI"
	"$SOURCE/Love"
	"$SOURCE/Lua"
	"$SOURCE/Platformer"
	"$SOURCE/3rdParty/font"
	"$SOURCE/3rdParty/nanovg"
	"$SOURCE/3rdParty/Other"
	"$SOURCE/3rdParty/implot"
	"$SOURCE/3rdParty/Effekseer"
)

# 单独放行的文件：渲染编排逻辑位于 Director（引擎渲染主循环所在）。
ALLOWED_FILES=(
	"$SOURCE/Basic/Director.cpp"
)

violations=$(grep -rlE 'include[[:space:]]*[<"]bgfx/' \
	"$SOURCE" --include="*.h" --include="*.hpp" --include="*.cpp" \
	| grep -vE "^$SOURCE/3rdParty/(bgfx|bx|bimg|shaderc)/")

while IFS= read -r file; do
	[ -z "$file" ] && continue
	allowed=0
	for dir in "${ALLOWED_DIRS[@]}"; do
		case "$file" in
			"$dir"/*) allowed=1; break ;;
		esac
	done
	if [ "$allowed" -eq 0 ]; then
		for allowed_file in "${ALLOWED_FILES[@]}"; do
			[ "$file" = "$allowed_file" ] && allowed=1 && break
		done
	fi
	if [ "$allowed" -eq 0 ]; then
		echo "FAIL: bgfx include outside render whitelist: $file"
		grep -nE 'include[[:space:]]*[<"]bgfx/' "$file"
		fail=1
	fi
done <<< "$violations"

if [ "$fail" -eq 0 ]; then
	echo "render boundary OK"
fi
exit "$fail"
