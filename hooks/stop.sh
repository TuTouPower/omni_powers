#!/usr/bin/env bash
# SubagentStop hook: implementer 交工门禁（拦 op-implementer 完成）
# - 检查 stop_hook_active 防递归
# - 验证 5 分钟内有新鲜测试证据
# 缺则拒收工
# 注：PreToolUse deny 对 subagent 失效（D18），但 SubagentStop 是事件门禁，可拦 subagent 完成

set -uo pipefail

input="$(cat)"
if [ "$(echo "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)" = "true" ]; then
  exit 0
fi

checkpoint="docs/omni_powers/op_execution/leader_checkpoint.md"
tid="$(awk -F': *' '/^current_task:/{print $2; exit}' "$checkpoint" 2>/dev/null | tr -d ' ')"

# 无活跃 task → 放行
[ -z "$tid" ] && exit 0

tasks_dir="docs/omni_powers/op_execution/tasks/$tid"

# 找 5 分钟内的证据
evidence="$(find "$tasks_dir" -name 'test_evidence_*.log' -mmin -5 2>/dev/null | head -1)"
if [ -z "$evidence" ]; then
  echo "[Hook] BLOCKED: $tid 无 5 分钟内新鲜测试证据。跑测试产出证据后再收工。" >&2
  exit 2
fi

exit 0
