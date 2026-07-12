#!/usr/bin/env bash
# op_close_post：per-task 收口后机械步骤（校验 review.md PASS + 归档 + 记录 + stage）
# 用法: op_close_post.sh <TID> <feature>（feature 由 leader 从 closer 提案读，非 spec 字段；用于写 progress 给人看）
# review.md 单文件；closer per-task 一段式已在验收后产 blueprint_update（见 design §2.4）
set -euo pipefail

OP_HOME_DIR="${OP_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
TID="${1:?用法: op_close_post.sh <TID> <feature>}"
FEATURE="${2:?缺少 feature}"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TASK_DIR="$ROOT/docs/omni_powers/op_execution/tasks/$TID"
ARCHIVE_DIR="$ROOT/docs/omni_powers/op_record/tasks/$TID"
PROGRESS_FILE="$ROOT/docs/omni_powers/op_record/progress.md"
DATE="$(TZ='Asia/Shanghai' date +'%F %T UTC+8')"

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

# 校验 acceptance_report.md verdict PASS（D6 验收前置，design §2.5）——非行为型 task（eval:skip）豁免
# 文件名契约与 op-evaluator.md 输出段一致（acceptance_report.md，非 eval.md）
EVAL_SKIP="$(jq -r --arg tid "$TID" '.tasks[] | select(.id==$tid) | .eval // "required"' "$ROOT/docs/omni_powers/op_execution/tasks_list.json" 2>/dev/null || echo required)"
if [ "$EVAL_SKIP" != "skip" ]; then
    EVAL_MD="$ROOT/docs/omni_powers/op_execution/acceptance/$TID/acceptance_report.md"
    [ -s "$EVAL_MD" ] || die "acceptance_report.md 缺或空: $EVAL_MD（D6：验收 PASS 才收口）"
    eval_verdict="$(grep -oE '^verdict:[[:space:]]*(PASS|FAIL)' "$EVAL_MD" | tail -1 | sed -E 's/.*verdict:[[:space:]]*//' || true)"
    [ -n "$eval_verdict" ] || die "acceptance_report.md 缺 verdict 末行: $EVAL_MD（evaluator 必写 verdict: PASS|FAIL）"
    [ "$eval_verdict" = "PASS" ] || die "eval 未 PASS: $EVAL_MD ($eval_verdict)（D6：验收 PASS 才收口，FAIL 须回流 implementer 重验）"
fi

# 归档（工作区 → 归档）：task 目录 + spec 原文 + acceptance（design §1.2 三态——活区清理）
if [ "$ACTIVE_DIR" = "$TASK_DIR" ]; then
    mkdir -p "$(dirname "$ARCHIVE_DIR")" "$ROOT/docs/omni_powers/op_record/specs" "$ROOT/docs/omni_powers/op_record/acceptance" || die "创建归档父目录失败"
    git mv "$TASK_DIR" "$ARCHIVE_DIR" || die "归档 task 失败: $TID"
    # spec 原文
    SPEC_SRC="$(ls "$ROOT"/docs/omni_powers/op_execution/specs/${TID}_*.md 2>/dev/null | head -1)"
    if [ -n "$SPEC_SRC" ] && [ ! -e "$ROOT/docs/omni_powers/op_record/specs/$(basename "$SPEC_SRC")" ]; then
        git mv "$SPEC_SRC" "$ROOT/docs/omni_powers/op_record/specs/" || die "归档 spec 失败: $TID"
    fi
    # acceptance 工作区
    ACCEPT_SRC="$ROOT/docs/omni_powers/op_execution/acceptance/$TID"
    ACCEPT_DST="$ROOT/docs/omni_powers/op_record/acceptance/$TID"
    if [ -d "$ACCEPT_SRC" ] && [ ! -e "$ACCEPT_DST" ]; then
        git mv "$ACCEPT_SRC" "$ACCEPT_DST" || die "归档 acceptance 失败: $TID"
    fi
fi

# progress 追加一行（幂等）
mkdir -p "$(dirname "$PROGRESS_FILE")" || die "创建 progress 父目录失败"
touch "$PROGRESS_FILE" || die "创建 progress.md 失败"
if ! grep -qE "^- $TID[[:space:]]*\\|" "$PROGRESS_FILE"; then
    printf -- '- %s | %s | %s | 完成\n' "$TID" "$FEATURE" "$DATE" >> "$PROGRESS_FILE" || die "追加 progress.md 失败"
fi

bash "$OP_HOME_DIR/scripts/op_status.sh" "$TID" done || die "更新状态失败: $TID → done"

# P0-4：收口完成，清 current_task + 写 last_completed + 刷 next_step（hook 不再校验本 task 证据）
# checkpoint 更新并入脚本，不靠 leader 手动（防过期，本轮改进）
# 段格式见 docs_template/.../leader_checkpoint.md（### 标题 + 正文），非 current_task: 冒号简写
# 用临时文件代 sed -i（BSD/GNU 通吃），失败 WARN 不静默
CHECKPOINT="$ROOT/docs/omni_powers/op_execution/leader_checkpoint.md"
if [ -f "$CHECKPOINT" ]; then
    tmp="$(mktemp)"
    # 清 current_task 段正文 + last_completed 段刷成本 TID + next_step 提示回 3.1 选下一 task
    if awk -v tid="$TID" '
        /^### current_task$/{print;print "";f="skip";next}
        /^### last_completed$/{print;print "";print tid;f="skip";next}
        /^### next_step$/{print;print "";print "回 /oprun 3.1 选下一 task（或全完成进收尾）";f="skip";next}
        /^### /{f="";print;next}
        /^## /{f="";print;next}
        {if(f=="")print}
    ' "$CHECKPOINT" > "$tmp"; then
        mv "$tmp" "$CHECKPOINT"
    else
        rm -f "$tmp"
        echo "[WARN] 更新 checkpoint 失败（不阻塞收口）: $CHECKPOINT" >&2
    fi
fi

# stage 边界收窄（#25）：只 add 本 task 归档 + progress + tasks_list，不 blanket add op_blueprint/op_execution
git add \
    "docs/omni_powers/op_record/tasks/$TID" \
    "docs/omni_powers/op_record/progress.md" \
    "docs/omni_powers/op_execution/tasks_list.json" || die "git add 失败"

echo "[OK] close post: $TID"
