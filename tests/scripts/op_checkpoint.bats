#!/usr/bin/env bats

load helpers

@test "op_checkpoint: 追加已完成 task（首次）" {
  setup_mock_project
  run "$OP_HOME/skills/oprun/scripts/op_checkpoint.sh" T01
  [ "$status" -eq 0 ]
  grep -qE '^- T01 "test task" ✅ ' docs/omni_powers/op_execution/leader_checkpoint.md
  teardown_mock_project
}

@test "op_checkpoint: 幂等——重跑不重复（P1-7）" {
  setup_mock_project
  "$OP_HOME/skills/oprun/scripts/op_checkpoint.sh" T01 >/dev/null
  run "$OP_HOME/skills/oprun/scripts/op_checkpoint.sh" T01
  [ "$status" -eq 0 ]
  count=$(grep -cE '^- T01 ' docs/omni_powers/op_execution/leader_checkpoint.md)
  [ "$count" -eq 1 ]
  teardown_mock_project
}

@test "op_checkpoint: TID 锚定——T01 不误配 T010" {
  setup_mock_project
  jq '.tasks += [{"id":"T010","title":"other","status":"完成","spec":"b01","type":"实现","covers_ac":[],"touches_inv":[],"depends_on":null,"risk_probe":false,"workset":[]}]' docs/omni_powers/op_execution/tasks_list.json > /tmp/tasks.json && mv /tmp/tasks.json docs/omni_powers/op_execution/tasks_list.json
  run "$OP_HOME/skills/oprun/scripts/op_checkpoint.sh" T01
  [ "$status" -eq 0 ]
  count=$(grep -cE '^- T01 ' docs/omni_powers/op_execution/leader_checkpoint.md)
  [ "$count" -eq 1 ]
  teardown_mock_project
}
