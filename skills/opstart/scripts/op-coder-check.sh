#!/usr/bin/env bash
# op-coder-check：coder 启动时判断当前模式（正向开发 / FAIL 轮）和轮次
# 用法: op-coder-check.sh <TID>
# 输出: mode=normal|fail|blocked, round=1|2|3
# exit 0 = 可继续, exit 1 = 阻塞（不应再派 coder）
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TID="${1:?用法: op-coder-check.sh <TID>}"
TASK_DIR="$ROOT/docs/omni_powers/op_execution/tasks/$TID"

has_file() { [ -f "$TASK_DIR/$1" ] && return 0 || return 1; }

# 检查是否有 review 文件且有 verdict 行
has_review=false
for f in review_spec.md review_code.md review_test.md; do
    if has_file "$f" && grep -q 'verdict:' "$TASK_DIR/$f" 2>/dev/null; then
        has_review=true
        break
    fi
done

if ! $has_review; then
    echo "mode: normal"
    echo "round: 1"
    exit 0
fi

# 统计已有 review 轮次（三个文件取大值，按 verdict 行数算）
max_round=0
for f in review_spec.md review_code.md review_test.md; do
    if has_file "$f"; then
        r=$(grep -c '^verdict:' "$TASK_DIR/$f" 2>/dev/null || echo 0)
        [ "$r" -gt "$max_round" ] && max_round="$r"
    fi
done

next_round=$((max_round + 1))

if [ "$next_round" -gt 3 ]; then
    echo "mode: blocked"
    echo "round: $next_round"
    exit 1
fi

echo "mode: fail"
echo "round: $next_round"
exit 0
