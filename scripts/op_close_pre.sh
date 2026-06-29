#!/usr/bin/env bash
# op_close_pre：收口前机械步骤（盖戳 + 状态）
# 用法: op_close_pre.sh <TID>
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TID="${1:?用法: op_close_pre.sh <TID>}"
SPEC_FILE="$ROOT/docs/omni_powers/op_execution/tasks/$TID/spec.md"
STAMP="> ⚠️ 历史快照，以 docs/omni_powers/op_blueprint/specs/ 为准。"

die() { echo "[FAIL] $*" >&2; exit 1; }

cd "$ROOT" || die "无法进入 repo root: $ROOT"
[ -f "$SPEC_FILE" ] || die "spec.md 不存在: $SPEC_FILE"

if ! grep -q "历史快照" "$SPEC_FILE"; then
    tmp_file="$(mktemp)" || die "创建临时文件失败"
    {
        printf '%s\n\n' "$STAMP"
        cat "$SPEC_FILE"
    } > "$tmp_file" || die "写入临时文件失败"
    mv "$tmp_file" "$SPEC_FILE" || die "更新 spec.md 失败"
fi

bash "$ROOT/scripts/op_status.sh" "$TID" 收口中 || die "更新状态失败: $TID → 收口中"

echo "[OK] close pre: $TID"
