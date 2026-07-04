#!/usr/bin/env bats

OP_HOME="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

@test "op_check_env: 环境就绪通过" {
  run bash "$OP_HOME/scripts/op_check_env.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"环境检查通过"* ]]
}

@test "op_check_env: OP_HOME 未设 die" {
  OP_HOME="" run bash "$OP_HOME/scripts/op_check_env.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"OP_HOME 未设"* ]]
}

@test "op_check_env: OP_HOME 指向错 die" {
  OP_HOME="/nonexistent" run bash "$OP_HOME/scripts/op_check_env.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"目录不存在"* ]]
}
