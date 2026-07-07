#!/usr/bin/env bash
# op_close_pre：per-task 收口前机械步骤（标 status=收口中）
# 用法: op_close_pre.sh <TID>
# spec 在 specs/{TID}_{slug}.md（task:spec 1:1），per-task 不盖戳（approved spec 受写保护，per-task 碰会被自家 hook 拦）
set -euo pipefail

PLUGIN_ROOT="${OP_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
TID="${1:?用法: op_close_pre.sh <TID>}"

die() { echo "[FAIL] $*" >&2; exit 1; }

bash "$PLUGIN_ROOT/scripts/op_status.sh" "$TID" 收口中 || die "更新状态失败: $TID → 收口中"

echo "[OK] close pre: $TID（status=收口中）"
