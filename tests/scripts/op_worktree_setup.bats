#!/usr/bin/env bats

# op_worktree_setup: 隔离 worktree（sparse-checkout）
# 测试: scripts/op_worktree_setup.sh + op_worktree_teardown.sh
# H9: 扩展 specs/acceptance/tasks_list/op_record 挂载断言

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
    mkdir -p src/store e2e/b01 tests/e2e tests/app/e2e \
             docs/omni_powers/op_execution/tasks/T01 \
             docs/omni_powers/op_execution/specs \
             docs/omni_powers/op_execution/acceptance/T01 \
             docs/omni_powers/op_record/tasks/T0000_old
    echo code > src/store/x.ts
    echo test > e2e/b01/t.spec.js
    echo test > tests/e2e/t.spec.js
    echo test > tests/app/e2e/t.spec.js
    echo report > docs/omni_powers/op_execution/tasks/T01/report.md
    echo spec > docs/omni_powers/op_execution/specs/T01_x.md
    echo baseline > docs/omni_powers/op_execution/acceptance/T01/baselines.txt
    echo decisions > docs/omni_powers/op_record/decisions.md
    echo archived > docs/omni_powers/op_record/tasks/T0000_old/old.md
    git add -A && git commit -qm init
}

teardown() {
    [ -n "${TEST_REPO:-}" ] && rm -rf "$TEST_REPO"
}

@test "worktree dev: 排除 e2e/（行为层隔离），保留 src/ + specs/ + tasks（report 可写）" {
    run bash "$SETUP" dev .claude/wt feat/dev
    [ "$status" -eq 0 ]
    [ -d ".claude/wt/src" ]
    [ ! -d ".claude/wt/e2e" ]
    [ ! -d ".claude/wt/tests/e2e" ]
    [ ! -d ".claude/wt/tests/app/e2e" ]
    [ -d ".claude/wt/docs/omni_powers/op_execution/specs" ]                    # H9: dev 有 specs
    [ -f ".claude/wt/docs/omni_powers/op_execution/tasks/T01/report.md" ]      # report 可写
}

@test "worktree eval: 排除 src/tasks/decisions（防抄实现），保留 e2e/ + acceptance（可写）" {
    run bash "$SETUP" eval .claude/wt feat/eval
    [ "$status" -eq 0 ]
    [ ! -d ".claude/wt/src" ]
    [ -d ".claude/wt/e2e" ]
    [ -d ".claude/wt/docs/omni_powers/op_execution/acceptance/T01" ]           # H9: eval 有 acceptance（可写）
    [ ! -d ".claude/wt/docs/omni_powers/op_execution/tasks" ]
    [ ! -f ".claude/wt/docs/omni_powers/op_record/decisions.md" ]
    [ ! -d ".claude/wt/docs/omni_powers/op_record/tasks" ]                     # H9: eval 无 op_record/tasks
}

@test "worktree teardown: 清理 worktree + 分支" {
    bash "$SETUP" dev .claude/wt feat/x >/dev/null 2>&1
    run bash "$TEARDOWN" .claude/wt feat/x
    [ "$status" -eq 0 ]
    [ ! -d ".claude/wt" ]
}
