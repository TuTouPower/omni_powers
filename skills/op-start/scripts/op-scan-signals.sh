#!/usr/bin/env bash
# op-scan-signals：扫描 worktree 中的完成标记文件
# 用法: op-scan-signals.sh <TID>
# 输出: coder_done / reviews_done / none
#       (reviews_done = reviewer_code_done + reviewer_test_done 同时存在)
# exit 0=有信号, 1=无信号
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TID="${1:?用法: op-scan-signals.sh <TID>}"
SIGNALS="$ROOT/.worktrees/$TID/.omni_powers/signals"

cd "$SIGNALS" 2>/dev/null || { echo "none"; exit 1; }

has_code=false
has_code_review=false
has_test_review=false

[ -f coder_done ] && has_code=true
[ -f reviewer_code_done ] && has_code_review=true
[ -f reviewer_test_done ] && has_test_review=true

if $has_code_review && $has_test_review; then
    echo "reviews_done"
elif $has_code; then
    echo "coder_done"
else
    echo "none"
fi

exit 0
