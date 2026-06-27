#!/usr/bin/env bash
# op-context-append：coder 完成后，在 context.md 顶部插入摘要
# 用法: echo "摘要内容" | op-context-append.sh <TID>
# 摘要写在 <!-- SUMMARY -->...<!-- /SUMMARY --> 之间
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TID="${1:?用法: echo '摘要' | op-context-append.sh <TID>}"
CTX="$ROOT/docs/omni_powers/op_execution/tasks/$TID/context.md"

summary=$(cat)

# 写新摘要到临时文件
{
    echo "<!-- SUMMARY -->"
    echo "## 摘要"
    echo "$summary"
    echo "<!-- /SUMMARY -->"
    echo ""
} > "/tmp/op_ctx_summary_$$.md"

if grep -q '<!-- SUMMARY -->' "$CTX" 2>/dev/null; then
    # 已有摘要：替换
    awk -v repl="$(cat /tmp/op_ctx_summary_$$.md)" '
        /^<!-- SUMMARY -->$/ { print repl; skip=1; next }
        /^<!-- \/SUMMARY -->$/ { skip=0; next }
        !skip
    ' "$CTX" > "/tmp/op_ctx_$$.md" && mv "/tmp/op_ctx_$$.md" "$CTX"
else
    # 首次：插在最前面
    cat "/tmp/op_ctx_summary_$$.md" "$CTX" > "/tmp/op_ctx_$$.md" && mv "/tmp/op_ctx_$$.md" "$CTX"
fi

rm -f "/tmp/op_ctx_summary_$$.md"
echo "[OK] 摘要已写入 context.md"
