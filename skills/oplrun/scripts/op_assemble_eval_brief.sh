#!/usr/bin/env bash
# op_assemble_eval_brief（lite）：组装 evaluator brief（裸评版）。
# 用法: op_assemble_eval_brief.sh <TID>
# 产出: docs/omni_powers/op_execution/acceptance/{TID}/eval_brief.md
# lite 差异（§5.7 裸评退化）：只 cat 工作 spec + AC + 启动方式，跳过生效规格/baselines 段。
#   无 op_blueprint 真相源、无 baselines——首次裸评，无对照基准。
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TID="${1:?用法: op_assemble_eval_brief.sh <TID>}"
ACCEPT_DIR="$ROOT/docs/omni_powers/op_execution/acceptance/$TID"

die() { echo "[FAIL] $*" >&2; exit 1; }

# spec 文件名 {TID}_{slug}.md，glob 取唯一匹配
WORK_SPEC=$(ls "$ROOT"/docs/omni_powers/op_execution/specs/${TID}_*.md 2>/dev/null | head -1 || true)
[ -n "$WORK_SPEC" ] || die "工作 spec 不存在: specs/${TID}_*.md"
mkdir -p "$ACCEPT_DIR"

BRIEF="$ACCEPT_DIR/eval_brief.md"

{
  echo "# Evaluator Brief (lite 裸评): $TID"
  echo
  echo "> 机械组装（op_assemble_eval_brief.sh lite 版），leader 不参与内容。"
  echo "> **lite 裸评退化**：无 worktree 隔离、无生效规格基线、无 baselines 对照。"
  echo "> 只做首次裸评——逐 AC 评估 + 跑/写 E2E + 破坏检查 + 对抗探索。"
  echo "> **失能声明**：无法防\"抄实现\"（你能读到 src/），无 baseline 回归检测。"
  echo

  echo "## 工作 spec（AC/INV/边界/可测性契约/预期失败模式）"
  echo
  cat "$WORK_SPEC"
  echo

  echo "## 应用启动方式"
  echo
  echo "从上方工作 spec 的「可测性契约」段提取。"
  echo

  echo "## 执行后端"
  echo
  echo "- CDP 优先：Playwright（Electron 用 _electron.launch；扩展 launchPersistentContext + --load-extension）"
  echo "- 直驱：Bash/HTTP/SQL（CLI/DB/API/进程类 AC）"
  echo "- 无对应通道能力时判 INSUFFICIENT_EVIDENCE 并写明，禁止降级推断"
  echo

} > "$BRIEF"

echo "[OK] lite evaluator brief 组装完成: $BRIEF"
echo "[下一步] evaluator 只读 \$BRIEF + 启动应用，按 AC 裸评"
