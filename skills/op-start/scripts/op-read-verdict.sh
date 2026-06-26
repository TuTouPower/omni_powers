#!/usr/bin/env bash
# op-read-verdict：读 review 文件的最终 verdict
# 用法: op-read-verdict.sh <TID>
# 输出: PASS / FAIL / MIXED（双 review 不一致）
# exit 0=PASS, 1=FAIL, 2=MIXED
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TID="${1:?用法: op-read-verdict.sh <TID>}"
TASK_DIR="$ROOT/docs/harness_execution/tasks/$TID"

die() { echo "[FAIL] $*" >&2; exit 2; }

read_verdict() {
    local file="$1"
    [ -f "$file" ] || die "$file 不存在"
    # 读最后一条 verdict 行（支持多轮 FAIL）
    tail -1 "$file" | grep -oP 'verdict:\s*\K(PASS|FAIL)' || die "$file 中未找到 verdict 行"
}

code_v=$(read_verdict "$TASK_DIR/review_code.md")
test_v=$(read_verdict "$TASK_DIR/review_test.md")

echo "code: $code_v"
echo "test: $test_v"

if [ "$code_v" = "PASS" ] && [ "$test_v" = "PASS" ]; then
    echo "verdict: PASS"
    exit 0
elif [ "$code_v" = "FAIL" ] || [ "$test_v" = "FAIL" ]; then
    echo "verdict: FAIL"
    exit 1
else
    echo "verdict: MIXED"
    exit 2
fi
