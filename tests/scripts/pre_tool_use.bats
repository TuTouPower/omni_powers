#!/usr/bin/env bats

load helpers

@test "pre_tool_use: --no-verify 拦截" {
  setup_mock_project
  run "$OP_HOME/hooks/pre_tool_use.sh" <<< '{"tool_name":"Bash","tool_input":{"command":"git commit --no-verify"}}'
  [ "$status" -eq 2 ]
  [[ "$output" == *"--no-verify"* ]]
  teardown_mock_project
}

@test "pre_tool_use: spec 写保护 approved 拦截" {
  setup_mock_project
  mkdir -p docs/omni_powers/op_blueprint/specs
  printf -- '---\nstatus: approved\n---\n# spec\n' > docs/omni_powers/op_blueprint/specs/feat.md
  json='{"tool_name":"Edit","tool_input":{"file_path":"'"$TEST_ROOT"'/docs/omni_powers/op_blueprint/specs/feat.md"}}'
  run "$OP_HOME/hooks/pre_tool_use.sh" <<< "$json"
  [ "$status" -eq 2 ]
  [[ "$output" == *"受写保护"* ]]
  teardown_mock_project
}

@test "pre_tool_use: e2e/ 拦截" {
  setup_mock_project
  run "$OP_HOME/hooks/pre_tool_use.sh" <<< '{"tool_name":"Write","tool_input":{"file_path":"'"$TEST_ROOT"'/e2e/test.spec.ts"}}'
  [ "$status" -eq 2 ]
  teardown_mock_project
}

@test "pre_tool_use: baselines 主会话写放行（agent_type 空，leader 自由）" {
  setup_mock_project
  mkdir -p docs/omni_powers/op_blueprint/baselines
  printf 'x' > docs/omni_powers/op_blueprint/baselines/snap.png
  run "$OP_HOME/hooks/pre_tool_use.sh" <<< '{"tool_name":"Edit","tool_input":{"file_path":"'"$TEST_ROOT"'/docs/omni_powers/op_blueprint/baselines/snap.png"}}'
  [ "$status" -eq 0 ]
  teardown_mock_project
}

@test "pre_tool_use: baselines subagent 写拦（agent_type 有）" {
  setup_mock_project
  mkdir -p docs/omni_powers/op_blueprint/baselines
  printf 'x' > docs/omni_powers/op_blueprint/baselines/snap.png
  run "$OP_HOME/hooks/pre_tool_use.sh" <<< '{"agent_type":"op-closer","tool_name":"Edit","tool_input":{"file_path":"'"$TEST_ROOT"'/docs/omni_powers/op_blueprint/baselines/snap.png"}}'
  [ "$status" -eq 2 ]
  teardown_mock_project
}
