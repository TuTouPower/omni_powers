#!/usr/bin/env bats

load helpers

@test "op_status: blocked 无 blocked_by die（P1-5）" {
  setup_mock_project
  run "$OP_HOME/scripts/op_status.sh" T01 blocked
  [ "$status" -ne 0 ]
  [[ "$output" == *"必须提供 blocked_by"* ]]
  teardown_mock_project
}

@test "op_status: blocked 带 blocked_by 成功" {
  setup_mock_project
  run "$OP_HOME/scripts/op_status.sh" T01 blocked resource
  [ "$status" -eq 0 ]
  [[ "$(jq -r '.tasks[0].status' docs/omni_powers/op_execution/tasks_list.json)" == "blocked" ]]
  [[ "$(jq -r '.tasks[0].blocked_by' docs/omni_powers/op_execution/tasks_list.json)" == "resource" ]]
  teardown_mock_project
}

@test "op_status: 无效 blocked_by die" {
  setup_mock_project
  run "$OP_HOME/scripts/op_status.sh" T01 blocked invalid_reason
  [ "$status" -ne 0 ]
  [[ "$output" == *"无效 blocked_by"* ]]
  teardown_mock_project
}

@test "op_status: 无效 status die" {
  setup_mock_project
  run "$OP_HOME/scripts/op_status.sh" T01 invalid_status
  [ "$status" -ne 0 ]
  [[ "$output" == *"无效 status"* ]]
  teardown_mock_project
}

@test "op_status: done 清 blocked_by" {
  setup_mock_project
  "$OP_HOME/scripts/op_status.sh" T01 blocked quality >/dev/null
  run "$OP_HOME/scripts/op_status.sh" T01 done
  [ "$status" -eq 0 ]
  [[ "$(jq -r '.tasks[0].blocked_by' docs/omni_powers/op_execution/tasks_list.json)" == "null" ]]
  teardown_mock_project
}
