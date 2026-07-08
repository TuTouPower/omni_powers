#!/usr/bin/env bats

# H7/Q2: stop.sh hook——SubagentStop（implementer 交工证据门禁）+ Stop（主会话收尾 WARN）

REPO="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
STOP="$REPO/hooks/stop.sh"

setup() {
  TEST_ROOT="$(mktemp -d)"
  cd "$TEST_ROOT"
  git init -q
  git config user.email t@t
  git config user.name t
  mkdir -p docs/omni_powers/op_execution/tasks/T01
  printf 'current_task: T01\n' > docs/omni_powers/op_execution/leader_checkpoint.md
}

teardown() {
  [ -n "${TEST_ROOT:-}" ] && rm -rf "$TEST_ROOT"
}

@test "SubagentStop: 无新鲜证据 → exit 2（拦 implementer 交工）" {
  echo '{"agent_type":"op-implementer","stop_hook_active":false}' | run bash "$STOP"
  [ "$status" -eq 2 ]
  [[ "$output" == *"新鲜测试证据"* ]]
}

@test "SubagentStop: 有新鲜证据 → exit 0" {
  printf 'evidence\n' > "docs/omni_powers/op_execution/tasks/T01/test_evidence_$(date +%s).log"
  echo '{"agent_type":"op-implementer","stop_hook_active":false}' | run bash "$STOP"
  [ "$status" -eq 0 ]
}

@test "SubagentStop: NONE 标记（无测试框架）→ 放行" {
  printf 'none\n' > docs/omni_powers/op_execution/tasks/T01/test_evidence_NONE.log
  echo '{"agent_type":"op-implementer","stop_hook_active":false}' | run bash "$STOP"
  [ "$status" -eq 0 ]
}

@test "Stop 主会话: current_task 非空 → WARN exit 0（Q2，不 BLOCK 允许中断）" {
  echo '{"stop_hook_active":false}' | run bash "$STOP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARN"*"current_task=T01"* ]]
}

@test "Stop 主会话: current_task 空 → 静默 exit 0" {
  printf 'current_task:\n' > docs/omni_powers/op_execution/leader_checkpoint.md
  echo '{"stop_hook_active":false}' | run bash "$STOP"
  [ "$status" -eq 0 ]
}
