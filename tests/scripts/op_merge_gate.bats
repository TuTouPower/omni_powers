#!/usr/bin/env bats

# op_merge_gate 回归测试（写入硬底线 §3.4——白名单机械校验）
# 覆盖：合法改动 PASS / 受保护路径 REJECT / 工作集越界 REJECT / review 未 PASS REJECT

load helpers

# 在 mock 项目基础上建 task 分支并改文件；$1=分支名，其余=改动文件列表（内容随意）
# 用法在各 @test 内内联，因分支切换需精细控制

@test "op_merge_gate: 合法改动（workset + 结构层测试）→ exit 0" {
  setup_mock_project
  # workset=src/x.ts（helpers 默认）；review verdict 已 PASS
  mkdir -p src
  echo "orig" > src/x.ts
  git add -A && git commit -qm "base src"
  git checkout -qb op/task/T01
  echo "changed" > src/x.ts
  echo "test" > src/x.test.ts
  git add -A && git commit -qm "task work"
  git checkout -q master 2>/dev/null || git checkout -q main
  run "$OP_HOME/scripts/op_merge_gate.sh" T01 op/task/T01
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS"* ]]
  teardown_mock_project
}

@test "op_merge_gate: 受保护路径（op_blueprint）→ exit 1 REJECT" {
  setup_mock_project
  mkdir -p src
  echo "orig" > src/x.ts
  git add -A && git commit -qm "base src"
  git checkout -qb op/task/T01
  echo "changed" > src/x.ts
  mkdir -p docs/omni_powers/op_blueprint/specs
  echo "leak" > docs/omni_powers/op_blueprint/specs/dashboard.md
  git add -A && git commit -qm "违规改 blueprint"
  git checkout -q master 2>/dev/null || git checkout -q main
  run "$OP_HOME/scripts/op_merge_gate.sh" T01 op/task/T01
  [ "$status" -eq 1 ]
  [[ "$output" == *"受保护路径"* ]]
  [[ "$output" == *"op_blueprint"* ]]
  teardown_mock_project
}

@test "op_merge_gate: 工作集越界（workset 外文件）→ exit 1 REJECT" {
  setup_mock_project
  mkdir -p src
  echo "orig" > src/x.ts
  git add -A && git commit -qm "base src"
  git checkout -qb op/task/T01
  echo "changed" > src/x.ts
  echo "sneaky" > src/y.ts   # 不在 workset
  git add -A && git commit -qm "越界改 y"
  git checkout -q master 2>/dev/null || git checkout -q main
  run "$OP_HOME/scripts/op_merge_gate.sh" T01 op/task/T01
  [ "$status" -eq 1 ]
  [[ "$output" == *"工作集越界"* ]]
  [[ "$output" == *"src/y.ts"* ]]
  teardown_mock_project
}

@test "op_merge_gate: review 未 PASS（verdict FAIL）→ exit 1 REJECT" {
  setup_mock_project
  # 改 review 为 FAIL
  printf "# review\\n\\nverdict: FAIL\\n" > docs/omni_powers/op_execution/tasks/T01/review.md
  mkdir -p src
  echo "orig" > src/x.ts
  git add -A && git commit -qm "base + fail verdict"
  git checkout -qb op/task/T01
  echo "changed" > src/x.ts
  git add -A && git commit -qm "task work"
  git checkout -q master 2>/dev/null || git checkout -q main
  run "$OP_HOME/scripts/op_merge_gate.sh" T01 op/task/T01
  [ "$status" -eq 1 ]
  [[ "$output" == *"review 未 PASS"* ]]
  teardown_mock_project
}

@test "op_merge_gate: task 分支不存在 → exit 2 环境错" {
  setup_mock_project
  run "$OP_HOME/scripts/op_merge_gate.sh" T01 op/task/NONEXISTENT
  [ "$status" -eq 2 ]
  [[ "$output" == *"分支不存在"* ]]
  teardown_mock_project
}
