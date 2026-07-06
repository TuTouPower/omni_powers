#!/usr/bin/env bash
# op_ci_local.sh: 本地 CI 等价物（design §3.3.1 三接口）
#
# 在被监督者控制之外执行测试/e2e/构建，结果落 .ci-results/{sha}/，reviewer/leader 读结果裁决。
# 由 leader 主会话在 implementer 交工后调用，或 git post-receive 触发。
#
# 三接口：
#   ① 跑测试（OP_TEST_CMD）→ test.log + test.exit
#   ② 只读跑 e2e（OP_E2E_CMD）→ e2e.log + e2e.exit（不写代码，回传结果）
#   ③ 构建产物（OP_BUILD_CMD + OP_BUILD_OUT）→ build.log + artifacts 归档
#
# 项目侧环境变量（在项目 .claude/settings.json env 或 leader dispatch 前导出）：
#   OP_TEST_CMD    测试命令（如 "npm test" / "pytest -q"）
#   OP_E2E_CMD     e2e 命令（如 "npx playwright test e2e/" / "pytest e2e/"）
#   OP_BUILD_CMD   构建命令（如 "npm run build" / "cargo build --release"）
#   OP_BUILD_OUT   构建产物路径（如 "dist/" / "target/release/app"），归档给 evaluator
#   OP_CI_OUT      结果输出根目录（默认 .ci-results）
#
# 安全边界（design §3.3.1 + A17）：
#   - 结果带 commit-sha（防混淆）
#   - leader 主会话跑（agent worktree 应不挂载 $OP_CI_OUT，靠 .gitignore 或 worktree 排除）
#   - 结果文件独立写，agent 不得覆盖（纪律 + reviewer 比对 sha）

set -uo pipefail

sha="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
out="${OP_CI_OUT:-.ci-results}/$sha"
mkdir -p "$out"

echo "=== op_ci_local @ $sha ==="
echo "结果落: $out"

# 接口 ① 跑测试
test_cmd="${OP_TEST_CMD:-}"
if [ -n "$test_cmd" ]; then
    echo "--- [1/3] 测试: $test_cmd ---"
    # shellcheck disable=SC2086
    $test_cmd > "$out/test.log" 2>&1
    echo "test exit=$?" > "$out/test.exit"
else
    echo "[SKIP] OP_TEST_CMD 未设" > "$out/test.log"
    echo "test exit=SKIP" > "$out/test.exit"
fi

# 接口 ② 只读跑 e2e
e2e_cmd="${OP_E2E_CMD:-}"
if [ -n "$e2e_cmd" ]; then
    echo "--- [2/3] e2e: $e2e_cmd ---"
    # shellcheck disable=SC2086
    $e2e_cmd > "$out/e2e.log" 2>&1 || true
    echo "e2e exit=$?" > "$out/e2e.exit"
else
    echo "[SKIP] OP_E2E_CMD 未设" > "$out/e2e.log"
    echo "e2e exit=SKIP" > "$out/e2e.exit"
fi

# 接口 ③ 构建产物归档
build_cmd="${OP_BUILD_CMD:-}"
build_out="${OP_BUILD_OUT:-}"
if [ -n "$build_cmd" ]; then
    echo "--- [3/3] 构建: $build_cmd ---"
    # shellcheck disable=SC2086
    $build_cmd > "$out/build.log" 2>&1
    echo "build exit=$?" > "$out/build.exit"
    if [ -n "$build_out" ] && [ -e "$build_out" ]; then
        tar czf "$out/artifacts.tar.gz" "$build_out" 2>/dev/null \
            && echo "artifacts: $out/artifacts.tar.gz" \
            || cp -r "$build_out" "$out/" 2>/dev/null
    fi
else
    echo "[SKIP] OP_BUILD_CMD 未设" > "$out/build.log"
    echo "build exit=SKIP" > "$out/build.exit"
fi

# 汇总 JSON（reviewer/leader 读此裁决）
test_exit="$(cat "$out/test.exit")"
e2e_exit="$(cat "$out/e2e.exit" 2>/dev/null || echo SKIP)"
build_exit="$(cat "$out/build.exit" 2>/dev/null || echo SKIP)"
cat > "$out/result.json" <<EOF
{
  "sha": "$sha",
  "test": "$test_exit",
  "e2e": "$e2e_exit",
  "build": "$build_exit"
}
EOF
cat "$out/result.json"
