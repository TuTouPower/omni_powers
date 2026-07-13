#!/usr/bin/env bats

REPO="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPT="$REPO/scripts/op_configure_project.sh"

setup() {
    TEST_ROOT="$(mktemp -d)"
    cd "$TEST_ROOT"
    git init -q
    git config user.email test@test.local
    git config user.name test
    mkdir -p .claude
}

teardown() {
    [ -n "${TEST_ROOT:-}" ] && rm -rf "$TEST_ROOT"
}

@test "configure: 写 OP_DOCS_DIR 保留 settings 其他字段" {
    printf '{"permissions":{"allow":["Read"]},"env":{"KEEP":"yes"}}\n' > .claude/settings.json
    run bash "$SCRIPT" --root "$TEST_ROOT" --target docs --yes
    [ "$status" -eq 0 ]
    [ "$(jq -r '.env.OP_DOCS_DIR' .claude/settings.json)" = docs ]
    [ "$(jq -r '.env.KEEP' .claude/settings.json)" = yes ]
    [ "$(jq -r '.permissions.allow[0]' .claude/settings.json)" = Read ]
}

@test "configure: legacy 目录迁移到 docs 且宿主 README 保留" {
    mkdir -p docs/omni_powers/op_execution docs/omni_powers/op_record docs/omni_powers/op_blueprint
    printf 'heavy\n' > docs/omni_powers/profile
    printf '{"tasks":[]}\n' > docs/omni_powers/op_execution/tasks_list.json
    printf '# OP old\n' > docs/omni_powers/README.md
    printf '# Host docs\n\nkeep me\n' > docs/README.md

    run bash "$SCRIPT" --root "$TEST_ROOT" --target docs --yes
    [ "$status" -eq 0 ]
    [ -f docs/op_execution/tasks_list.json ]
    [ ! -e docs/omni_powers/op_execution ]
    grep -q 'keep me' docs/README.md
    grep -q 'omni_powers managed start' docs/README.md
    grep -q '# OP old' docs/README.md
}

@test "configure: 冲突预检失败时不修改文件或配置" {
    mkdir -p docs/omni_powers/op_execution docs/op_execution
    printf 'heavy\n' > docs/omni_powers/profile
    printf 'source\n' > docs/omni_powers/op_execution/x.md
    printf 'target\n' > docs/op_execution/x.md
    printf '{"env":{"KEEP":"yes"}}\n' > .claude/settings.json

    run bash "$SCRIPT" --root "$TEST_ROOT" --target docs --yes
    [ "$status" -ne 0 ]
    [ "$(cat docs/omni_powers/op_execution/x.md)" = source ]
    [ "$(cat docs/op_execution/x.md)" = target ]
    [ "$(jq -r '.env.OP_DOCS_DIR // empty' .claude/settings.json)" = "" ]
}

@test "configure: 非交互迁移未确认时拒绝" {
    mkdir -p docs/omni_powers/op_execution
    printf 'heavy\n' > docs/omni_powers/profile
    run bash "$SCRIPT" --root "$TEST_ROOT" --target docs
    [ "$status" -ne 0 ]
    [[ "$output" == *"需要确认"* ]]
}

@test "configure: managed block 重跑幂等" {
    run bash "$SCRIPT" --root "$TEST_ROOT" --target docs/op --yes
    [ "$status" -eq 0 ]
    run bash "$SCRIPT" --root "$TEST_ROOT" --target docs/op --yes
    [ "$status" -eq 0 ]
    [ "$(grep -c 'omni_powers managed start' docs/op/.gitignore)" -eq 1 ]
}

@test "configure: custom 根迁移到另一 custom 根" {
    mkdir -p custom/old/op_execution
    printf 'lite\n' > custom/old/profile
    printf '{"tasks":[]}\n' > custom/old/op_execution/tasks_list.json
    printf '{"env":{"OP_DOCS_DIR":"custom/old"}}\n' > .claude/settings.json

    run bash "$SCRIPT" --root "$TEST_ROOT" --target custom/new --yes
    [ "$status" -eq 0 ]
    [ -f custom/new/op_execution/tasks_list.json ]
    [ ! -e custom/old/profile ]
    [ "$(jq -r '.env.OP_DOCS_DIR' .claude/settings.json)" = custom/new ]
}

@test "configure: 相同目标文件去重不覆盖" {
    mkdir -p docs/omni_powers/op_execution docs/op_execution
    printf 'heavy\n' > docs/omni_powers/profile
    printf 'same\n' > docs/omni_powers/op_execution/x.md
    printf 'same\n' > docs/op_execution/x.md

    run bash "$SCRIPT" --root "$TEST_ROOT" --target docs --yes
    [ "$status" -eq 0 ]
    [ "$(cat docs/op_execution/x.md)" = same ]
    [ ! -e docs/omni_powers/op_execution/x.md ]
}

@test "configure: 故障注入后回滚文件和 settings" {
    mkdir -p docs/omni_powers/op_execution
    printf 'heavy\n' > docs/omni_powers/profile
    printf 'source\n' > docs/omni_powers/op_execution/x.md
    printf '{"env":{"KEEP":"yes"}}\n' > .claude/settings.json

    run env OP_TEST_FAIL_AFTER_STAGE=owned bash "$SCRIPT" --root "$TEST_ROOT" --target docs --yes
    [ "$status" -ne 0 ]
    [ "$(cat docs/omni_powers/op_execution/x.md)" = source ]
    [ ! -e docs/op_execution/x.md ]
    [ "$(jq -r '.env.KEEP' .claude/settings.json)" = yes ]
    [ "$(jq -r '.env.OP_DOCS_DIR // empty' .claude/settings.json)" = "" ]
}

@test "configure: docs 共享根迁出保留宿主内容并只迁 OP block" {
    mkdir -p docs/op_execution
    printf 'lite\n' > docs/profile
    printf 'task\n' > docs/op_execution/x.md
    cat > docs/README.md <<'EOF'
# Host docs
keep me

<!-- omni_powers managed start: README.md -->
# OP navigation
<!-- omni_powers managed end: README.md -->
EOF
    printf '{"env":{"OP_DOCS_DIR":"docs"}}\n' > .claude/settings.json

    run bash "$SCRIPT" --root "$TEST_ROOT" --target custom/op --yes
    [ "$status" -eq 0 ]
    [ -f docs/README.md ]
    grep -q 'keep me' docs/README.md
    ! grep -q 'omni_powers managed' docs/README.md
    [ "$(cat custom/op/README.md)" = "# OP navigation" ]
    [ -f custom/op/op_execution/x.md ]
}

@test "configure: 拒绝目标 owned 树内部符号链接" {
    mkdir -p docs/omni_powers/op_execution docs/op_execution outside
    printf 'heavy\n' > docs/omni_powers/profile
    printf 'source\n' > docs/omni_powers/op_execution/x.md
    ln -s "$TEST_ROOT/outside" docs/op_execution/tasks

    run bash "$SCRIPT" --root "$TEST_ROOT" --target docs --yes
    [ "$status" -ne 0 ]
    [[ "$output" == *"符号链接"* ]]
    [ ! -e outside/x.md ]
}

@test "configure: 拒绝源 owned 树内部符号链接" {
    mkdir -p docs/omni_powers/op_execution outside
    printf 'heavy\n' > docs/omni_powers/profile
    printf 'outside\n' > outside/x.md
    ln -s "$TEST_ROOT/outside" docs/omni_powers/op_execution/tasks

    run bash "$SCRIPT" --root "$TEST_ROOT" --target docs --yes
    [ "$status" -ne 0 ]
    [[ "$output" == *"符号链接"* ]]
}

@test "configure: 拒绝 settings 符号链接" {
    printf '{}\n' > real_settings.json
    ln -s ../real_settings.json .claude/settings.json
    run bash "$SCRIPT" --root "$TEST_ROOT" --target docs --yes
    [ "$status" -ne 0 ]
    [[ "$output" == *"符号链接"* ]]
    [ "$(cat real_settings.json)" = "{}" ]
}

@test "configure: .gitignore managed block 迁移后标签唯一" {
    mkdir -p docs/omni_powers
    printf 'heavy\n' > docs/omni_powers/profile
    printf '*.tmp\n' > docs/omni_powers/.gitignore

    run bash "$SCRIPT" --root "$TEST_ROOT" --target docs --yes
    [ "$status" -eq 0 ]
    [ "$(grep -c 'managed start: gitignore' docs/.gitignore)" -eq 1 ]
    [ "$(grep -c 'managed start: .gitignore' docs/.gitignore || true)" -eq 0 ]
}

@test "configure: 拒绝符号链接目标根" {
    mkdir real_docs
    ln -s real_docs linked_docs
    run bash "$SCRIPT" --root "$TEST_ROOT" --target linked_docs --yes
    [ "$status" -ne 0 ]
    [[ "$output" == *"符号链接"* ]]
}
