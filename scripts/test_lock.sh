#!/usr/bin/env bash
# test_lock：锁定与解锁 e2e/** 与 BUG-* 行为层测试文件
# 用法:
#   bash scripts/test_lock.sh add <file>        # 锁定（evaluator 用）
#   bash scripts/test_lock.sh remove <file>     # 解锁（evaluator 用，leader 审批后）
#   bash scripts/test_lock.sh list              # 列锁定文件
#   bash scripts/test_lock.sh check <file>      # 检查是否锁定（exit 0=锁, 1=未锁）

set -euo pipefail   # #32: 加 -e（原仅 set -uo pipefail）

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

lockfile="docs/omni_powers/op_execution/.test_locks"
mkdir -p "$(dirname "$lockfile")"
touch "$lockfile"

# #33: flock 防并发 add/remove 重复或丢记录
exec 9>"$lockfile.lock"
flock 9

cmd="${1:?用法: test_lock.sh add|remove|list|check [file]}"
file="${2:-}"

rel() {
  local f="$1"
  echo "${f#$root/}"
}

case "$cmd" in
  add)
    [ -z "$file" ] && { echo "need file" >&2; exit 1; }
    r="$(rel "$file")"
    grep -qxF "$r" "$lockfile" || echo "$r" >> "$lockfile"
    echo "[OK] locked: $r"
    ;;
  remove)
    [ -z "$file" ] && { echo "need file" >&2; exit 1; }
    r="$(rel "$file")"
    grep -vxF "$r" "$lockfile" > "$lockfile.tmp" 2>/dev/null || true
    mv "$lockfile.tmp" "$lockfile"
    echo "[OK] unlocked: $r"
    ;;
  list)
    grep -v '^#' "$lockfile" 2>/dev/null | grep -v '^$' || echo "(none)"
    ;;
  check)
    [ -z "$file" ] && { echo "need file" >&2; exit 1; }
    r="$(rel "$file")"
    grep -qxF "$r" "$lockfile" 2>/dev/null && exit 0 || exit 1
    ;;
  *)
    echo "unknown cmd: $cmd" >&2
    exit 1
    ;;
esac
