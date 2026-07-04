#!/usr/bin/env bash
# op_new_task：建 task 工作区（默认）或录待规划种子（--seed）
# 用法:
#   op_new_task.sh <TID>                        建 task 工作区（brief/report/review）
#   op_new_task.sh --seed <TID> <title> [type]  录待规划种子到 tasks_list.json（不建工作区）
set -euo pipefail

PLUGIN_ROOT="${OP_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TASKS_FILE="$ROOT/docs/omni_powers/op_execution/tasks_list.json"

die() { echo "[FAIL] $*" >&2; exit 1; }

# --- --seed 模式：录待规划种子（不建工作区）---
if [ "${1:-}" = "--seed" ]; then
  TID="${2:?用法: op_new_task.sh --seed <TID> <title> [type]}"
  TITLE="${3:?缺少 title}"
  TYPE="${4:-feat}"
  [ -f "$TASKS_FILE" ] || die "tasks_list.json 不存在: $TASKS_FILE"
  command -v jq >/dev/null 2>&1 || die "jq 未装"
  jq -e --arg tid "$TID" '.tasks[] | select(.id == $tid)' "$TASKS_FILE" >/dev/null 2>&1 && die "TID 已存在: $TID"
  jq --arg tid "$TID" --arg title "$TITLE" --arg type "$TYPE" \
    '.tasks += [{"id":$tid,"title":$title,"status":"待规划","spec":"","type":$type,"covers_ac":[],"touches_inv":[],"depends_on":null,"risk_probe":false,"workset":[]}]' \
    "$TASKS_FILE" > "$TASKS_FILE.tmp" && mv "$TASKS_FILE.tmp" "$TASKS_FILE"
  echo "[OK] 待规划种子 $TID 已录入 tasks_list.json（未建工作区）"
  exit 0
fi

# --- 默认模式：建 task 工作区 ---
TID="${1:?用法: op_new_task.sh <TID> 或 op_new_task.sh --seed <TID> <title> [type]}"
TASK_DIR="$ROOT/docs/omni_powers/op_execution/tasks/$TID"
TEMPLATE_DIR="$PLUGIN_ROOT/docs_template/omni_powers/op_execution/tasks/{TID}"

[ -d "$TEMPLATE_DIR" ] || die "模板目录不存在: $TEMPLATE_DIR（检查 OP_HOME=$PLUGIN_ROOT）"
[ -e "$TASK_DIR" ] && die "task 已存在: $TASK_DIR"

mkdir -p "$TASK_DIR"
for f in brief.md report.md review.md; do
    [ -f "$TEMPLATE_DIR/$f" ] || die "模板缺失: $TEMPLATE_DIR/$f"
    cp "$TEMPLATE_DIR/$f" "$TASK_DIR/$f"
done

echo "[OK] $TID 工作区已创建: $TASK_DIR（brief/report/review 三文件）"
