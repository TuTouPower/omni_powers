#!/usr/bin/env bats

# H6: lite 副本脚本（oplrun/scripts/）冒烟——确认副本存在 + ASCII 状态机工作
# lite 副本逻辑同 heavy（除无 closing 态），heavy 测试覆盖逻辑，此处只冒烟 lite 副本寻址 + ASCII

load helpers

@test "lite op_jq: pending 查 ready（ASCII，lite 副本寻址）" {
  setup_mock_project
  jq '.tasks[0].status="ready"' docs/omni_powers/op_execution/tasks_list.json > /tmp/t && mv /tmp/t docs/omni_powers/op_execution/tasks_list.json
  run bash "$OP_HOME/skills/oplrun/scripts/op_jq.sh" pending
  [ "$status" -eq 0 ]
  [[ "$output" == *"T01"* ]]
  teardown_mock_project
}

@test "lite op_status: 标 done（ASCII，lite 副本无 closing）" {
  setup_mock_project
  run bash "$OP_HOME/skills/oplrun/scripts/op_status.sh" T01 done
  [ "$status" -eq 0 ]
  [[ "$(jq -r '.tasks[0].status' docs/omni_powers/op_execution/tasks_list.json)" == "done" ]]
  teardown_mock_project
}

@test "lite op_status: closing die（lite 无 closing 态）" {
  setup_mock_project
  run bash "$OP_HOME/skills/oplrun/scripts/op_status.sh" T01 closing
  [ "$status" -ne 0 ]
  [[ "$output" == *"lite 无 closing"* ]]
  teardown_mock_project
}
