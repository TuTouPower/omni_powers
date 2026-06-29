#!/usr/bin/env bash
# op-context-read：leader 用，只读 context.md 的摘要部分（不读完整 context）
# 用法: op-context-read.sh <TID>
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TID="${1:?用法: op-context-read.sh <TID>}"
CTX="$ROOT/docs/omni_powers/op_execution/tasks/$TID/context.md"

if [ ! -f "$CTX" ]; then
    echo "状态: 无 context.md"
    exit 0
fi

if grep -q '<!-- SUMMARY -->' "$CTX" 2>/dev/null; then
    awk '/^<!-- SUMMARY -->$/ { print; skip=0; next } /^<!-- \/SUMMARY -->$/ { print; exit } skip' "$CTX"
else
    echo "[WARN] context.md 无摘要标记，显示全文前5行："
    head -5 "$CTX"
fi
