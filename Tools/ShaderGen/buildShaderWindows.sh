#!/bin/bash
# 再生成 Source/Shader/**/*.bin.h（Windows 版；供 CI 在 msbuild 前调用）。
# 目标含 dxbc/dxil（依赖 Windows SDK 的 D3DCompiler/DXC）；wgsl 需 tint，跳过。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TOOL="${1:-}"
if [ -z "$TOOL" ]; then
	for c in \
		"$ROOT/Source/3rdParty/bgfx/build/windows/x64/release/shaderc-cli.exe" \
		"$ROOT/Source/3rdParty/bgfx/build/windows/x86/release/shaderc-cli.exe" \
		"$ROOT/Source/3rdParty/bgfx/build/windows/x64/debug/shaderc-cli.exe" \
		"$ROOT/Source/3rdParty/bgfx/build/windows/x86/debug/shaderc-cli.exe"; do
		[ -f "$c" ] && TOOL="$c" && break
	done
fi
[ -n "$TOOL" ] && [ -f "$TOOL" ] || { echo "shaderc-cli not found; build it via: xmake -j8 shaderc-cli" >&2; exit 1; }

BGFX_SRC="$ROOT/Source/3rdParty/bgfx/src"
SHADER_PATH="$ROOT/Source/Shader"

targets=(
	"300_es android essl"
	"330 osx glsl"
	"spirv linux spv"
	"metal osx mtl"
	"s_5_0 windows dxbc"
)

compile() { # <dir> <file> <stage> <bin2c-name> <out-bin.h> <varyingdef> [extra]
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

dir="$SHADER_PATH/Model3D"
: > "$dir/fs_model3d_sheen.bin.h"
compile "$dir" fs_model3d.sc f fs_model3d_sheen "$dir/fs_model3d_sheen.bin.h" "$dir/varying.def.sc" \
	"--define DORA_SHEEN_ROUGHNESS_TEXTURE=1"
: > "$dir/fs_model3d_thickness_sheen.bin.h"
compile "$dir" fs_model3d.sc f fs_model3d_thickness_sheen "$dir/fs_model3d_thickness_sheen.bin.h" "$dir/varying.def.sc" \
	"--define DORA_THICKNESS_SHEEN_TEXTURE=1"

dir="$SHADER_PATH/efkbgfx"
# efkbgfx 命名不是规则的 <model>_<Type>_<stage>：按原 buildShaderMac.yue 显式映射
# modeltype shadertype  vs-name                fs-name
efk_map=(
	"sprite Unlit             sprite_unlit_vs          model_unlit_ps"
	"sprite Lit               sprite_lit_vs            model_lit_ps"
	"sprite BackDistortion    sprite_distortion_vs     model_distortion_ps"
	"sprite AdvancedUnlit     ad_sprite_unlit_vs       ad_model_unlit_ps"
	"sprite AdvancedLit       ad_sprite_lit_vs         ad_model_lit_ps"
	"sprite AdvancedBackDistortion ad_sprite_distortion_vs ad_model_distortion_ps"
	"model  Unlit             model_unlit_vs           model_unlit_ps"
	"model  Lit               model_lit_vs             model_lit_ps"
	"model  BackDistortion    model_distortion_vs      model_distortion_ps"
	"model  AdvancedUnlit     ad_model_unlit_vs        ad_model_unlit_ps"
	"model  AdvancedLit       ad_model_lit_vs          ad_model_lit_ps"
	"model  AdvancedBackDistortion ad_model_distortion_vs ad_model_distortion_ps"
)

for entry in "${efk_map[@]}"; do
	read -r modeltype shadertype vsname fsname <<<"$entry"
	for pair in "$vsname v" "$fsname f"; do
		read -r sname stage <<<"$pair"
		[ -e "$dir/$sname.fx.sc" ] || { echo "missing $dir/$sname.fx.sc" >&2; continue; }
		: > "$dir/$sname.bin.h"
		compile "$dir" "$sname.fx.sc" "$stage" "$sname" "$dir/$sname.bin.h" \
			"$dir/${modeltype}_${shadertype}_varying.def.sc"
	done
done

echo "All shaders regenerated."
