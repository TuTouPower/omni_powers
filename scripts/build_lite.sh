#!/usr/bin/env bash
# build_lite：校验 lite 自带脚本与 heavy 源的一致性，防副本漂移。
# 用法: bash scripts/build_lite.sh [--sync]
#   默认校验（diff 逐字节复制的脚本 + 检查改造版关键差异标记）
#   --sync：把逐字节复制类脚本从 heavy 源重新拷贝（改造版不动，需人工同步）
# 逐字节复制类：op_coder_check / op_read_verdict / close_check（heavy 无 OP_HOME 依赖，原样复用）
# 改造版（人工维护）：op_check_env / op_jq / op_status / op_close_post / op_assemble_eval_brief
# 注：不用 declare -A（macOS 系统 bash 3.2 无关联数组），用 "dst|src" 平行列表。
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LITE="$REPO/skills/oplrun/scripts"
HEAVY_ORUN="$REPO/skills/oprun/scripts"
MODE="check"
[ "${1:-}" = "--sync" ] && MODE="sync"

# 逐字节复制类：lite 目标路径|heavy 源路径
VERBATIM="
$LITE/op_coder_check.sh|$HEAVY_ORUN/op_coder_check.sh
$LITE/op_read_verdict.sh|$HEAVY_ORUN/op_read_verdict.sh
$LITE/close_check.sh|$HEAVY_ORUN/close_check.sh
"

# 三份 op_check_env.sh 互为逐字节副本（oplrun 为主本，oplinit/oplintake 跟随）
CHECK_ENV_MAIN="$LITE/op_check_env.sh"
CHECK_ENV_COPIES="
$REPO/skills/oplinit/scripts/op_check_env.sh
$REPO/skills/oplintake/scripts/op_check_env.sh
"

# 改造版：lite 文件|必须存在的关键差异标记（grep 断言 lite 化未丢失）
MUTATED_MARK="
op_check_env.sh|lite 环境检查通过
op_status.sh|lite 无 closing 态
op_close_post.sh|lite 无 closing
op_assemble_eval_brief.sh|lite 裸评
op_jq.sh|op_jq（lite）
"

drift=0

check_pair() {
    local src="$1" dst="$2" label="$3"
    [ -f "$src" ] || { echo "[FAIL] 源缺失: $src"; drift=1; return; }
    [ -f "$dst" ] || { echo "[FAIL] 副本缺失: $dst"; drift=1; return; }
    if diff -q "$src" "$dst" >/dev/null; then
        echo "[OK] $label 一致"
    elif [ "$MODE" = "sync" ]; then
        cp "$src" "$dst"; chmod +x "$dst"
        echo "[SYNC] $label 已从源更新"
    else
        echo "[DRIFT] $label 与源不一致（--sync 修复，或确认是有意改造）"
        drift=1
    fi
}

echo "=== 逐字节复制类：diff 校验 ==="
while IFS='|' read -r dst src; do
    [ -n "$dst" ] || continue
    check_pair "$src" "$dst" "$(basename "$dst")"
done <<< "$VERBATIM"

echo "=== op_check_env.sh 三副本一致性（oplrun 为主本）==="
while read -r copy; do
    [ -n "$copy" ] || continue
    check_pair "$CHECK_ENV_MAIN" "$copy" "${copy#"$REPO"/}"
done <<< "$CHECK_ENV_COPIES"

echo "=== 改造版：关键差异标记校验 ==="
while IFS='|' read -r f mark; do
    [ -n "$f" ] || continue
    dst="$LITE/$f"
    [ -f "$dst" ] || { echo "[FAIL] lite 改造版缺失: $dst"; drift=1; continue; }
    if grep -qF "$mark" "$dst"; then
        echo "[OK] $f 含 lite 标记「$mark」"
    else
        echo "[FAIL] $f 丢失 lite 标记「$mark」——改造被覆盖?"
        drift=1
    fi
done <<< "$MUTATED_MARK"

echo ""
if [ "$drift" -eq 0 ]; then
    echo "[OK] lite 副本无漂移"
else
    echo "[WARN] 检测到漂移或缺失，见上"
    [ "$MODE" = "check" ] && exit 1
fi
