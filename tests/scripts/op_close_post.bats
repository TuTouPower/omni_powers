#!/usr/bin/env bats

load helpers

@test "op_close_post: 缺 feature 参数 die（P0-1）" {
  setup_mock_project
  run "$OP_HOME/skills/oprun/scripts/op_close_post.sh" T01
  [ "$status" -eq 1 ]
  [[ "$output" == *"缺少 feature"* ]]
  teardown_mock_project
}

@test "op_close_post: verdict PASS 归档 + 清 current_task（P0-4）" {
  setup_mock_project
  run "$OP_HOME/skills/oprun/scripts/op_close_post.sh" T01 myfeature
  [ "$status" -eq 0 ]
  [ -d "docs/omni_powers/op_record/tasks/T01" ]
  [ ! -d "docs/omni_powers/op_execution/tasks/T01" ]
  # current_task 段正文清空（### 段格式）：提取 current_task 标题下正文，应无 T01
  cur="$(awk '/^### current_task$/{f=1;next} /^### /{f=0} /^## /{f=0} f && NF{print}' docs/omni_powers/op_execution/leader_checkpoint.md)"
  [ -z "$cur" ]
  # last_completed 段刷成 T01（收口脚本并入 checkpoint 更新）
  last="$(awk '/^### last_completed$/{f=1;next} /^### /{f=0} /^## /{f=0} f && NF{print}' docs/omni_powers/op_execution/leader_checkpoint.md)"
  [ "$last" = "T01" ]
  teardown_mock_project
}

@test "op_close_post: verdict FAIL 不归档" {
  setup_mock_project
  printf "# review\\n\\nverdict: FAIL\\n" > docs/omni_powers/op_execution/tasks/T01/review.md
  run "$OP_HOME/skills/oprun/scripts/op_close_post.sh" T01 myfeature
  [ "$status" -ne 0 ]
  [[ "$output" == *"未 PASS"* ]]
  [ -d "docs/omni_powers/op_execution/tasks/T01" ]
  teardown_mock_project
}

@test "op_close_post: review 缺 verdict die" {
  setup_mock_project
  printf "# review\\n\\n无 verdict 行\\n" > docs/omni_powers/op_execution/tasks/T01/review.md
  run "$OP_HOME/skills/oprun/scripts/op_close_post.sh" T01 myfeature
  [ "$status" -ne 0 ]
  [[ "$output" == *"verdict 不存在"* ]]
  teardown_mock_project
}
