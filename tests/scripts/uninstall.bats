#!/usr/bin/env bats

REPO="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPT="$REPO/uninstall.sh"

setup() {
    TEST_ROOT="$(mktemp -d)"
    TEST_HOME="$(mktemp -d)"
    cd "$TEST_ROOT"
    git init -q
    git config user.email test@test.local
    git config user.name test
    mkdir -p .claude .git/hooks "$TEST_HOME/.claude"
    printf '{}\n' > "$TEST_HOME/.claude/settings.json"
}

teardown() {
    rm -rf "$TEST_ROOT" "$TEST_HOME"
}

run_uninstall() {
    CLAUDE_CONFIG_DIR="$TEST_HOME/.claude" HOME="$TEST_HOME" run bash "$SCRIPT" --purge-project -y "$@"
}

@test "uninstall: legacy 默认根完整删除" {
    mkdir -p docs/omni_powers/op_execution
    printf 'heavy\n' > docs/omni_powers/profile
    run_uninstall
    [ "$status" -eq 0 ]
    [ ! -e docs/omni_powers ]
}

@test "uninstall: docs 共享根只删 OP 资产并保留宿主内容" {
    mkdir -p docs/op_execution docs/op_blueprint docs/host
    printf 'lite\n' > docs/profile
    printf 'keep\n' > docs/host/readme.md
    cat > docs/README.md <<'EOF'
# Host
keep

<!-- omni_powers managed start: README.md -->
# OP
<!-- omni_powers managed end: README.md -->
EOF
    printf '{"env":{"OP_DOCS_DIR":"docs","KEEP":"yes"}}\n' > .claude/settings.json

    run_uninstall
    [ "$status" -eq 0 ]
    [ -f docs/host/readme.md ]
    grep -q '^keep$' docs/README.md
    ! grep -q 'omni_powers managed' docs/README.md
    [ ! -e docs/op_execution ]
    [ ! -e docs/profile ]
    [ "$(jq -r '.env.KEEP' .claude/settings.json)" = yes ]
    [ "$(jq -r '.env.OP_DOCS_DIR // empty' .claude/settings.json)" = "" ]
}

@test "uninstall: 清理 copied op_paths helper 和 OP hooks" {
    printf '# helper\n' > .git/hooks/op_paths.sh
    printf '#!/bin/sh\n# omni_powers\n' > .git/hooks/pre-commit
    printf '#!/bin/sh\n# user hook\n' > .git/hooks/user-hook

    run_uninstall
    [ "$status" -eq 0 ]
    [ ! -e .git/hooks/op_paths.sh ]
    [ ! -e .git/hooks/pre-commit ]
    [ -e .git/hooks/user-hook ]
}

@test "uninstall: 拒绝清理 Git dir 外 core.hooksPath" {
    outside_hooks="$(mktemp -d)"
    printf '# omni_powers but external\n' > "$outside_hooks/pre-commit"
    git config core.hooksPath "$outside_hooks"

    run_uninstall
    [ "$status" -eq 0 ]
    [ -f "$outside_hooks/pre-commit" ]
    [[ "$output" == *"Git dir 外"* ]]
    rm -rf "$outside_hooks"
}

@test "uninstall: 清理真实嵌套 Claude hooks" {
    cat > .claude/settings.json <<'EOF'
{"hooks":{"PreToolUse":[{"matcher":"Write|Edit","hooks":[{"type":"command","command":"$OP_HOME/hooks/run-hook.cmd pre_tool_use"},{"type":"command","command":"user-hook"}]}]},"env":{"OP_DOCS_DIR":"docs/omni_powers"}}
EOF

    run_uninstall
    [ "$status" -eq 0 ]
    [ "$(jq -r '.hooks.PreToolUse[0].hooks | length' .claude/settings.json)" -eq 1 ]
    [ "$(jq -r '.hooks.PreToolUse[0].hooks[0].command' .claude/settings.json)" = user-hook ]
}

@test "uninstall: dry-run 不修改共享根或 settings" {
    mkdir -p docs/op_execution
    printf '{"env":{"OP_DOCS_DIR":"docs"}}\n' > .claude/settings.json

    run_uninstall --dry-run
    [ "$status" -eq 0 ]
    [ -d docs/op_execution ]
    [ "$(jq -r '.env.OP_DOCS_DIR' .claude/settings.json)" = docs ]
}

@test "uninstall: 损坏项目 settings 时 fail closed" {
    mkdir -p docs/omni_powers
    printf '{broken\n' > .claude/settings.json

    run_uninstall
    [ "$status" -ne 0 ]
    [ -d docs/omni_powers ]
}
