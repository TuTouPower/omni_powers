#!/usr/bin/env bash
# op-read-verdict：读 review 文件的最终 verdict，并判断当前轮次
# 用法: op-read-verdict.sh <TID>
# 输出: round + 各文件 verdict + result
# 无 review 文件时输出 round: 0, result: NONE，仍 exit 0
# exit 0 = 三 PASS 或无 review 文件, exit 1 = 任一 FAIL
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TID="${1:?用法: op-read-verdict.sh <TID>}"
TASK_DIR="$ROOT/docs/omni_powers/op_execution/tasks/$TID"

read_verdict() {
    local file="$1"
    [ -f "$file" ] || { echo "NONE"; return; }
    grep -oP 'verdict:\s*\K(PASS|FAIL)' "$file" | tail -1 || echo "NONE"
}

spec_v=$(read_verdict "$TASK_DIR/review_spec.md")
code_v=$(read_verdict "$TASK_DIR/review_code.md")
test_v=$(read_verdict "$TASK_DIR/review_test.md")

# 轮次 = review_spec.md 中 verdict 行数（无文件则为 0）
round=$(grep -c '^verdict:' "$TASK_DIR/review_spec.md" 2>/dev/null || echo 0)

if [ "$spec_v" = "NONE" ] && [ "$code_v" = "NONE" ] && [ "$test_v" = "NONE" ]; then
    echo "round: 0"
    echo "spec_review: NONE"
    echo "code_review: NONE"
    echo "test_review: NONE"
    echo "result: NONE"
    exit 0
fi

echo "round: $round"
echo "spec_review: $spec_v"
echo "code_review: $code_v"
echo "test_review: $test_v"

if [ "$spec_v" = "PASS" ] && [ "$code_v" = "PASS" ] && [ "$test_v" = "PASS" ]; then
    echo "result: PASS"
    exit 0
else
    echo "result: FAIL"
    exit 1
fi
