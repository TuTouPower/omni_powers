#!/usr/bin/env bash
# op_implementer_check：implementer 启动时判断模式（正向/FAIL）和轮次
# 用法: op_implementer_check.sh <TID>
# 输出: mode=normal|fail|blocked, round=1|2|3
# exit 0 = 可继续, exit 1 = 阻塞（不应再派 implementer）
# review.md 单文件；review ≤ 2 轮（第 3 轮 → blocked，design §7.2 / RULES.md）
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
OP_PATHS_SCRIPT="${OP_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/scripts/op_paths.sh"
source "$OP_PATHS_SCRIPT"
op_load_paths "" "$ROOT"
TID="${1:?用法: op_implementer_check.sh <TID>}"
REVIEW_FILE="$OP_DOCS_ROOT/op_execution/tasks/$TID/review.md"

# 无 review.md 或无 verdict 行 → 首轮正向开发
if [ ! -f "$REVIEW_FILE" ] || ! grep -q '^verdict:' "$REVIEW_FILE" 2>/dev/null; then
    echo "mode: normal"
    echo "round: 1"
    exit 0
fi

# 先读末行 verdict（最后一行是权威裁决结果——本轮修复：不用全部 verdict 行计数，防 FAIL+PASS 误判）
last_verdict="$(grep -oE '^verdict:[[:space:]]*(PASS|FAIL)' "$REVIEW_FILE" | tail -1 | sed -E 's/.*verdict:[[:space:]]*//')"

# 末行 PASS → implementer 已完成，不应再派
if [ "$last_verdict" = "PASS" ]; then
    echo "mode: done"
    echo "round: 0"
    echo "# implementer 已完成（review 末行 verdict: PASS），不需再派"
    exit 0
fi

# 末行 FAIL → 统计 FAIL 行数决定模式
fail_count=$(grep -cE '^verdict:[[:space:]]*FAIL' "$REVIEW_FILE" || true)
next_round=$((fail_count + 1))

# 第 2 次 FAIL 后 blocked
if [ "$fail_count" -ge 2 ]; then
    echo "mode: blocked"
    echo "round: $next_round"
    exit 1
fi

echo "mode: fail"
echo "round: $next_round"
exit 0
