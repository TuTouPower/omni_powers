#!/usr/bin/env bash
# 共享 helpers：建 mock omni_powers 项目（临时 git 仓库 + 三区 fixtures）
# 每个 @test setup 时调 setup_mock_project，结束调 teardown_mock_project

# OP_HOME = 项目根（tests/scripts/*.bats 上溯两级）
OP_HOME="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
export OP_HOME

setup_mock_project() {
  TEST_ROOT="$(mktemp -d)"
  cd "$TEST_ROOT" || return 1
  git init -q
  git config user.email "test@test.local"
  git config user.name "test"

  mkdir -p docs/omni_powers/op_execution/tasks/T01
  mkdir -p docs/omni_powers/op_execution/issues
  mkdir -p docs/omni_powers/op_record/tasks
  mkdir -p e2e

  # tasks_list.json（opintake schema）
  cat > docs/omni_powers/op_execution/tasks_list.json <<'JSON'
{"tasks":[{"id":"T01","title":"test task","status":"收口中","spec":"b01","type":"实现","covers_ac":["AC-1"],"touches_inv":[],"depends_on":null,"risk_probe":false,"workset":["src/x.ts"]}]}
JSON

  # task 工作区三件（review verdict PASS）
  echo "# brief" > docs/omni_powers/op_execution/tasks/T01/brief.md
  echo "# report" > docs/omni_powers/op_execution/tasks/T01/report.md
  printf "# review\\n\\nverdict: PASS\\n" > docs/omni_powers/op_execution/tasks/T01/review.md

  # leader_checkpoint（含 current_task: T01）
  cat > docs/omni_powers/op_execution/leader_checkpoint.md <<'EOF'
current_task: T01
last_completed:
next_step:
关键上下文:

## 已完成 task

## tasks_list 状态
EOF

  touch docs/omni_powers/op_record/progress.md

  # 初始 commit（让 op_close_post 的 git mv 可用）
  git add -A
  git commit -qm "init"

  cd "$TEST_ROOT" || return 1
}

teardown_mock_project() {
  [ -n "${TEST_ROOT:-}" ] && [ -d "$TEST_ROOT" ] && rm -rf "$TEST_ROOT"
}
