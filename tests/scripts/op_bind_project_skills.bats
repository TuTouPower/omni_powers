#!/usr/bin/env bats

load helpers

setup() {
    setup_mock_project
}

teardown() {
    teardown_mock_project
}

@test "bind heavy: 链 heavy 集且无 lite 业务 skill" {
    run bash "$OP_HOME/scripts/op_bind_project_skills.sh" --profile heavy
    [ "$status" -eq 0 ]
    [ -L "$TEST_ROOT/.claude/skills/oprun" ]
    [ -L "$TEST_ROOT/.claude/skills/opintake" ]
    [ -L "$TEST_ROOT/.claude/skills/opinit" ]
    [ -L "$TEST_ROOT/.claude/skills/opstatus" ]
    [ ! -e "$TEST_ROOT/.claude/skills/oplrun" ]
    [ ! -e "$TEST_ROOT/.claude/skills/oplintake" ]
    [ ! -e "$TEST_ROOT/.claude/agents/op-implementer.md" ]
    [ "$(readlink "$TEST_ROOT/.claude/skills/oprun")" = "$OP_HOME/skills/oprun" ]
}

@test "bind lite: 链 lite 集且无 heavy 业务 skill" {
    run bash "$OP_HOME/scripts/op_bind_project_skills.sh" --profile lite
    [ "$status" -eq 0 ]
    [ -L "$TEST_ROOT/.claude/skills/oplrun" ]
    [ -L "$TEST_ROOT/.claude/skills/oplintake" ]
    [ -L "$TEST_ROOT/.claude/skills/oplinit" ]
    [ ! -e "$TEST_ROOT/.claude/skills/oprun" ]
    [ ! -e "$TEST_ROOT/.claude/skills/opintake" ]
}

@test "bind: 缺 --profile 失败" {
    run bash "$OP_HOME/scripts/op_bind_project_skills.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"profile"* ]]
}

@test "bind: 非法 profile 失败" {
    run bash "$OP_HOME/scripts/op_bind_project_skills.sh" --profile mixed
    [ "$status" -ne 0 ]
}

@test "bind: dry-run 不写磁盘" {
    run bash "$OP_HOME/scripts/op_bind_project_skills.sh" --profile heavy --dry-run
    [ "$status" -eq 0 ]
    [ ! -e "$TEST_ROOT/.claude/skills/oprun" ]
}

@test "bind: 幂等重跑" {
    bash "$OP_HOME/scripts/op_bind_project_skills.sh" --profile heavy
    run bash "$OP_HOME/scripts/op_bind_project_skills.sh" --profile heavy
    [ "$status" -eq 0 ]
    [ -L "$TEST_ROOT/.claude/skills/oprun" ]
}

@test "bind: lite profile 时 heavy 零写入" {
    mkdir -p "$OP_TEST_DOCS_ROOT"
    printf 'lite\n' > "$OP_TEST_DOCS_ROOT/profile"
    run bash "$OP_HOME/scripts/op_bind_project_skills.sh" --profile heavy
    [ "$status" -ne 0 ]
    [[ "$output" == *"冲突"* ]] || [[ "$output" == *"profile"* ]]
    [ ! -e "$TEST_ROOT/.claude/skills/oprun" ]
    [ ! -e "$TEST_ROOT/.claude/skills/opinit" ]
}

@test "bind: heavy profile 时 lite 零写入" {
    mkdir -p "$OP_TEST_DOCS_ROOT"
    printf 'heavy\n' > "$OP_TEST_DOCS_ROOT/profile"
    run bash "$OP_HOME/scripts/op_bind_project_skills.sh" --profile lite
    [ "$status" -ne 0 ]
    [ ! -e "$TEST_ROOT/.claude/skills/oplrun" ]
    [ ! -e "$TEST_ROOT/.claude/skills/oplinit" ]
}

@test "bind: 拒绝覆盖非 OP 同名 skill" {
    mkdir -p "$TEST_ROOT/.claude/skills/oprun"
    printf '# user skill\n' > "$TEST_ROOT/.claude/skills/oprun/SKILL.md"
    run bash "$OP_HOME/scripts/op_bind_project_skills.sh" --profile heavy
    [ "$status" -ne 0 ]
    [[ "$output" == *"非 OP"* ]] || [[ "$output" == *"占用"* ]]
    [ -f "$TEST_ROOT/.claude/skills/oprun/SKILL.md" ]
    grep -q 'user skill' "$TEST_ROOT/.claude/skills/oprun/SKILL.md"
    [ ! -e "$TEST_ROOT/.claude/skills/opintake" ]
}

@test "ownership: OP 软链可识别" {
    # shellcheck source=/dev/null
    source "$OP_HOME/scripts/op_asset_ownership.sh"
    mkdir -p "$TEST_ROOT/.claude/skills"
    ln -s "$OP_HOME/skills/oprun" "$TEST_ROOT/.claude/skills/oprun"
    run bash -c "source '$OP_HOME/scripts/op_asset_ownership.sh'; op_is_owned_skill '$TEST_ROOT/.claude/skills/oprun' oprun"
    [ "$status" -eq 0 ]
}
