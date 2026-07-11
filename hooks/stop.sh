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

# 区分主会话 Stop（leader 收尾门禁，Q2）vs SubagentStop（implementer 交工，下文）
agent_type="$(echo "$input" | jq -r '.agent_type // empty' 2>/dev/null)"
if [ -z "$agent_type" ]; then
  # 主会话 Stop：current_task 非空 = task 未收尾，WARN（不 BLOCK，允许用户中断）
  checkpoint="docs/omni_powers/op_execution/leader_checkpoint.md"
  tid="$(awk -F': *' '/^### current_task:/{print $2; exit}' "$checkpoint" 2>/dev/null | tr -d ' ')"
  if [ -n "$tid" ]; then
    echo "[Hook Stop] WARN: current_task=$tid 非空——task 未收尾（归档/status done）。oprun 收尾或显式中断。" >&2
  fi
  exit 0
fi

checkpoint="docs/omni_powers/op_execution/leader_checkpoint.md"
tid="$(awk -F': *' '/^### current_task:/{print $2; exit}' "$checkpoint" 2>/dev/null | tr -d ' ')"

# 无活跃 task → WARN（不静默放行；current_task 应由 oprun 派 implementer 前写入）
if [ -z "$tid" ]; then
  echo "[Hook] WARN: current_task 为空，无法校验新鲜证据。oprun 派 implementer 前应写 current_task 到 leader_checkpoint.md。" >&2
  exit 0
fi

tasks_dir="docs/omni_powers/op_execution/tasks/$tid"

# P1-6：无测试框架项目（只有 NONE 标记）→ 放行
[ -f "$tasks_dir/test_evidence_NONE.log" ] && exit 0
# 找 5 分钟内的证据
evidence="$(find "$tasks_dir" -name 'test_evidence_*.log' -not -name 'test_evidence_NONE.log' -mmin -5 2>/dev/null | head -1)"
if [ -z "$evidence" ]; then
  echo "[Hook] BLOCKED: $tid 无 5 分钟内新鲜测试证据。跑测试产出证据后再收工。" >&2
  exit 2
fi

exit 0
