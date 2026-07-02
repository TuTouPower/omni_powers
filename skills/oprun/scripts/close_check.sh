#!/usr/bin/env bash
# 收口 checklist 检查：leader 收口后跑，非 0 拦住不许进下一个 task
# 用法: close_check.sh <TID>
# 检查项:
#   1. leader_checkpoint.md 含本 task                → 必须通过
#   2. 归档目录三件齐全（brief/report/review）       → 必须通过
#   3. blueprint_update.md 已产                      → 必须通过
#   4. git status 非本 task 残留                     → 仅提醒，不拦
# 注意: 调用前 leader 应先审批 closer 提案、写入 op_blueprint 并 commit

set -uo pipefail

TID="${1:?用法: close_check.sh <TID>}"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

fail=0
warn=0

echo "=== 收口检查: $TID ==="

# 1. leader_checkpoint.md 含本 task
if grep -q "$TID" docs/omni_powers/op_execution/leader_checkpoint.md 2>/dev/null; then
    echo "[PASS] leader_checkpoint.md 含 ${TID}"
else
    echo "[FAIL] leader_checkpoint.md 未更新 ${TID}"
    fail=1
fi

# 2. 归档目录三件齐全且非空
arch="docs/omni_powers/op_record/tasks/${TID}"
missing=()
for f in brief.md report.md review.md; do
    [ -s "$arch/$f" ] || missing+=("$f")
done
if [ ${#missing[@]} -eq 0 ]; then
    echo "[PASS] 归档三件齐全且非空: $arch"
else
    echo "[FAIL] 归档缺或空: ${missing[*]}"
    fail=1
fi

# 3. blueprint_update.md 已产（closer 提案）
if [ -s "$arch/blueprint_update.md" ]; then
    echo "[PASS] blueprint_update.md 已产"
else
    echo "[FAIL] 缺 blueprint_update.md（closer 未产提案）"
    fail=1
fi

# 4. git status 提醒（非本 task 改动）——不拦，只报
task_arch="docs/omni_powers/op_record/tasks/${TID}"
others=$(git status --short 2>/dev/null | grep -v "^[MADRC? ]\+ ${task_arch}" || true)
if [ -n "$others" ]; then
    echo "[WARN] git status 有非 ${TID} 归档的改动，leader 请检查:"
    echo "$others" | sed 's/^/    /'
    warn=1
else
    echo "[PASS] git status 无非 ${TID} 改动"
fi

echo "=== 结果: $([ $fail -eq 0 ] && echo '通过' || echo '不通过')  (warn=$warn) ==="
exit $fail
