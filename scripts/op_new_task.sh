#!/usr/bin/env bash
# op_new_task：建 task 工作区目录并拷三模板（brief/report/review）
# 用法: op_new_task.sh <TID>
# spec 不在 task 目录——叶子共享于 docs/omni_powers/op_execution/specs/{前缀}.md
set -euo pipefail

TID="${1:?用法: op_new_task.sh <TID>}"
PLUGIN_ROOT="${OP_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TASK_DIR="$ROOT/docs/omni_powers/op_execution/tasks/$TID"
TEMPLATE_DIR="$PLUGIN_ROOT/docs_template/omni_powers/op_execution/tasks/{TID}"

die() { echo "[FAIL] $*" >&2; exit 1; }

[ -d "$TEMPLATE_DIR" ] || die "模板目录不存在: $TEMPLATE_DIR（检查 OP_HOME=$PLUGIN_ROOT）"
[ -e "$TASK_DIR" ] && die "task 已存在: $TASK_DIR"

mkdir -p "$TASK_DIR"

for f in brief.md report.md review.md; do
    [ -f "$TEMPLATE_DIR/$f" ] || die "模板缺失: $TEMPLATE_DIR/$f"
    cp "$TEMPLATE_DIR/$f" "$TASK_DIR/$f"
done

echo "[OK] $TID 工作区已创建: $TASK_DIR（brief/report/review 三文件）"
