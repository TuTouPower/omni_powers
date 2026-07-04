#!/usr/bin/env bats

load helpers

@test "op_status: 阻塞无 blocked_by die（P1-5）" {
  setup_mock_project
  run "$OP_HOME/scripts/op_status.sh" T01 阻塞
  [ "$status" -ne 0 ]
  [[ "$output" == *"必须提供 blocked_by"* ]]
  teardown_mock_project
}

@test "op_status: 阻塞带 blocked_by 成功" {
  setup_mock_project
  run "$OP_HOME/scripts/op_status.sh" T01 阻塞 resource
  [ "$status" -eq 0 ]
  [[ "$(jq -r '.tasks[0].status' docs/omni_powers/op_execution/tasks_list.json)" == "阻塞" ]]
  [[ "$(jq -r '.tasks[0].blocked_by' docs/omni_powers/op_execution/tasks_list.json)" == "resource" ]]
  teardown_mock_project
}

@test "op_status: 无效 blocked_by die" {
  setup_mock_project
  run "$OP_HOME/scripts/op_status.sh" T01 阻塞 invalid_reason
  [ "$status" -ne 0 ]
  [[ "$output" == *"无效 blocked_by"* ]]
  teardown_mock_project
}

@test "op_status: 无效 status die" {
  setup_mock_project
  run "$OP_HOME/scripts/op_status.sh" T01 无效状态
  [ "$status" -ne 0 ]
  [[ "$output" == *"无效 status"* ]]
  teardown_mock_project
}

@test "op_status: 完成 清 blocked_by" {
  setup_mock_project
  "$OP_HOME/scripts/op_status.sh" T01 阻塞 quality >/dev/null
  run "$OP_HOME/scripts/op_status.sh" T01 完成
  [ "$status" -eq 0 ]
  [[ "$(jq -r '.tasks[0].blocked_by' docs/omni_powers/op_execution/tasks_list.json)" == "null" ]]
  teardown_mock_project
}
