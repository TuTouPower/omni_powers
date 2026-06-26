#!/usr/bin/env bash
# op-read-verdict：读 review 文件的最终 verdict + 轮次
# 用法: op-read-verdict.sh <TID>
# 分别读 review_code.md 和 review_test.md 的最后一条 verdict 行
# 输出: 轮次、各文件 verdict、最终结果
# exit 0 = 双 PASS, exit 1 = 任一 FAIL
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TID="${1:?用法: op-read-verdict.sh <TID>}"
TASK_DIR="$ROOT/docs/op_execution/tasks/$TID"

die() { echo "[FAIL] $*" >&2; exit 1; }

read_verdict() {
    local file="$1"
    [ -f "$file" ] || die "$file 不存在"
    grep -oP 'verdict:\s*\K(PASS|FAIL)' "$file" | tail -1 || die "$file 中未找到 verdict 行"
}

code_v=$(read_verdict "$TASK_DIR/review_code.md")
test_v=$(read_verdict "$TASK_DIR/review_test.md")

# 轮次 = review_code.md 中 Round verdict 行数（两个文件应一致）
round=$(grep -c 'Round.*verdict:' "$TASK_DIR/review_code.md" 2>/dev/null || echo 0)

echo "round: $round"
echo "code_review: $code_v"
echo "test_review: $test_v"

if [ "$code_v" = "PASS" ] && [ "$test_v" = "PASS" ]; then
    echo "result: PASS"
    exit 0
else
    echo "result: FAIL"
    exit 1
fi
