#!/usr/bin/env bats

# 测 opinit_skeleton.sh（建三区骨架 + 重跑幂等）

OP_HOME="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
export OP_HOME

setup() {
  TEST_ROOT="$(mktemp -d)"
  cd "$TEST_ROOT"
  git init -q
  git config user.email "test@test.local"
  git config user.name "test"
  git commit -qm "init" --allow-empty
}

teardown() {
  [ -n "${TEST_ROOT:-}" ] && [ -d "$TEST_ROOT" ] && rm -rf "$TEST_ROOT"
}

@test "opinit_skeleton: 建三区骨架（目录+baselines+tasks_list+checkpoint+.test_locks）" {
  run bash "$OP_HOME/scripts/opinit_skeleton.sh"
  [ "$status" -eq 0 ]
  [ -d docs/omni_powers/op_blueprint/specs ]
  [ -d docs/omni_powers/op_blueprint/baselines ]
  [ -d docs/omni_powers/op_execution/tasks ]
  [ -d docs/omni_powers/op_record/specs ]
  [ -f docs/omni_powers/op_blueprint/baselines/baselines_index.md ]
  [ -f docs/omni_powers/op_execution/tasks_list.json ]
  [ -f docs/omni_powers/op_execution/leader_checkpoint.md ]
  [ -f docs/omni_powers/op_execution/.test_locks ]
}

@test "opinit_skeleton: 重跑幂等——不覆盖 tasks_list/checkpoint" {
  bash "$OP_HOME/scripts/opinit_skeleton.sh" >/dev/null
  # 模拟用户已有数据
  echo '{"tasks":[{"id":"T01"}]}' > docs/omni_powers/op_execution/tasks_list.json
  echo "user checkpoint content" > docs/omni_powers/op_execution/leader_checkpoint.md
  # 重跑
  run bash "$OP_HOME/scripts/opinit_skeleton.sh"
  [ "$status" -eq 0 ]
  # 内容保留（不被覆盖）
  [ "$(cat docs/omni_powers/op_execution/tasks_list.json)" = '{"tasks":[{"id":"T01"}]}' ]
  [ "$(cat docs/omni_powers/op_execution/leader_checkpoint.md)" = "user checkpoint content" ]
}
