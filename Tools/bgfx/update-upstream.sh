#!/bin/bash
# 三方合并式上游升级（git merge-tree，要求 git >= 2.38）。
#
# 与补丁队列的区别：本地修改是 main 分支上的普通 commit，上游只以
# "merge base 树 + 新版本树"的形式参与一次离线三方合并。上游历史不进入
# 本仓库，无冲突时升级就是一次普通提交。
#
# 用法:
#   ./update-upstream.sh <bgfx|bimg|bx> --fetch <ref>   （仓库地址读自各库 UPSTREAM 文件）
#   ./update-upstream.sh <bgfx|bimg|bx> --dir  <已解压的上游源码目录>
#   ./update-upstream.sh <bgfx|bimg|bx> --tree <上游树OID（调试用）>
#   选项: -n  只报告合并结果，不改动工作区
#
# 流程:
#   BASE   = bases 文件记录的上游树（上次同步点）
#   OURS   = HEAD:Source/3rdParty/<lib>   （上游 + Dora 修改）
#   THEIRS = 新上游树
#   git merge-tree --write-tree --merge-base=BASE OURS THEIRS
#   无冲突 → 把结果树挂回子路径，更新 bases，提示重新编译。
#   有冲突 → 结果树带冲突标记写盘，逐文件解决后提交；
#            base 在解决完成并提交后才更新（重跑脚本续传）。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STUBS_DIR=""
DRY=0

if [ "${1:-}" = "-n" ]; then DRY=1; shift; fi
LIB="${1:?usage: $0 [-n] <bgfx|bimg|bx> <source>}"
shift
case "$LIB" in
	bgfx|bimg|bx) ;;
	*) echo "unknown library: $LIB" >&2; exit 1 ;;
esac

cd "$ROOT"

# ---- 读取/校验 base（元数据存放在各库目录的 UPSTREAM 文件里，自描述）----
UPSTREAM_FILE="$ROOT/Source/3rdParty/$LIB/UPSTREAM"
[ -f "$UPSTREAM_FILE" ] || { echo "missing metadata file: $UPSTREAM_FILE" >&2; exit 1; }
get_base() {
	grep -E "^tree *=" "$UPSTREAM_FILE" | tail -1 | sed 's/^[^=]*= *//' | tr -d '[:space:]' || true
}
get_repo() {
	grep -E "^repository *=" "$UPSTREAM_FILE" | tail -1 | sed 's/^[^=]*= *//' | tr -d '[:space:]'
}
get_keep() {
	grep -E "^keep *=" "$UPSTREAM_FILE" | tail -1 | sed 's/^[^=]*= *//' | xargs
}
set_base() {
	local tree=$1 commit=${2:-}
	sed -i "s#^tree *=.*#tree       = $tree#" "$UPSTREAM_FILE"
	if [ -n "$commit" ]; then
		if grep -qE "^commit *=" "$UPSTREAM_FILE"; then
			sed -i "s#^commit *=.*#commit     = $commit#" "$UPSTREAM_FILE"
		else
			printf 'commit     = %s\n' "$commit" >> "$UPSTREAM_FILE"
		fi
	fi
}
BASE=$(get_base)
if [ -z "$BASE" ]; then
	# 首次迁移: 以 bgfx 整合基线提交（0836aa1d1）里的子树为准
	BASE=$(git rev-parse "0836aa1d1:Source/3rdParty/$LIB")
	set_base "$BASE"
	echo "[INFO] initialized $LIB base from import commit: $BASE"
fi

OURS=$(git rev-parse "HEAD:Source/3rdParty/$LIB")

# ---- 获取新上游树 ----
MODE=${1:-}
THEIRS=""
case "$MODE" in
	--fetch)
		URL=$(get_repo)
		REF=${2:?ref required}
		echo "[INFO] fetching $URL $REF ..."
		git fetch --no-tags "$URL" "$REF" >/dev/null 2>&1
		THEIRS=$(git rev-parse "FETCH_HEAD^{tree}")
		;;
	--dir)
		DIR=${2:?source dir required}
		[ -d "$DIR" ] || { echo "not a directory: $DIR" >&2; exit 1; }
		TMPIDX=$(mktemp)
		EMPTY=$(git hash-object -t tree /dev/null)
		GIT_INDEX_FILE="$TMPIDX" git read-tree "$EMPTY"
		GIT_INDEX_FILE="$TMPIDX" git --work-tree="$DIR" add -A
		THEIRS=$(GIT_INDEX_FILE="$TMPIDX" git write-tree)
		rm -f "$TMPIDX"
		;;
	--tree)
		THEIRS=${2:?tree oid required}
		;;
	*)
		echo "usage: $0 [-n] <bgfx|bimg|bx> --fetch <ref> | --dir <dir> | --tree <oid>" >&2
		exit 1
		;;
esac
[ -n "$THEIRS" ] || { echo "empty upstream tree" >&2; exit 1; }

# 裁剪上游树：UPSTREAM 文件里的 keep 列表声明保留的顶层目录/文件，
# 其余（tests、tools、.github 等引擎不用的内容）在合并前剔除，
# 这样上游新增目录不会作为"新文件"涌进合并结果。
KEEP=$(get_keep)
if [ -n "$KEEP" ]; then
	FULL="$THEIRS"
	TMPIDX=$(mktemp)
	GIT_INDEX_FILE="$TMPIDX" git read-tree "$THEIRS"
	for p in $(git ls-tree --name-only "$THEIRS"); do
		case " $KEEP " in
			*" $p "*) ;;
			*) GIT_INDEX_FILE="$TMPIDX" git rm -rf --cached -q --ignore-unmatch "$p" ;;
		esac
	done
	THEIRS=$(GIT_INDEX_FILE="$TMPIDX" git write-tree)
	rm -f "$TMPIDX"
	echo "[INFO] keep-list '$KEEP' applied: $FULL -> $THEIRS"
fi

[ "$THEIRS" != "$BASE" ] || { echo "upstream tree unchanged."; exit 0; }

# ---- 三方合并 ----
set +e
OUT=$(git merge-tree --write-tree --merge-base="$BASE" "$OURS" "$THEIRS")
RC=$?
set -e
TREE=$(printf '%s\n' "$OUT" | head -1)

if [ "$RC" -ne 0 ]; then
	echo ""
	echo "=== CONFLICTS ($LIB) — 解决以下文件中的冲突标记后提交 ==="
	printf '%s\n' "$OUT" | tail -n +2 | sed '/^$/d' | sed 's/^/  /'
	echo ""
	echo "合并树已就绪: $TREE"
	if [ "$DRY" -eq 1 ]; then echo "(dry-run: 未改动工作区)"; exit 1; fi
	git rm -r --cached --quiet "Source/3rdParty/$LIB" 2>/dev/null || true
	git read-tree --prefix="Source/3rdParty/$LIB/" "$TREE"
	git checkout-index -f -a
	set_base "$THEIRS" "$(git rev-parse FETCH_HEAD 2>/dev/null || echo)"
	echo "冲突已写盘。解决后: git add -A && git commit，然后重编译。"
	exit 1
fi

echo "merge clean: tree $TREE"
if [ "$DRY" -eq 1 ]; then
	echo "(dry-run) 变更预览:"
	git diff-tree -p --stat "$OURS" "$TREE" | tail -5
	exit 0
fi

# ---- 物化到工作区与索引 ----
git rm -r --cached --quiet "Source/3rdParty/$LIB"
git read-tree --prefix="Source/3rdParty/$LIB/" "$TREE"
git checkout-index -f -a
git clean -fd "Source/3rdParty/$LIB"
set_base "$THEIRS"

echo "完成。请运行 Tools/build-scripts/build_lib_bgfx.sh 重编译，并跑全平台构建。"
