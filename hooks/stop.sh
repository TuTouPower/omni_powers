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
  tid="$(awk '/^### current_task$/{f=1;next} /^### /{f=0} f&&NF{print;exit}' "$checkpoint" 2>/dev/null | tr -d ' ')"
  if [ -n "$tid" ]; then
    echo "[Hook Stop] WARN: current_task=$tid 非空——task 未收尾（归档/status done）。oprun 收尾或显式中断。" >&2
  fi
  exit 0
fi

checkpoint="docs/omni_powers/op_execution/leader_checkpoint.md"
tid="$(awk '/^### current_task$/{f=1;next} /^### /{f=0} f&&NF{print;exit}' "$checkpoint" 2>/dev/null | tr -d ' ')"

# 无活跃 task → WARN（不静默放行；current_task 应由 oprun 派 implementer 前写入）
if [ -z "$tid" ]; then
  echo "[Hook] WARN: current_task 为空，无法校验新鲜证据。oprun 派 implementer 前应写 current_task 到 leader_checkpoint.md。" >&2
  exit 0
fi

tasks_dir="docs/omni_powers/op_execution/tasks/$tid"

# ── 按 agent 类型分别校验（本轮改进：evaluator/closer 缺位补齐）──
case "$agent_type" in
  op-implementer)
    # P1-6：无测试框架项目（只有 NONE 标记）→ 放行
    [ -f "$tasks_dir/test_evidence_NONE.log" ] && exit 0
    # 找 5 分钟内的证据
    evidence="$(find "$tasks_dir" -name 'test_evidence_*.log' -not -name 'test_evidence_NONE.log' -mmin -5 2>/dev/null | head -1)"
    if [ -z "$evidence" ]; then
      echo "[Hook] BLOCKED: $tid 无 5 分钟内新鲜测试证据。跑测试产出证据后再收工。" >&2
      exit 2
    fi
    ;;
  op-evaluator)
    # evaluator 交工门禁：acceptance_report.md 必须存在且含 verdict:
    acc_report="docs/omni_powers/op_execution/acceptance/$tid/acceptance_report.md"
    if [ ! -f "$acc_report" ]; then
      echo "[Hook] BLOCKED: $tid evaluator 交工缺 acceptance_report.md。按 brief 执行验收并写报告。" >&2
      exit 2
    fi
    if ! grep -qE '^verdict:[[:space:]]*(PASS|FAIL)' "$acc_report" 2>/dev/null; then
      echo "[Hook] BLOCKED: $tid acceptance_report.md 缺 verdict: 末行。必写 verdict: PASS 或 FAIL。" >&2
      exit 2
    fi
    ;;
  op-closer)
    # closer 交工门禁：写入路径在白名单内（复用 op_closer_gate.sh 逻辑）
    op_closer_gate="$OP_HOME/scripts/op_closer_gate.sh"
    if [ -x "$op_closer_gate" ] || [ -f "$op_closer_gate" ]; then
      bash "$op_closer_gate" "$tid" || {
        echo "[Hook] BLOCKED: $tid closer 越界写入——白名单外路径。修正后重交。" >&2
        exit 2
      }
    fi
    ;;
  *)
    # reviewer / 未知 agent 不设 SubagentStop（reviewer 产出由 leader 落盘）
    ;;
esac

exit 0
