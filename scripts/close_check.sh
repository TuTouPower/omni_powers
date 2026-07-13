#!/usr/bin/env bash
# close_check：per-task 收口后 checklist，leader 跑，非 0 拦住不许进下一个 task
# 用法: close_check.sh <TID>
# 检查项（per-task 收口）:
#   1. tasks_list.json 该 task status=done           → 必须通过（唯一真相源）
#   2. 归档目录二件齐全（report/review）       → 必须通过
#   3. git status 非本 task 残留                     → 仅提醒，不拦
# 注意: closer per-task 一段式已产 blueprint_update（验收后，design §2.4）；不查 spec.md（task:spec 1:1 各自独立）

set -uo pipefail

TID="${1:?用法: close_check.sh <TID>}"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
OP_PATHS_SCRIPT="${OP_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/scripts/op_paths.sh"
source "$OP_PATHS_SCRIPT"
op_load_paths "" "$ROOT"
cd "$ROOT"

fail=0
warn=0

echo "=== per-task 收口检查: $TID ==="

# 1. tasks_list.json 该 task status=done（唯一真相源）
status=$(jq -r ".tasks[] | select(.id == \"$TID\") | .status" "$OP_DOCS_ROOT/op_execution/tasks_list.json" 2>/dev/null)
if [ "$status" = "done" ]; then
    echo "[PASS] tasks_list.json 标 ${TID} done"
else
    echo "[FAIL] tasks_list.json 未标 ${TID} done（当前: ${status:-未找到}）"
    fail=1
fi

# 2. 归档目录二件齐全且非空
arch="$OP_DOCS_DIR/op_record/tasks/${TID}"
missing=()
for f in report.md review.md; do
    [ -s "$arch/$f" ] || missing+=("$f")
done
if [ ${#missing[@]} -eq 0 ]; then
    echo "[PASS] 归档二件齐全且非空: $arch"
else
    echo "[FAIL] 归档缺或空: ${missing[*]}"
    fail=1
fi

# 3. git status 提醒（非本 task 改动）——不拦，只报
others=$(git status --short 2>/dev/null | grep -v "^[MADRC? ]\+ ${arch}" || true)
if [ -n "$others" ]; then
    echo "[WARN] git status 有非 ${TID} 归档的改动，leader 请检查:"
    echo "$others" | sed 's/^/    /'
    warn=1
else
    echo "[PASS] git status 无非 ${TID} 改动"
fi

echo "=== 结果: $([ $fail -eq 0 ] && echo '通过' || echo '不通过')  (warn=$warn) ==="
exit $fail
