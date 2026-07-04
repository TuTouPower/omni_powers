#!/usr/bin/env bats

load helpers

@test "close_check: T01 归档+checkpoint 后通过" {
  setup_mock_project
  "$OP_HOME/scripts/op_close_post.sh" T01 myfeature >/dev/null
  "$OP_HOME/skills/oprun/scripts/op-checkpoint.sh" T01 >/dev/null
  run "$OP_HOME/skills/oprun/scripts/close_check.sh" T01
  [ "$status" -eq 0 ]
  teardown_mock_project
}

@test "close_check: 未归档的 task 不通过" {
  setup_mock_project
  run "$OP_HOME/skills/oprun/scripts/close_check.sh" T01
  [ "$status" -ne 0 ]
  teardown_mock_project
}
