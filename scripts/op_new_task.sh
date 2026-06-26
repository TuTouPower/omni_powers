#!/usr/bin/env bash
# op-new-task：建 task 工作区目录并拷模板
# 用法: op_new_task.sh <TID>
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TID="${1:?用法: op_new_task.sh <TID>}"
TASK_DIR="$ROOT/docs/op_execution/tasks/$TID"
TEMPLATE_DIR="$ROOT/template/op_execution/tasks/{TID}"

die() { echo "[FAIL] $*" >&2; exit 1; }

[ -d "$TEMPLATE_DIR" ] || die "模板目录不存在: $TEMPLATE_DIR"

mkdir -p "$TASK_DIR"

for f in spec.md plan.md context.md steps.md; do
    src="$TEMPLATE_DIR/$f"
    dst="$TASK_DIR/$f"
    [ -f "$src" ] || die "模板缺失: $src"
    cp "$src" "$dst"
done

echo "[OK] $TID 工作区已创建: $TASK_DIR"
