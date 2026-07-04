#!/usr/bin/env bash
# SessionStart hook: 动态计算注入路由
# - 读 checkpoint + tasks_list.json + git 状态
# - 输出当前 spec/task/下一步（1-2K token）
# - approved spec 完整性校验（git diff --quiet 防"好心更新规格"漂移）

set -uo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

checkpoint="docs/omni_powers/op_execution/leader_checkpoint.md"
tasks="docs/omni_powers/op_execution/tasks_list.json"

echo "=== omni_powers session 路由 ==="

if [ -f "$checkpoint" ]; then
  echo "--- checkpoint ---"
  head -30 "$checkpoint"
fi

if [ -f "$tasks" ]; then
  echo "--- tasks 概览 ---"
  jq -r '.tasks[] | "\(.id) | \(.status) | \(.title)"' "$tasks" 2>/dev/null | head -20
  echo "--- 待开始（可跑）---"
  jq -r '.tasks[] | select(.status=="待开始") | "\(.id) depends_on=\(.depends_on//[]) \(.title)"' "$tasks" 2>/dev/null
fi

echo "--- git 状态 ---"
git status --short 2>/dev/null | head -10

# approved spec 完整性校验：approved 状态的 spec 文件不应有未 commit 改动
if [ -d "docs/omni_powers/op_blueprint/specs" ]; then
  for spec in docs/omni_powers/op_blueprint/specs/*.md; do
    [ -f "$spec" ] || continue
    status="$(awk -F': *' '/^status:/{print $2; exit}' "$spec" 2>/dev/null | tr -d ' ')"
    if [ "$status" = "approved" ] || [ "$status" = "in_progress" ]; then
      if ! git diff --quiet HEAD -- "$spec" 2>/dev/null; then
        echo "[Hook] WARN: $spec 状态=$status 但有未 commit 改动，疑似规格漂移。走变更子流程。" >&2
      fi
    fi
  done
fi

echo "=== 路由结束：读 RULES.md + 用 /opintake /oprun /opstatus ==="
exit 0
