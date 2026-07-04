#!/usr/bin/env bash
# op_assemble_eval_brief：机械组装 evaluator brief（leader 不参与内容，防主会话污染）
# 用法: op_assemble_eval_brief.sh <前缀>
# 产出: docs/omni_powers/op_execution/acceptance/{前缀}/eval_brief.md
# 内容源（固定路径 cat，per-task 不写 op_blueprint 故生效规格天然是开工前基线）:
#   - 工作 spec: op_execution/specs/{前缀}.md（AC/INV/边界/可测性契约）
#   - 生效规格: op_blueprint/specs/{feature}.md（经 spec_index 索引）
#   - baselines 索引: op_blueprint/baselines/baselines_index.md（首次为空）
# 不含: implementer 的 report/diff/review、src/**、tasks/**（evaluator worktree 不挂载）
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
PREFIX="${1:?用法: op_assemble_eval_brief.sh <前缀>}"
ACCEPT_DIR="$ROOT/docs/omni_powers/op_execution/acceptance/$PREFIX"
WORK_SPEC="$ROOT/docs/omni_powers/op_execution/specs/$PREFIX.md"
BLUEPRINT_DIR="$ROOT/docs/omni_powers/op_blueprint"

die() { echo "[FAIL] $*" >&2; exit 1; }

[ -f "$WORK_SPEC" ] || die "工作 spec 不存在: $WORK_SPEC"
mkdir -p "$ACCEPT_DIR"

BRIEF="$ACCEPT_DIR/eval_brief.md"

{
  echo "# Evaluator Brief: $PREFIX"
  echo
  echo "> 机械组装（op_assemble_eval_brief.sh），leader 不参与内容，主会话污染传不过来。"
  echo "> 你只读本文件 + 启动应用。src/**、tasks/** 不在你的 worktree（结构隔离）。"
  echo

  echo "## 工作 spec（AC/INV/边界/可测性契约/预期失败模式）"
  echo
  cat "$WORK_SPEC"
  echo

  echo "## 生效规格（开工前基线）"
  echo
  if [ -f "$BLUEPRINT_DIR/spec_index.md" ]; then
    echo "（spec_index.md 索引；按前缀定位对应 specs/{feature}.md）"
    cat "$BLUEPRINT_DIR/spec_index.md"
  else
    echo "（spec_index.md 缺失，无历史生效规格——首次验收）"
  fi
  echo

  echo "## baselines 索引（重验对照；首次为空）"
  echo
  if [ -f "$BLUEPRINT_DIR/baselines/baselines_index.md" ]; then
    cat "$BLUEPRINT_DIR/baselines/baselines_index.md"
  else
    echo "（首次验收，无 baselines——裸评建基准）"
  fi
  echo

  echo "## 应用启动方式"
  echo
  echo "从上方工作 spec 的「可测性契约」段提取。"
  echo

} > "$BRIEF"

echo "[OK] evaluator brief 组装完成: $BRIEF"
echo "[下一步] evaluator 只读 \$BRIEF + 启动应用，按 brief 内 AC/可测性契约执行验收"
