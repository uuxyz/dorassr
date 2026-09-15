#!/bin/bash
# 再生成 Source/Shader/**/*.bin.h 嵌入着色器（Linux 版，对应 buildShaderMac.yue）。
# 用法: Tools/ShaderGen/buildShaderLinux.sh [shaderc-cli 路径]
# 目标: essl/glsl/spv/mtl/wgsl（dxbc/dxil 需 Windows SDK，请用 buildShaderWin.yue 生成）

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TOOL="${1:-$ROOT/Source/3rdParty/bgfx/build/linux/x86_64/release/shaderc-cli}"
BGFX_SRC="$ROOT/Source/3rdParty/bgfx/src"
SHADER_PATH="$ROOT/Source/Shader"

targets=(
	"300_es android essl"
	"330 osx glsl"
	"spirv linux spv"
	"metal osx mtl"
)

compile() { # <dir> <file> <stage(v|f)> <bin2c-name> <out-bin.h> <varyingdef> [extra defines]
	local dir=$1 file=$2 stage=$3 name=$4 target=$5 varyingdef=$6 extra=${7:-}
	for t in "${targets[@]}"; do
		read -r profile platform suffix <<<"$t"
		local tmp="$dir/tmp_$suffix"
		# shellcheck disable=SC2086
		"$TOOL" -i "$dir" -i "$BGFX_SRC" --type "$stage" --platform "$platform" \
			-f "$dir/$file" -o "$tmp" -p "$profile" -O 3 \
			--bin2c "${name}_${suffix}" --varyingdef "$varyingdef" $extra
		cat "$tmp" >> "$target"
		rm -f "$tmp"
	done
}

# --- 普通目录: 每个场景 {vs,fs}_*.sc 共享 varying.def.sc ---
for dirpath in "$SHADER_PATH"/*/; do
	dirname=$(basename "$dirpath")
	case "$dirname" in efkbgfx|DoraShaderc) continue ;; esac
	[ -e "$dirpath/varying.def.sc" ] || continue
	for sc in "$dirpath"/vs_*.sc "$dirpath"/fs_*.sc; do
		[ -e "$sc" ] || continue
		case "$(basename "$sc")" in *varying*|*\.fx\.sc) continue ;; esac
		file=$(basename "$sc")
		name="${file%.sc}"
		stage=v; [[ "$file" == fs_* ]] && stage=f
		: > "$dirpath/$name.bin.h"
		compile "$dirpath" "$file" "$stage" "$name" "$dirpath/$name.bin.h" "$dirpath/varying.def.sc"
	done
done

# --- Model3D 材质变体: 同一 fragment 源 + 不同 define ---
dir="$SHADER_PATH/Model3D"
: > "$dir/fs_model3d_sheen.bin.h"
compile "$dir" fs_model3d.sc f fs_model3d_sheen "$dir/fs_model3d_sheen.bin.h" "$dir/varying.def.sc" \
	"--define DORA_SHEEN_ROUGHNESS_TEXTURE=1"
: > "$dir/fs_model3d_thickness_sheen.bin.h"
compile "$dir" fs_model3d.sc f fs_model3d_thickness_sheen "$dir/fs_model3d_thickness_sheen.bin.h" "$dir/varying.def.sc" \
	"--define DORA_THICKNESS_SHEEN_TEXTURE=1"

# --- efkbgfx: Effekseer 移植着色器（源: <name>.fx.sc，varying: <model>_<type>_varying.def.sc）---
dir="$SHADER_PATH/efkbgfx"
for modeltype in sprite model; do
	for shadertype in Unlit Lit BackDistortion AdvancedUnlit AdvancedLit AdvancedBackDistortion; do
		vs="${modeltype}_${shadertype}_vs"
		fs="${modeltype}_${shadertype}_ps"
		for pair in "$vs v" "$fs f"; do
			read -r sname stage <<<"$pair"
			[ -e "$dir/$sname.fx.sc" ] || continue
			: > "$dir/$sname.bin.h"
			compile "$dir" "$sname.fx.sc" "$stage" "$sname" "$dir/$sname.bin.h" \
				"$dir/${modeltype}_${shadertype}_varying.def.sc"
		done
	done
done

echo "All shaders regenerated."
