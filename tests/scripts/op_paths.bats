#!/usr/bin/env bats

REPO="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPT="$REPO/scripts/op_paths.sh"

setup() {
    TEST_ROOT="$(mktemp -d)"
    cd "$TEST_ROOT"
    git init -q
    mkdir -p .claude
}

teardown() {
    [ -n "${TEST_ROOT:-}" ] && rm -rf "$TEST_ROOT"
}

@test "op_paths: 无配置使用默认根" {
    run bash -c 'source "$1"; unset OP_DOCS_DIR; op_load_paths "" "$2"; printf "%s\n%s\n" "$OP_DOCS_DIR" "$OP_EXECUTION_DIR_REL"' _ "$SCRIPT" "$TEST_ROOT"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "docs/omni_powers" ]
    [ "${lines[1]}" = "docs/omni_powers/op_execution" ]
}

@test "op_paths: 项目配置覆盖进程 env" {
    printf '{"env":{"OP_DOCS_DIR":"docs"}}\n' > .claude/settings.json
    run env OP_DOCS_DIR=legacy/path bash -c 'source "$1"; op_load_paths "" "$2"; printf "%s\n%s\n" "$OP_DOCS_DIR" "$OP_DOCS_DIR_SOURCE"' _ "$SCRIPT" "$TEST_ROOT"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "docs" ]
    [ "${lines[1]}" = "project_settings" ]
}

@test "op_paths: 显式参数优先并规范化" {
    printf '{"env":{"OP_DOCS_DIR":"docs/from_settings"}}\n' > .claude/settings.json
    run env OP_DOCS_DIR=docs/from_env bash -c 'source "$1"; op_load_paths "./custom//op/" "$2"; printf "%s\n%s\n" "$OP_DOCS_DIR" "$OP_DOCS_DIR_SOURCE"' _ "$SCRIPT" "$TEST_ROOT"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "custom/op" ]
    [ "${lines[1]}" = "explicit" ]
}

@test "op_paths: 进程 env 在项目无配置时生效" {
    run env OP_DOCS_DIR=custom/op bash -c 'source "$1"; op_load_paths "" "$2"; printf "%s\n" "$OP_DOCS_DIR"' _ "$SCRIPT" "$TEST_ROOT"
    [ "$status" -eq 0 ]
    [ "$output" = "custom/op" ]
}

@test "op_paths: settings JSON 或类型损坏时 fail closed" {
    local value
    for value in '{broken' '[]' '{"env":[]}' '{"env":{"OP_DOCS_DIR":7}}' '{"env":{"OP_DOCS_DIR":""}}'; do
        printf '%s\n' "$value" > .claude/settings.json
        run bash -c 'source "$1"; op_load_paths "" "$2"' _ "$SCRIPT" "$TEST_ROOT"
        [ "$status" -ne 0 ]
        [[ "$output" == *"非法"* ]]
    done
}

@test "op_paths: 拒绝危险或非法路径" {
    local value
    for value in /tmp/op . ../docs docs/../op .git/op .claude/op 'docs/op root' 'docs/*' 'docs\op' 'docs:op' $'docs\nother'; do
        run bash -c 'source "$1"; op_normalize_docs_dir "$2"' _ "$SCRIPT" "$value"
        [ "$status" -ne 0 ]
    done
}

@test "op_paths: zsh 可加载并规范化路径" {
    command -v zsh >/dev/null || skip "zsh 未安装"
    run zsh -c 'source "$1"; op_normalize_docs_dir "docs/custom"' _ "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$output" = "docs/custom" ]
}

@test "op_paths: 运行时拒绝 OP 根路径符号链接" {
    mkdir real_docs
    ln -s real_docs linked_docs
    run bash -c 'source "$1"; op_load_paths linked_docs "$2"' _ "$SCRIPT" "$TEST_ROOT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"符号链接"* ]]
}

@test "op_paths: 拒绝 settings 符号链接" {
    printf '{}\n' > real_settings.json
    ln -s ../real_settings.json .claude/settings.json
    run bash -c 'source "$1"; op_load_paths "" "$2"' _ "$SCRIPT" "$TEST_ROOT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"符号链接"* ]]
}

@test "op_paths: 精确成员判断不混淆相似前缀" {
    run bash -c 'source "$1"; op_path_is_within "docs/op/file" "docs/op"; op_path_is_within "docs/op_extra/file" "docs/op"' _ "$SCRIPT"
    [ "$status" -ne 0 ]
}

@test "op_paths: 派生绝对路径和 literal pathspec" {
    run bash -c 'source "$1"; unset OP_DOCS_DIR; op_load_paths "docs" "$2"; printf "%s\n%s\n" "$OP_BLUEPRINT_DIR" "$(op_git_literal_pathspec "$OP_BLUEPRINT_DIR_REL")"' _ "$SCRIPT" "$TEST_ROOT"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "$TEST_ROOT/docs/op_blueprint" ]
    [ "${lines[1]}" = ":(literal)docs/op_blueprint" ]
}

@test "op_paths: literal pathspec 拒绝绝对路径和穿越" {
    run bash -c 'source "$1"; op_git_literal_pathspec /tmp/x' _ "$SCRIPT"
    [ "$status" -ne 0 ]
    run bash -c 'source "$1"; op_git_literal_pathspec docs/../x' _ "$SCRIPT"
    [ "$status" -ne 0 ]
}

@test "op_paths: E2E 判断覆盖 heavy 与 lite 集合" {
    run bash -c 'source "$1"; op_load_paths "docs" "$2"; op_is_e2e_path e2e/T01/a.ts; op_is_e2e_path tests/e2e/a.ts; op_is_e2e_path tests/app/e2e/a.ts; op_is_e2e_path docs/e2e/T01/a.ts; ! op_is_e2e_path src/e2e_helper.ts' _ "$SCRIPT" "$TEST_ROOT"
    [ "$status" -eq 0 ]
}

@test "op_paths: optional TID review 属于保护路径" {
    run bash -c 'source "$1"; op_load_paths "docs" "$2"; op_is_protected_path docs/op_execution/tasks/T01/review.md T01; ! op_is_protected_path docs/op_execution/tasks/T02/review.md T01' _ "$SCRIPT" "$TEST_ROOT"
    [ "$status" -eq 0 ]
}

@test "op_paths: 失败和重复加载不保留旧派生状态" {
    run bash -c 'source "$1"; op_load_paths docs "$2"; OP_DOCS_DIR=../bad; if op_load_paths "" "$2"; then exit 9; fi; [ -z "${OP_DOCS_ROOT+x}" ] && [ -z "${OP_EXECUTION_DIR_REL+x}" ]' _ "$SCRIPT" "$TEST_ROOT"
    [ "$status" -eq 0 ]

    run bash -c 'source "$1"; op_load_paths docs "$2"; op_load_paths custom/op "$2"; printf "%s\n%s\n" "$OP_DOCS_ROOT" "$OP_EXECUTION_DIR_REL"' _ "$SCRIPT" "$TEST_ROOT"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "$TEST_ROOT/custom/op" ]
    [ "${lines[1]}" = "custom/op/op_execution" ]
}
