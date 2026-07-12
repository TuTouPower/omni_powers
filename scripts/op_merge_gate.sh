#!/usr/bin/env bash
# op_merge_gate.sh: 主分支回流写入硬底线（design §3.4——安全模型的生效点）
#
# 为什么这是唯一硬底线：pre-commit 拦不住 subagent（hook 失效）、implementer 在自己
# 分支上 git 层保护全失效、sparse-checkout 只防无意耦合（object store 共享可绕）。
# 链条推到底——唯一在被监督者控制之外的检查点 = leader 把 task 分支合回主分支的时刻。
#
# 用法: op_merge_gate.sh <TID> <task_branch> [base_branch]
#   base_branch 缺省自动探测 main/master
# 退出码: 0=PASS(许合)  1=REJECT(拒合)  2=参数/环境错
#
# 校验（全 PASS 才 exit 0）：
#   1. task 分支实际 diff（相对 merge-base）每个文件命中白名单：
#        workset ∪ tasks/{TID}/report.md ∪ 结构层测试（*.test.* / *.spec.* / *_test.*，排除 e2e/）
#   2. 受保护路径黑名单二次确认（op_blueprint / op_record / specs / review.md /
#        tasks_list.json / issues / progress.md / checkpoint / e2e/）——命中即 REJECT
#   3. review verdict PASS 存在（主分支 tasks/{TID}/review.md 末行）

set -uo pipefail

TID="${1:?用法: op_merge_gate.sh <TID> <task_branch> [base_branch]}"
BRANCH="${2:?缺少 task_branch}"
BASE="${3:-}"

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || { echo "[FATAL] 无法进入 repo root: $ROOT" >&2; exit 2; }

die_env() { echo "[FATAL] $*" >&2; exit 2; }
reject()  { echo "[REJECT] $*" >&2; }

command -v jq >/dev/null 2>&1 || die_env "jq 不可用（merge gate 需读 tasks_list.json workset）"
git show-ref --verify --quiet "refs/heads/$BRANCH" 2>/dev/null || die_env "task 分支不存在: $BRANCH"

# ── 探测主分支 ──
if [ -z "$BASE" ]; then
    for b in main master; do
        if git show-ref --verify --quiet "refs/heads/$b" 2>/dev/null; then BASE="$b"; break; fi
    done
    [ -n "$BASE" ] || die_env "无法探测主分支（main/master 均不存在），请显式传 base_branch"
fi
git show-ref --verify --quiet "refs/heads/$BASE" 2>/dev/null || die_env "主分支不存在: $BASE"

# ── 算 task 分支相对主分支的实际改动集（直接 diff 两 tip，不依赖 merge-base）──
# 用 tip-to-tip 而非 merge-base：支持 P0 模型（feat/op-dev 跨 task 复用）。
# merge-base 在 squash-merge 后不前进（task 分支 commit SHA 不在主分支），
# 导致前 task 文件出现在 diff 中、被后 task 的 workset 误判越界。
mapfile -t CHANGED < <(git diff --name-only "$BASE" "$BRANCH" 2>/dev/null)

if [ "${#CHANGED[@]}" -eq 0 ]; then
    echo "[WARN] task 分支相对 $BASE 无改动（空 diff）——无需 merge gate，但也无东西可合" >&2
    exit 0
fi

# ── 读 workset（tasks_list.json）──
TASKS_FILE="$ROOT/docs/omni_powers/op_execution/tasks_list.json"
[ -f "$TASKS_FILE" ] || die_env "tasks_list.json 不存在: $TASKS_FILE"
mapfile -t WORKSET < <(jq -r --arg tid "$TID" '.tasks[] | select(.id==$tid) | .workset // [] | .[]' "$TASKS_FILE" 2>/dev/null)

# ── 受保护路径黑名单（design §3.4：其余一律 REJECT，黑名单做显式二次确认）──
# 前缀匹配；命中即拒，走专属通道（spec 变更子流程 / e2e leader 入口 / closer 提案）
PROTECTED=(
    "docs/omni_powers/op_blueprint/"
    "docs/omni_powers/op_record/"
    "docs/omni_powers/op_execution/specs/"
    "docs/omni_powers/op_execution/issues/"
    "docs/omni_powers/op_execution/tasks_list.json"
    "docs/omni_powers/op_execution/leader_checkpoint.md"
    "e2e/"
    "docs/omni_powers/e2e/"
    "tests/e2e/"
    "tests/"*"/e2e/"
)

# review.md 单独判（在 tasks/{TID}/ 下，但同目录 report.md 是白名单——精确匹配路径）
REVIEW_PATH="docs/omni_powers/op_execution/tasks/$TID/review.md"
REPORT_PATH="docs/omni_powers/op_execution/tasks/$TID/report.md"

# ── 结构层测试判定：*.test.* / *.spec.* / *_test.* 且不在 e2e/ 下 ──
is_struct_test() {
    local f="$1"
    case "$f" in
        e2e/*|*/e2e/*) return 1 ;;  # e2e 不算结构层
    esac
    case "$f" in
        *.test.*|*.spec.*|*_test.*|*_test) return 0 ;;
        */tests/*|tests/*) return 0 ;;  # tests/ 目录下的实现侧测试
    esac
    return 1
}

in_workset() {
    local f="$1" w
    for w in "${WORKSET[@]:-}"; do
        [ -z "$w" ] && continue
        [ "$f" = "$w" ] && return 0
    done
    return 1
}

is_protected() {
    local f="$1" p
    [ "$f" = "$REVIEW_PATH" ] && return 0  # review.md 受保护（leader 主分支单写）
    for p in "${PROTECTED[@]}"; do
        case "$f" in "$p"*) return 0 ;; esac
    done
    return 1
}

# ── 逐文件裁决 ──
violation=0
for f in "${CHANGED[@]}"; do
    [ -z "$f" ] && continue

    # 先判受保护黑名单（优先级最高，命中即拒——即使巧合在 workset 也拒，防越权）
    if is_protected "$f"; then
        reject "受保护路径 task 分支禁改: $f（走专属通道：spec 变更 / e2e leader 入口 / closer 提案）"
        violation=1
        continue
    fi

    # 白名单：report.md ∪ workset ∪ 结构层测试
    if [ "$f" = "$REPORT_PATH" ]; then continue; fi
    if in_workset "$f"; then continue; fi
    if is_struct_test "$f"; then continue; fi

    # 未命中任何白名单 = 工作集越界（advisory 升硬）
    reject "工作集越界: $f 不在 workset ∪ report.md ∪ 结构层测试白名单（TID=$TID）"
    violation=1
done

# ── review verdict PASS 校验（读主分支 review.md 末行）──
# 从主分支树读（非工作区），确保读的是 leader 落盘的权威副本
review_verdict="$(git show "$BASE:$REVIEW_PATH" 2>/dev/null | grep -oE '^verdict:[[:space:]]*(PASS|FAIL)' | tail -1 | sed -E 's/.*verdict:[[:space:]]*//' || true)"
if [ -z "$review_verdict" ]; then
    reject "review verdict 缺失（主分支 $REVIEW_PATH 无 verdict 末行）——reviewer 双裁决未落盘"
    violation=1
elif [ "$review_verdict" != "PASS" ]; then
    reject "review 未 PASS（$review_verdict）——双裁决未通过不许合"
    violation=1
fi

if [ "$violation" -eq 1 ]; then
    echo "[REJECT] merge gate 拒绝 $TID（$BRANCH → $BASE）：见上方越界项。task 分支修正后重跑" >&2
    exit 1
fi

echo "[OK] merge gate PASS: $TID（$BRANCH → $BASE）"
echo "[OK]   改动 ${#CHANGED[@]} 文件全在白名单，review verdict=PASS，许 squash-merge"
