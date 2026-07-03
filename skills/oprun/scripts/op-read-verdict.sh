#!/usr/bin/env bash
# op_read_verdict：读 review.md 最终 verdict，判断轮次
# 用法: op_read_verdict.sh <TID>
# 输出: round + verdict + result
# 无 review.md → round: 0, result: NONE, exit 0
# exit 0 = PASS 或 NONE, exit 1 = FAIL
# v6：review.md 单文件（取代 v5 review_spec/code/test 三文件）
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TID="${1:?用法: op_read_verdict.sh <TID>}"
REVIEW_FILE="$ROOT/docs/omni_powers/op_execution/tasks/$TID/review.md"

if [ ! -f "$REVIEW_FILE" ]; then
    echo "round: 0"
    echo "verdict: NONE"
    echo "result: NONE"
    exit 0
fi

round=$(grep -c '^verdict:' "$REVIEW_FILE" 2>/dev/null || echo 0)
verdict=$(grep -oE '^verdict:[[:space:]]*(PASS|FAIL)' "$REVIEW_FILE" | tail -1 | sed -E 's/.*verdict:[[:space:]]*//' || echo "NONE")

echo "round: $round"
echo "verdict: $verdict"

if [ "$verdict" = "PASS" ]; then
    echo "result: PASS"
    exit 0
elif [ "$verdict" = "FAIL" ]; then
    echo "result: FAIL"
    exit 1
else
    echo "result: NONE"
    exit 0
fi
