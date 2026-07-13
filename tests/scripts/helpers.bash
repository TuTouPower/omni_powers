#!/usr/bin/env bash
# 共享 helpers：建 mock omni_powers 项目（临时 git 仓库 + 三区 fixtures）
# 每个 @test setup 时调 setup_mock_project，结束调 teardown_mock_project

# OP_HOME = 项目根（tests/scripts/*.bats 上溯两级）
OP_HOME="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
export OP_HOME

setup_mock_project() {
  TEST_ROOT="$(mktemp -d)"
  OP_TEST_DOCS_DIR="${OP_TEST_DOCS_DIR:-docs/omni_powers}"
  OP_TEST_DOCS_ROOT="$TEST_ROOT/$OP_TEST_DOCS_DIR"
  export TEST_ROOT OP_TEST_DOCS_DIR OP_TEST_DOCS_ROOT
  cd "$TEST_ROOT" || return 1
  git init -q
  git config user.email "test@test.local"
  git config user.name "test"

  mkdir -p "$OP_TEST_DOCS_ROOT"/op_execution/tasks/T01
  mkdir -p "$OP_TEST_DOCS_ROOT"/op_execution/issues
  mkdir -p "$OP_TEST_DOCS_ROOT"/op_record/tasks
  mkdir -p "$OP_TEST_DOCS_ROOT"/op_execution/acceptance/T01
  mkdir -p e2e/T01

  if [ "$OP_TEST_DOCS_DIR" != "docs/omni_powers" ]; then
    mkdir -p .claude
    jq -n --arg value "$OP_TEST_DOCS_DIR" '{env:{OP_DOCS_DIR:$value}}' > .claude/settings.json
  fi

  # tasks_list.json（schema：id/title/status/spec/depends_on/workset/eval/eval_reason，design §2.3/D9）
  cat > "$OP_TEST_DOCS_ROOT"/op_execution/tasks_list.json <<'JSON'
{"tasks":[{"id":"T01","title":"test task","status":"closing","spec":"specs/T01_x.md","depends_on":null,"workset":["src/x.ts"],"eval":"skip","eval_reason":"fixture"}]}
JSON

  # task 工作区（review verdict PASS；无 brief，design §1.1）
  echo "# report" > "$OP_TEST_DOCS_ROOT"/op_execution/tasks/T01/report.md
  printf "# review\\n\\nverdict: PASS\\n" > "$OP_TEST_DOCS_ROOT"/op_execution/tasks/T01/review.md
  printf "# blueprint update\\n\\n无更新\\n" > "$OP_TEST_DOCS_ROOT"/op_execution/acceptance/T01/blueprint_update.md
  touch e2e/T01/.keep

  # merge gate 证据（本轮改进：op_close_post 强制要求）
  echo "PASS T01 op/task/T01→main $(date -Iseconds)" > "$OP_TEST_DOCS_ROOT"/op_execution/tasks/T01/.merge_gate_passed

  # leader_checkpoint（### 段格式，对齐 docs_template/.../leader_checkpoint.md；current_task 正文=T01）
  cat > "$OP_TEST_DOCS_ROOT"/op_execution/leader_checkpoint.md <<'EOF'
# Leader Checkpoint

## 断点

### current_task

T01

### last_completed

### next_step

## 关键上下文

- fixture
EOF

  touch "$OP_TEST_DOCS_ROOT"/op_record/progress.md

  # 初始 commit（让 op_close_post 的 git mv 可用）
  git add -A
  git commit -qm "init"

  cd "$TEST_ROOT" || return 1
}

teardown_mock_project() {
  [ -n "${TEST_ROOT:-}" ] && [ -d "$TEST_ROOT" ] && rm -rf "$TEST_ROOT"
}
