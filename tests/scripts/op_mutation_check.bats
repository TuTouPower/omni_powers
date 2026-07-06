#!/usr/bin/env bats

# op_mutation_check: 变异测试骨架（== ↔ !=）

REPO="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPT="$REPO/scripts/op_mutation_check.sh"

setup() {
    TEST_DIR="$(mktemp -d)"
}

teardown() {
    [ -n "${TEST_DIR:-}" ] && rm -rf "$TEST_DIR"
}

@test "mutation: 测试覆盖 == → KILLED（exit 0）" {
    cd "$TEST_DIR"
    # 源：eq 函数用 == 比较
    cat > lib.sh <<'EOF'
eq() { [ "$1" == "$2" ]; }
EOF
    # 测试：验证 eq a a 为真（覆盖了 ==）
    cat > test.sh <<'EOF'
#!/usr/bin/env bash
source lib.sh
if eq a a; then echo pass; else echo fail; exit 1; fi
EOF
    chmod +x test.sh
    run bash "$SCRIPT" "$TEST_DIR/lib.sh" bash "$TEST_DIR/test.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"KILLED"* ]]
}

@test "mutation: 测试不覆盖 == → ESCAPE（exit 1）" {
    cd "$TEST_DIR"
    cat > lib.sh <<'EOF'
eq() { [ "$1" == "$2" ]; }
unused() { return 0; }
EOF
    # 测试只调 unused，从不调 eq——== 分支无覆盖
    cat > test.sh <<'EOF'
#!/usr/bin/env bash
source lib.sh
unused
echo pass
EOF
    chmod +x test.sh
    run bash "$SCRIPT" "$TEST_DIR/lib.sh" bash "$TEST_DIR/test.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"ESCAPE"* ]]
}

@test "mutation: 无 == / != 运算符 → SKIP" {
    cd "$TEST_DIR"
    echo 'x=1' > lib.sh
    echo 'echo ok' > test.sh
    chmod +x test.sh
    run bash "$SCRIPT" "$TEST_DIR/lib.sh" bash "$TEST_DIR/test.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"SKIP"* ]]
}
