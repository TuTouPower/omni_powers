#!/usr/bin/env bash
# op_close_post（lite）：per-task 收口机械步骤（校验 review PASS + 归档 + progress + 标完成 + stage）
# 用法: op_close_post.sh <TID> <feature>（feature 由 leader 判断——lite 无 closer，leader 据 task 内容定；用于写 progress 给人看）
# lite 无「收口中」态、无 op_close_pre——review PASS 后直接 close_post。
# 无 OP_HOME 依赖：兄弟脚本 op_status.sh 走 ${BASH_SOURCE} 自探测同目录。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TID="${1:?用法: op_close_post.sh <TID> <feature>}"
FEATURE="${2:?缺少 feature}"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TASK_DIR="$ROOT/docs/omni_powers/op_execution/tasks/$TID"
ARCHIVE_DIR="$ROOT/docs/omni_powers/op_record/tasks/$TID"
PROGRESS_FILE="$ROOT/docs/omni_powers/op_record/progress.md"
DATE="$(date +%F)"

die() { echo "[FAIL] $*" >&2; exit 1; }

cd "$ROOT" || die "无法进入 repo root: $ROOT"

# 确定活跃目录（工作区优先，归档次之——幂等重跑）
if [ -d "$TASK_DIR" ] && [ -e "$ARCHIVE_DIR" ]; then
    die "task 工作区和归档目录同时存在，拒绝覆盖: $TASK_DIR / $ARCHIVE_DIR"
elif [ -d "$TASK_DIR" ]; then
    ACTIVE_DIR="$TASK_DIR"
elif [ -d "$ARCHIVE_DIR" ]; then
    ACTIVE_DIR="$ARCHIVE_DIR"
else
    die "task 工作区不存在: $TASK_DIR"
fi

# 校验二件齐全且非空
for f in report.md review.md; do
    [ -s "$ACTIVE_DIR/$f" ] || die "task 文件缺或空: $ACTIVE_DIR/$f"
done

# 校验 review.md verdict PASS（最后一行）
verdict="$(grep -oE '^verdict:[[:space:]]*(PASS|FAIL)' "$ACTIVE_DIR/review.md" | tail -1 | sed -E 's/.*verdict:[[:space:]]*//' || true)"
[ -n "$verdict" ] || die "review verdict 不存在: $ACTIVE_DIR/review.md"
[ "$verdict" = "PASS" ] || die "review 未 PASS: $ACTIVE_DIR/review.md ($verdict)"

# 归档（工作区 → 归档）
if [ "$ACTIVE_DIR" = "$TASK_DIR" ]; then
    mkdir -p "$(dirname "$ARCHIVE_DIR")" || die "创建归档父目录失败"
    git mv "$TASK_DIR" "$ARCHIVE_DIR" || die "归档 task 失败: $TID"
fi

# progress 追加一行（幂等）
mkdir -p "$(dirname "$PROGRESS_FILE")" || die "创建 progress 父目录失败"
touch "$PROGRESS_FILE" || die "创建 progress.md 失败"
if ! grep -qE "^- $TID[[:space:]]*\\|" "$PROGRESS_FILE"; then
    printf -- '- %s | %s | %s | 完成\n' "$TID" "$FEATURE" "$DATE" >> "$PROGRESS_FILE" || die "追加 progress.md 失败"
fi

bash "$SCRIPT_DIR/op_status.sh" "$TID" 完成 || die "更新状态失败: $TID → 完成"

# 清 current_task。用临时文件代 sed -i（BSD/GNU 通吃），失败 WARN 不静默
CHECKPOINT="$ROOT/docs/omni_powers/op_execution/leader_checkpoint.md"
if [ -f "$CHECKPOINT" ]; then
    tmp="$(mktemp)"
    if sed 's/^current_task:.*/current_task:/' "$CHECKPOINT" > "$tmp"; then
        mv "$tmp" "$CHECKPOINT"
    else
        rm -f "$tmp"
        echo "[WARN] 清 current_task 失败（不阻塞收口）: $CHECKPOINT" >&2
    fi
fi

# stage 边界收窄：只 add 本 task 归档 + progress + tasks_list
git add \
    "docs/omni_powers/op_record/tasks/$TID" \
    "docs/omni_powers/op_record/progress.md" \
    "docs/omni_powers/op_execution/tasks_list.json" || die "git add 失败"

echo "[OK] close post: $TID"
