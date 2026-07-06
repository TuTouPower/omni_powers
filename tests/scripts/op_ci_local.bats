#!/usr/bin/env bats

# op_ci_local: 本地 CI 等价物（design §3.3.1 三接口）

REPO="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPT="$REPO/scripts/op_ci_local.sh"

setup() {
    TEST_REPO="$(mktemp -d)"
    cd "$TEST_REPO"
    git init -q
    git config user.email t@t
    git config user.name t
    echo x > f.txt
    git add f.txt && git commit -qm init
}

teardown() {
    [ -n "${TEST_REPO:-}" ] && rm -rf "$TEST_REPO"
}

@test "op_ci_local: 三接口全设 → result.json + artifacts" {
    SHA=$(git rev-parse HEAD)
    OP_TEST_CMD="echo ok" OP_E2E_CMD="echo ok" \
    OP_BUILD_CMD="mkdir -p dist && echo b > dist/a" OP_BUILD_OUT="dist" \
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -f ".ci-results/$SHA/result.json" ]
    [ -f ".ci-results/$SHA/artifacts.tar.gz" ]
    grep -q '"test": "test exit=0"' ".ci-results/$SHA/result.json"
    grep -q '"build": "build exit=0"' ".ci-results/$SHA/result.json"
}

@test "op_ci_local: 未设环境变量 → 全 SKIP，不报错" {
    SHA=$(git rev-parse HEAD)
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    grep -q '"test": "test exit=SKIP"' ".ci-results/$SHA/result.json"
    grep -q '"e2e": "e2e exit=SKIP"' ".ci-results/$SHA/result.json"
    grep -q '"build": "build exit=SKIP"' ".ci-results/$SHA/result.json"
}

@test "op_ci_local: 只设测试 → e2e/build SKIP，test 有结果" {
    SHA=$(git rev-parse HEAD)
    OP_TEST_CMD="echo ok" run bash "$SCRIPT"
    [ -f ".ci-results/$SHA/test.log" ]
    grep -q '"test": "test exit=0"' ".ci-results/$SHA/result.json"
    grep -q '"e2e": "e2e exit=SKIP"' ".ci-results/$SHA/result.json"
}
