#!/usr/bin/env bats

load helpers

@test "op_close_post: blueprint 有实质提案但未合入 die（T0003 B2）" {
  setup_mock_project
  printf "# blueprint update\n\n### 新增\n\n- 新增约束\n" > docs/omni_powers/op_execution/acceptance/T01/blueprint_update.md
  run "$OP_HOME/scripts/op_close_post.sh" T01 myfeature
  [ "$status" -ne 0 ]
  [[ "$output" == *"blueprint 提案未合入，先执行 3.8 leader 自审写入"* ]]
  [ -d "docs/omni_powers/op_execution/tasks/T01" ]
  teardown_mock_project
}

@test "op_close_post: open issue 未 triage die（T0003 B3）" {
  setup_mock_project
  cat > docs/omni_powers/op_execution/issues/issue_t01_bug.md <<'EOF'
---
id: I-20260713-01
spec: T01
status: open
---
EOF
  git add docs/omni_powers/op_execution/issues/issue_t01_bug.md
  run "$OP_HOME/scripts/op_close_post.sh" T01 myfeature
  [ "$status" -ne 0 ]
  [[ "$output" == *"先跑 /optriage 分级（分级后在 issue frontmatter 加 triaged: P0-P3|closed）"* ]]
  [ -d "docs/omni_powers/op_execution/tasks/T01" ]
  teardown_mock_project
}

@test "op_close_post: required eval 无跟踪 E2E die（T0003 B5）" {
  setup_mock_project
  printf '%s\n' '{"tasks":[{"id":"T01","title":"test task","status":"closing","spec":"specs/T01_x.md","depends_on":null,"workset":["src/x.ts"],"eval":"required"}]}' > docs/omni_powers/op_execution/tasks_list.json
  printf "# acceptance\n\nverdict: PASS\n" > docs/omni_powers/op_execution/acceptance/T01/acceptance_report.md
  git rm -q e2e/T01/.keep
  run "$OP_HOME/scripts/op_close_post.sh" T01 myfeature
  [ "$status" -ne 0 ]
  [[ "$output" == *"E2E 未固化入库（evaluator 固化产物须落主仓库 e2e/T01/）"* ]]
  [ -d "docs/omni_powers/op_execution/tasks/T01" ]
  teardown_mock_project
}

@test "op_close_post: E2E waiver WARN 后放行（T0003 B5）" {
  setup_mock_project
  printf '%s\n' '{"tasks":[{"id":"T01","title":"test task","status":"closing","spec":"specs/T01_x.md","depends_on":null,"workset":["src/x.ts"],"eval":"required"}]}' > docs/omni_powers/op_execution/tasks_list.json
  printf "# acceptance\n\nverdict: PASS\n" > docs/omni_powers/op_execution/acceptance/T01/acceptance_report.md
  git rm -q e2e/T01/.keep
  OP_E2E_WAIVER=1 run "$OP_HOME/scripts/op_close_post.sh" T01 myfeature
  [ "$status" -eq 0 ]
  [[ "$output" == *"[WARN] OP_E2E_WAIVER=1"* ]]
  [ -d "docs/omni_powers/op_record/tasks/T01" ]
  teardown_mock_project
}

@test "op_close_post: 缺 feature 参数 die（P0-1）" {
  setup_mock_project
  run "$OP_HOME/scripts/op_close_post.sh" T01
  [ "$status" -eq 1 ]
  [[ "$output" == *"缺少 feature"* ]]
  teardown_mock_project
}

@test "op_close_post: verdict PASS 归档 + 清 current_task（P0-4）" {
  setup_mock_project
  run "$OP_HOME/scripts/op_close_post.sh" T01 myfeature
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
  run "$OP_HOME/scripts/op_close_post.sh" T01 myfeature
  [ "$status" -ne 0 ]
  [[ "$output" == *"未 PASS"* ]]
  [ -d "docs/omni_powers/op_execution/tasks/T01" ]
  teardown_mock_project
}

@test "op_close_post: review 缺 verdict die" {
  setup_mock_project
  printf "# review\\n\\n无 verdict 行\\n" > docs/omni_powers/op_execution/tasks/T01/review.md
  run "$OP_HOME/scripts/op_close_post.sh" T01 myfeature
  [ "$status" -ne 0 ]
  [[ "$output" == *"verdict 不存在"* ]]
  teardown_mock_project
}
