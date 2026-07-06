#!/usr/bin/env bats

# op_worktree_setup: 隔离 worktree（sparse-checkout）
# 测试: scripts/op_worktree_setup.sh + op_worktree_teardown.sh

REPO="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SETUP="$REPO/scripts/op_worktree_setup.sh"
TEARDOWN="$REPO/scripts/op_worktree_teardown.sh"

setup() {
    git version 2>/dev/null | grep -qE 'git version (2\.(2[5-9]|[3-9])|[3-9])' || skip "git < 2.25，sparse-checkout 不可用"
    TEST_REPO="$(mktemp -d)"
    cd "$TEST_REPO"
    git init -q
    git config user.email t@t
    git config user.name t
    mkdir -p src/store e2e/b01 docs/omni_powers/op_execution/tasks/T01 docs/omni_powers/op_record
    echo code > src/store/x.ts
    echo test > e2e/b01/t.spec.js
    echo brief > docs/omni_powers/op_execution/tasks/T01/brief.md
    echo decisions > docs/omni_powers/op_record/decisions.md
    git add -A && git commit -qm init
}

teardown() {
    [ -n "${TEST_REPO:-}" ] && rm -rf "$TEST_REPO"
}

@test "worktree dev: 排除 e2e/（行为层隔离），保留 src/" {
    run bash "$SETUP" dev .claude/wt feat/dev
    [ "$status" -eq 0 ]
    [ -d ".claude/wt/src" ]
    [ ! -d ".claude/wt/e2e" ]
}

@test "worktree eval: 排除 src/tasks/decisions（防抄实现），保留 e2e/" {
    run bash "$SETUP" eval .claude/wt feat/eval
    [ "$status" -eq 0 ]
    [ ! -d ".claude/wt/src" ]
    [ -d ".claude/wt/e2e" ]
    [ ! -d ".claude/wt/docs/omni_powers/op_execution/tasks" ]
    [ ! -f ".claude/wt/docs/omni_powers/op_record/decisions.md" ]
}

@test "worktree teardown: 清理 worktree + 分支" {
    bash "$SETUP" dev .claude/wt feat/x >/dev/null 2>&1
    run bash "$TEARDOWN" .claude/wt feat/x
    [ "$status" -eq 0 ]
    [ ! -d ".claude/wt" ]
}
