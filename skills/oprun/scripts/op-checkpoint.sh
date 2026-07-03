#!/usr/bin/env bash
# op-checkpoint：每 task 闭环后自动更新 leader_checkpoint.md 的机械部分
# 用法: op-checkpoint.sh <TID>
# commit 后跑。自动取最新 commit hash + 从 tasks_list.json 取 title。
# 跑完后 leader 手动编辑"关键上下文"段，然后跑 close_check.sh 验收。
set -euo pipefail

# #48: 临时文件异常清理
trap 'rm -f /tmp/op_checkpoint_status_$$.md /tmp/op_checkpoint_$$.md' EXIT INT TERM

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TID="${1:?用法: op-checkpoint.sh <TID>}"

CHECKPOINT="$ROOT/docs/omni_powers/op_execution/leader_checkpoint.md"
TASKS_LIST="$ROOT/docs/omni_powers/op_execution/tasks_list.json"

HASH=$(git rev-parse HEAD)
TITLE=$(jq -r ".tasks[] | select(.id == \"$TID\") | .title" "$TASKS_LIST" 2>/dev/null || echo "")

# --- 1. 追加已完成 task ---
if [ -n "$TITLE" ] && [ -n "$HASH" ]; then
    sed -i "/^## 已完成 task$/a - ${TID} \"${TITLE}\" ✅ ${HASH}" "$CHECKPOINT"
fi

# --- 2. 生成 tasks_list 状态 ---
status_json=$(jq -r '[.tasks[] | {id, status, blocked_by}]' "$TASKS_LIST" 2>/dev/null || echo "[]")

done_ids=$(echo "$status_json" | jq -r '[.[] | select(.status == "完成") | .id] | join(", ")' 2>/dev/null || echo "")
pending_ids=$(echo "$status_json" | jq -r '[.[] | select(.status == "待开始") | .id] | join(", ")' 2>/dev/null || echo "")
pending_plan_ids=$(echo "$status_json" | jq -r '[.[] | select(.status == "待规划") | .id] | join(", ")' 2>/dev/null || echo "")
blocked=$(echo "$status_json" | jq -r '[.[] | select(.status == "阻塞") | "\(.id)(\(.blocked_by))"] | join(", ")' 2>/dev/null || echo "")
skipped_ids=$(echo "$status_json" | jq -r '[.[] | select(.status == "跳过") | .id] | join(", ")' 2>/dev/null || echo "")
suspended_ids=$(echo "$status_json" | jq -r '[.[] | select(.status == "挂起") | .id] | join(", ")' 2>/dev/null || echo "")

{
    echo "## tasks_list 状态"
    echo ""
    echo "<!-- AUTO -->"
    echo "- 完成：${done_ids:-无}"
    echo "- 待开始：${pending_ids:-无}"
    echo "- 待规划：${pending_plan_ids:-无}"
    echo "- 阻塞：${blocked:-无}"
    echo "- 跳过：${skipped_ids:-无}"
    echo "- 挂起：${suspended_ids:-无}"
    echo ""
} > "/tmp/op_checkpoint_status_$$.md"

awk -v repl="$(cat /tmp/op_checkpoint_status_$$.md)" '
    /^## tasks_list 状态$/ { print repl; skip=1; next }
    /^## / && skip { skip=0 }
    !skip
' "$CHECKPOINT" > "/tmp/op_checkpoint_$$.md" && mv "/tmp/op_checkpoint_$$.md" "$CHECKPOINT"

rm -f "/tmp/op_checkpoint_status_$$.md"

echo "[OK] checkpoint 机械部分已更新：${TID} (${HASH:0:7})"
echo "[TODO] leader 请编辑 '关键上下文' 段，完成后跑 close_check.sh {TID}"
