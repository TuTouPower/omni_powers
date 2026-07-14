#!/usr/bin/env bash
# SubagentStop hook: implementer 交工门禁（拦 op-implementer 完成）
# - 检查 stop_hook_active 防递归
# - 验证 5 分钟内有新鲜测试证据
# 缺则拒收工
# 注：PreToolUse deny 对 subagent 失效（D18），但 SubagentStop 是事件门禁，可拦 subagent 完成

set -uo pipefail

project_root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
op_paths_script="${OP_HOME:-}/scripts/op_paths.sh"
if [ -f "$op_paths_script" ]; then
  source "$op_paths_script"
  if ! op_load_paths "" "$project_root"; then
    echo "[Hook] BLOCKED: OP_DOCS_DIR 配置无效，保护性拒绝" >&2
    exit 2
  fi
else
  echo "[Hook] BLOCKED: $op_paths_script 缺失，无法解析 OP_DOCS_DIR" >&2
  exit 2
fi

input="$(cat)"
if [ "$(echo "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)" = "true" ]; then
  exit 0
fi

# 区分主会话 Stop（leader 收尾门禁，Q2）vs SubagentStop（implementer 交工，下文）
agent_type="$(echo "$input" | jq -r '.agent_type // empty' 2>/dev/null)"
if [ -z "$agent_type" ]; then
  # 主会话 Stop：current_task 非空 = task 未收尾，WARN（不 BLOCK，允许用户中断）
  checkpoint="$OP_DOCS_ROOT/op_execution/leader_checkpoint.md"
  tid="$(awk '/^### current_task$/{f=1;next} /^### /{f=0} f&&NF{print;exit}' "$checkpoint" 2>/dev/null | tr -d ' ')"
  if [ -n "$tid" ]; then
    echo "[Hook Stop] WARN: current_task=$tid 非空——task 未收尾（归档/status done）。oprun 收尾或显式中断。" >&2
  fi
  exit 0
fi

checkpoint="$OP_DOCS_ROOT/op_execution/leader_checkpoint.md"
tid="$(awk '/^### current_task$/{f=1;next} /^### /{f=0} f&&NF{print;exit}' "$checkpoint" 2>/dev/null | tr -d ' ')"

# 无活跃 task → WARN（不静默放行；current_task 应由 oprun 派 implementer 前写入）
if [ -z "$tid" ]; then
  echo "[Hook] WARN: current_task 为空，无法校验新鲜证据。oprun 派 implementer 前应写 current_task 到 leader_checkpoint.md。" >&2
  exit 0
fi

tasks_dir="$OP_DOCS_ROOT/op_execution/tasks/$tid"

# ── 按 agent 类型分别校验 ──
# D29：派发常用 general-purpose + 模板注入；agent_type 可能是 general-purpose。
# general-purpose：任一门禁通过即放行（implementer 证据 / evaluator verdict / closer gate）。
check_implementer_evidence() {
  [ -f "$tasks_dir/test_evidence_NONE.log" ] && return 0
  evidence="$(find "$tasks_dir" -name 'test_evidence_*.log' -not -name 'test_evidence_NONE.log' -mmin -5 2>/dev/null | head -1)"
  [ -n "$evidence" ]
}
check_evaluator_report() {
  local acc_report="$OP_DOCS_ROOT/op_execution/acceptance/$tid/acceptance_report.md"
  [ -f "$acc_report" ] || return 1
  grep -qE '^verdict:[[:space:]]*(PASS|FAIL)' "$acc_report" 2>/dev/null
}
check_closer_gate() {
  local op_closer_gate="$OP_HOME/scripts/op_closer_gate.sh"
  [ -f "$op_closer_gate" ] || return 1
  bash "$op_closer_gate" "$tid" >/dev/null 2>&1
}

case "$agent_type" in
  op-implementer)
    if ! check_implementer_evidence; then
      echo "[Hook] BLOCKED: $tid 无 5 分钟内新鲜测试证据。跑测试产出证据后再收工。" >&2
      exit 2
    fi
    ;;
  op-evaluator)
    if ! check_evaluator_report; then
      echo "[Hook] BLOCKED: $tid evaluator 交工缺 acceptance_report.md 或 verdict 行。" >&2
      exit 2
    fi
    ;;
  op-closer)
    if ! check_closer_gate; then
      echo "[Hook] BLOCKED: $tid closer 越界写入或 gate 失败。修正后重交。" >&2
      exit 2
    fi
    ;;
  general-purpose|general_purpose)
    if check_implementer_evidence || check_evaluator_report || check_closer_gate; then
      exit 0
    fi
    echo "[Hook] BLOCKED: $tid general-purpose 交工缺 implementer 证据 / evaluator verdict / closer 合法写入。" >&2
    exit 2
    ;;
  *)
    # reviewer / 未知 agent 不设硬门禁（reviewer 产出由 leader 落盘）
    ;;
esac

exit 0
