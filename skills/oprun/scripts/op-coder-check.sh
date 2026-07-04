#!/usr/bin/env bash
# op_coder_check：implementer 启动时判断模式（正向/FAIL）和轮次
# 用法: op_coder_check.sh <TID>
# 输出: mode=normal|fail|blocked, round=1|2|3
# exit 0 = 可继续, exit 1 = 阻塞（不应再派 implementer）
# review.md 单文件；review ≤ 2 轮（第 3 轮 → blocked，design §7.2 / RULES.md）
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TID="${1:?用法: op_coder_check.sh <TID>}"
REVIEW_FILE="$ROOT/docs/omni_powers/op_execution/tasks/$TID/review.md"

# 无 review.md 或无 verdict 行 → 首轮正向开发
if [ ! -f "$REVIEW_FILE" ] || ! grep -q '^verdict:' "$REVIEW_FILE" 2>/dev/null; then
    echo "mode: normal"
    echo "round: 1"
    exit 0
fi

# 已有 review 轮次 = verdict 行数
max_round=$(grep -c '^verdict:' "$REVIEW_FILE" 2>/dev/null || echo 0)
next_round=$((max_round + 1))

# review ≤ 2 轮：第 3 轮 blocked
if [ "$next_round" -gt 2 ]; then
    echo "mode: blocked"
    echo "round: $next_round"
    exit 1
fi

echo "mode: fail"
echo "round: $next_round"
exit 0
