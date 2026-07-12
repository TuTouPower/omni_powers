#!/usr/bin/env bats

# lite 冒烟：两版共用脚本（$OP_HOME/scripts/）在 lite 项目下工作
# 架构已合并——lite 不再有 skills/oplrun/scripts/ 副本，统一用 $OP_HOME/scripts/（CLAUDE.md / design §5.5）。
# lite「无 closing 态」是流程约定（oplrun SKILL §3.6 leader 收口无收口中态），非脚本层拦截——
# 共用 op_status.sh 支持 closing（heavy 需要），故不再断言 closing die。

load helpers

@test "lite op_jq: pending 查 ready（共用脚本寻址）" {
  setup_mock_project
  jq '.tasks[0].status="ready"' docs/omni_powers/op_execution/tasks_list.json > /tmp/t && mv /tmp/t docs/omni_powers/op_execution/tasks_list.json
  run bash "$OP_HOME/scripts/op_jq.sh" pending
  [ "$status" -eq 0 ]
  [[ "$output" == *"T01"* ]]
  teardown_mock_project
}

@test "lite op_status: 标 done（共用脚本，ASCII 状态）" {
  setup_mock_project
  run bash "$OP_HOME/scripts/op_status.sh" T01 done
  [ "$status" -eq 0 ]
  [[ "$(jq -r '.tasks[0].status' docs/omni_powers/op_execution/tasks_list.json)" == "done" ]]
  teardown_mock_project
}

@test "lite op_status: 非法状态 die（共用脚本枚举校验）" {
  setup_mock_project
  run bash "$OP_HOME/scripts/op_status.sh" T01 bogus_state
  [ "$status" -ne 0 ]
  [[ "$output" == *"无效 status"* ]]
  teardown_mock_project
}
