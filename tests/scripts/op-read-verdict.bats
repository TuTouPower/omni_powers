#!/usr/bin/env bats

load helpers

@test "op-read-verdict: 无 review round 0 NONE" {
  setup_mock_project
  rm docs/omni_powers/op_execution/tasks/T01/review.md
  run "$OP_HOME/skills/oprun/scripts/op-read-verdict.sh" T01
  [ "$status" -eq 0 ]
  [[ "$output" == *"result: NONE"* ]]
  teardown_mock_project
}

@test "op-read-verdict: PASS exit 0" {
  setup_mock_project
  run "$OP_HOME/skills/oprun/scripts/op-read-verdict.sh" T01
  [ "$status" -eq 0 ]
  [[ "$output" == *"result: PASS"* ]]
  teardown_mock_project
}

@test "op-read-verdict: FAIL exit 1" {
  setup_mock_project
  printf "# review\\n\\nverdict: FAIL\\n" > docs/omni_powers/op_execution/tasks/T01/review.md
  run "$OP_HOME/skills/oprun/scripts/op-read-verdict.sh" T01
  [ "$status" -eq 1 ]
  [[ "$output" == *"result: FAIL"* ]]
  teardown_mock_project
}

@test "op-read-verdict: 重审追加——末行 verdict + round=2" {
  setup_mock_project
  printf "# review\\n\\nverdict: FAIL\\n\\nverdict: PASS\\n" > docs/omni_powers/op_execution/tasks/T01/review.md
  run "$OP_HOME/skills/oprun/scripts/op-read-verdict.sh" T01
  [ "$status" -eq 0 ]
  [[ "$output" == *"round: 2"* ]]
  [[ "$output" == *"result: PASS"* ]]
  teardown_mock_project
}
