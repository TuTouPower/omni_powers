#!/usr/bin/env bash
# op_closer_gate：closer 越界写入机械校验（design §2.6）
# 用法: op_closer_gate.sh <TID>
# Q5：只报不撤销——越界即告警 + exit 1，不自动 git checkout（防误删 closer 前已存在的 leader 合法改动）
# 越界改动保留，交 leader 决策（采纳/revert）
set -uo pipefail

TID="${1:?用法: op_closer_gate.sh <TID>}"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
OP_PATHS_SCRIPT="${OP_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/scripts/op_paths.sh"
source "$OP_PATHS_SCRIPT"
op_load_paths "" "$ROOT"
cd "$ROOT"

# closer 允许写的路径前缀（design §2.6 权限清单）
ALLOWED=(
  "$OP_DOCS_DIR/op_record/decisions.md"
  "$OP_DOCS_DIR/op_execution/issues/"
  "$OP_DOCS_DIR/op_execution/acceptance/${TID}/"
)

# 扫工作区改动（closer 产出）——只报告，不撤销
mapfile -t CHANGED < <(git status --porcelain | awk '{print $2}')

violation=0
for f in "${CHANGED[@]:-}"; do
  [ -z "$f" ] && continue
  ok=0
  for a in "${ALLOWED[@]}"; do
    case "$f" in
      "$a"*) ok=1; break ;;
    esac
  done
  if [ "$ok" -eq 0 ]; then
    echo "[FAIL] closer 越界写入: $f（允许：decisions.md / issues/ / acceptance/${TID}/）" >&2
    violation=1
  fi
done

if [ "$violation" -eq 1 ]; then
  echo "[FAIL] closer 越界，提案不进 leader 自审（design §2.6 / A18）。越界改动保留，交 leader 决策" >&2
  exit 1
fi
echo "[OK] closer 触碰路径均在白名单内（TID=$TID）"
