#!/usr/bin/env bash
# op_close_post：收口后机械步骤（校验 + 归档 + 记录 + stage）
# 用法: op_close_post.sh <TID> <feature>
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TID="${1:?用法: op_close_post.sh <TID> <feature>}"
FEATURE="${2:?缺少 feature}"
TASK_DIR="$ROOT/docs/omni_powers/op_execution/tasks/$TID"
ARCHIVE_DIR="$ROOT/docs/omni_powers/op_record/tasks/$TID"
PROGRESS_FILE="$ROOT/docs/omni_powers/op_record/progress.md"
DATE="$(date +%F)"

die() { echo "[FAIL] $*" >&2; exit 1; }

read_verdict() {
    local file="$1"
    [ -f "$file" ] || die "review 文件不存在: $file"
    local verdict
    verdict="$(grep -oE 'verdict:[[:space:]]*(PASS|FAIL)' "$file" | tail -1 | sed -E 's/.*verdict:[[:space:]]*//' || true)"
    [ -n "$verdict" ] || die "review verdict 不存在: $file"
    printf '%s\n' "$verdict"
}

require_pass() {
    local file="$1"
    local verdict
    verdict="$(read_verdict "$file")"
    [ "$verdict" = "PASS" ] || die "review 未 PASS: $file ($verdict)"
}

cd "$ROOT" || die "无法进入 repo root: $ROOT"

if [ -d "$TASK_DIR" ] && [ -e "$ARCHIVE_DIR" ]; then
    die "task 工作区和归档目录同时存在，拒绝覆盖: $TASK_DIR / $ARCHIVE_DIR"
elif [ -d "$TASK_DIR" ]; then
    ACTIVE_DIR="$TASK_DIR"
elif [ -d "$ARCHIVE_DIR" ]; then
    ACTIVE_DIR="$ARCHIVE_DIR"
else
    die "task 工作区不存在: $TASK_DIR"
fi

SPEC_FILE="$ACTIVE_DIR/spec.md"
[ -f "$SPEC_FILE" ] || die "spec.md 不存在: $SPEC_FILE"
grep -q "历史快照" "$SPEC_FILE" || die "spec.md 未盖戳: $SPEC_FILE"

require_pass "$ACTIVE_DIR/review_spec.md"
require_pass "$ACTIVE_DIR/review_code.md"
require_pass "$ACTIVE_DIR/review_test.md"

if [ "$ACTIVE_DIR" = "$TASK_DIR" ]; then
    mkdir -p "$(dirname "$ARCHIVE_DIR")" || die "创建归档父目录失败"
    git mv "$TASK_DIR" "$ARCHIVE_DIR" || die "归档 task 失败: $TID"
fi

mkdir -p "$(dirname "$PROGRESS_FILE")" || die "创建 progress 父目录失败"
touch "$PROGRESS_FILE" || die "创建 progress.md 失败"
if ! grep -qE "^- $TID[[:space:]]*\\|" "$PROGRESS_FILE"; then
    printf -- '- %s | %s | %s | 完成\n' "$TID" "$FEATURE" "$DATE" >> "$PROGRESS_FILE" || die "追加 progress.md 失败"
fi

bash "$ROOT/scripts/op_status.sh" "$TID" 完成 || die "更新状态失败: $TID → 完成"

git add \
    docs/omni_powers/op_execution/ \
    docs/omni_powers/op_record/ \
    docs/omni_powers/op_blueprint/ || die "git add 失败"

echo "[OK] close post: $TID"
