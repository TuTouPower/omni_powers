#!/usr/bin/env bash
# op_closer_gate：closer 越界写入机械校验（design §2.6）
# 用法: op_closer_gate.sh <TID>
# 校验本次 closer 触碰路径 ⊆ { op_record/decisions.md, op_execution/issues/, op_execution/acceptance/{TID}/ }
# 越界 → git checkout 撤销 + 告警，提案不进 leader 自审（A18）
# 一个 git status --porcelain 对照脚本的成本——closer 是四角色权限最大约束最少的，唯一机械拦截点
set -uo pipefail

TID="${1:?用法: op_closer_gate.sh <TID>}"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

# closer 允许写的路径前缀（design §2.6 权限清单）
ALLOWED=(
  "docs/omni_powers/op_record/decisions.md"
  "docs/omni_powers/op_execution/issues/"
  "docs/omni_powers/op_execution/acceptance/${TID}/"
)

# 扫工作区改动（未 commit 的 closer 产出）
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
    git checkout -- "$f" 2>/dev/null && echo "[REVERT] 已撤销 $f" >&2
    violation=1
  fi
done

if [ "$violation" -eq 1 ]; then
  echo "[FAIL] closer 越界，提案不进 leader 自审（design §2.6 / A18）" >&2
  exit 1
fi
echo "[OK] closer 触碰路径均在白名单内（TID=$TID）"
chmod +x "$0" 2>/dev/null || true
