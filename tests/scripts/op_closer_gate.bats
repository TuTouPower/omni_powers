#!/usr/bin/env bats

# Q9: op_closer_gate 回归测试（D3 已落地 + Q5 只报不撤销）

load helpers

@test "op_closer_gate: 白名单内（decisions/issues/acceptance）→ exit 0" {
  setup_mock_project
  mkdir -p docs/omni_powers/op_record docs/omni_powers/op_execution/acceptance/T01 docs/omni_powers/op_execution/issues
  echo "decision" > docs/omni_powers/op_record/decisions.md
  echo "issue" > docs/omni_powers/op_execution/issues/I-test.md
  echo "proposal" > docs/omni_powers/op_execution/acceptance/T01/blueprint_update.md
  git add -A
  run "$OP_HOME/scripts/op_closer_gate.sh" T01
  [ "$status" -eq 0 ]
  teardown_mock_project
}

@test "op_closer_gate: 越界（src/）→ exit 1 + 报告，不撤销（Q5）" {
  setup_mock_project
  mkdir -p src
  echo "leak" > src/leak.ts
  git add -A
  run "$OP_HOME/scripts/op_closer_gate.sh" T01
  [ "$status" -eq 1 ]
  [[ "$output" == *"越界"* ]]
  [[ "$output" == *"src/leak.ts"* ]]
  # Q5：只报不撤销——文件保留，交 leader 决策
  [ -f src/leak.ts ]
  teardown_mock_project
}
