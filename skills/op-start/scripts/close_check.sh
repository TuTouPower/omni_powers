#!/usr/bin/env bash
# 收口 checklist 检查：leader 收口后跑，非 0 拦住不许进下一个 task
# 用法: close_check.sh <TID> [commit-hash]
# 检查项:
#   1. tech_debt.md 有本 task 段（含"无新增"）        → 必须通过
#   2. leader_checkpoint.md 含本 task                → 必须通过
#   3. 归档目录五件齐全                              → 必须通过
#   4. git status 非本 task 残留                     → 仅提醒，不拦
# 注意: 调用前 leader 应先审查 closer 产出并 commit，否则 git status 混入未提交项

set -euo pipefail

TID="${1:?用法: close_check.sh <TID> [commit-hash]}"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

fail=0
warn=0

echo "=== 收口检查: $TID ==="

# 1. tech_debt.md 必须有本 task 段（含"无新增"标注）
if grep -qE "^## ${TID}" docs/omni_powers/op_execution/tech_debt.md 2>/dev/null; then
    echo "[PASS] tech_debt.md 含 ${TID} 段"
elif grep -qE "${TID}.*无新增" docs/omni_powers/op_execution/tech_debt.md 2>/dev/null; then
    echo "[PASS] tech_debt.md 已标 ${TID} 无新增"
else
    echo "[FAIL] tech_debt.md 无 ${TID} 段，也未标'无新增'——必须追加（无债也要写一行)"
    fail=1
fi

# 2. leader_checkpoint.md 含本 task
if grep -q "$TID" docs/omni_powers/op_execution/leader_checkpoint.md 2>/dev/null; then
    echo "[PASS] leader_checkpoint.md 含 ${TID}"
else
    echo "[FAIL] leader_checkpoint.md 未更新 ${TID}"
    fail=1
fi

# 3. 归档目录五件齐全且非空
arch="docs/omni_powers/op_record/tasks/${TID}"
missing=()
for f in spec.md plan.md context.md review_code.md review_test.md; do
    [ -s "$arch/$f" ] || missing+=("$f")
done
if [ ${#missing[@]} -eq 0 ]; then
    echo "[PASS] 归档五件齐全且非空: $arch"
else
    echo "[FAIL] 归档缺或空: ${missing[*]}"
    fail=1
fi

# 3.1 spec.md 盖戳检查
if [ -s "$arch/spec.md" ]; then
    if grep -q "历史快照" "$arch/spec.md" 2>/dev/null; then
        echo "[PASS] spec.md 已盖戳"
    else
        echo "[FAIL] spec.md 未盖戳（缺少 '历史快照' 标记）"
        fail=1
    fi
fi

# 4. git status 提醒（非本 task 改动）——不拦，只报
task_dir="docs/omni_powers/op_execution/tasks/${TID}"
others=$(git status --short 2>/dev/null | grep -v "^[MADRC? ]\+ ${task_dir}" || true)
if [ -n "$others" ]; then
    echo "[WARN] git status 有非 ${TID} 的改动，leader 请检查是否本 task 残留或需 stash 隔离:"
    echo "$others" | sed 's/^/    /'
    warn=1
else
    echo "[PASS] git status 无非 ${TID} 改动"
fi

echo "=== 结果: $([ $fail -eq 0 ] && echo '通过' || echo '不通过')  (warn=$warn) ==="
exit $fail
