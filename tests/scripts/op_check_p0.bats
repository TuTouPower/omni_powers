#!/usr/bin/env bats

# op_check_p0: lite P0 阻断检查（代闸门 C 的 P0 阻断语义）
# 测试脚本：skills/oplrun/scripts/op_check_p0.sh

SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/skills/oplrun/scripts/op_check_p0.sh"

setup() {
  TEST_DIR="$(mktemp -d)"
  export TEST_DIR
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "op_check_p0: 无 issues 目录 → exit 0（可归档）" {
  run bash -c "cd '$TEST_DIR' && bash '$SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "op_check_p0: 有 issues 无 P0 → exit 0" {
  mkdir -p "$TEST_DIR/docs/omni_powers/op_execution/issues"
  printf -- '---\nseverity: P2\nstatus: open\ntitle: 小问题\n---\n' \
    > "$TEST_DIR/docs/omni_powers/op_execution/issues/i1.md"
  run bash -c "cd '$TEST_DIR' && bash '$SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "op_check_p0: 有 open P0 → exit 1 + 清单含 id/title" {
  mkdir -p "$TEST_DIR/docs/omni_powers/op_execution/issues"
  printf -- '---\nid: I-test-01\ntitle: 登录崩溃\nseverity: P0\nstatus: open\n---\n' \
    > "$TEST_DIR/docs/omni_powers/op_execution/issues/i2.md"
  run bash -c "cd '$TEST_DIR' && bash '$SCRIPT'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"I-test-01"* ]]
  [[ "$output" == *"登录崩溃"* ]]
}

@test "op_check_p0: P0 已 closed → exit 0（不阻断）" {
  mkdir -p "$TEST_DIR/docs/omni_powers/op_execution/issues"
  printf -- '---\nseverity: P0\nstatus: closed\ntitle: 已修\n---\n' \
    > "$TEST_DIR/docs/omni_powers/op_execution/issues/i3.md"
  run bash -c "cd '$TEST_DIR' && bash '$SCRIPT'"
  [ "$status" -eq 0 ]
}
