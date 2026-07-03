#!/usr/bin/env bash
# op_jq：tasks_list.json 通用查询
# 用法: op_jq.sh <query> [args...]
# 查询项:
#   pending              — 查所有待开始 task
#   pending_plan         — 查所有待规划 task
#   deps <TID>           — 查某 task 的前置依赖是否全完成
#   blocked              — 查所有阻塞 task
#   skipped              — 查所有跳过 task
#   suspended            — 查所有挂起 task
#   downstream <TID>     — 查某 task 的下游（谁依赖它）
#   status <TID>         — 查某 task 的 status
#   all                  — 全部 task 概览（id + status + depends_on）
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TASKS="$ROOT/docs/omni_powers/op_execution/tasks_list.json"
CMD="${1:?用法: op_jq.sh <pending|pending_plan|deps|blocked|skipped|suspended|downstream|status|all> [args...]}"
shift

case "$CMD" in
pending)
    jq '.tasks[] | select(.status=="待开始") | {id, title, status}' "$TASKS"
    ;;
pending_plan)
    jq '.tasks[] | select(.status=="待规划") | {id, title, status}' "$TASKS"
    ;;
deps)
    TID="${1:?用法: op_jq.sh deps <TID>}"
    DEPS=$(jq --arg tid "$TID" -r '.tasks[] | select(.id==$tid) | .depends_on[]?' "$TASKS" 2>/dev/null || true)
    if [ -z "$DEPS" ]; then
        echo "无依赖"
        exit 0
    fi
    has_unready=0
    for d in $DEPS; do
        st=$(jq --arg d "$d" -r '.tasks[] | select(.id==$d) | .status' "$TASKS")
        echo "$d: $st"
        # 未就绪 = 非完成（#22：原条件含冗余的 待规划/挂起 分支，等价于 st != 完成）
        if [ "$st" != "完成" ]; then
            has_unready=1
        fi
    done
    if [ "$has_unready" -eq 1 ]; then
        echo "[WARN] 存在未就绪的前置依赖"
    fi
    ;;
blocked)
    jq '.tasks[] | select(.status=="阻塞") | {id, title, status, blocked_by}' "$TASKS"
    ;;
skipped)
    jq '.tasks[] | select(.status=="跳过") | {id, title, status}' "$TASKS"
    ;;
suspended)
    jq '.tasks[] | select(.status=="挂起") | {id, title, status}' "$TASKS"
    ;;
downstream)
    TID="${1:?用法: op_jq.sh downstream <TID>}"
    jq --arg tid "$TID" -r '.tasks[] | select(.depends_on != null and (.depends_on | index($tid))) | .id' "$TASKS"
    ;;
status)
    TID="${1:?用法: op_jq.sh status <TID>}"
    jq --arg tid "$TID" -r '.tasks[] | select(.id==$tid) | .status' "$TASKS"
    ;;
all)
    jq '[.tasks[] | {id, status, depends_on}]' "$TASKS"
    ;;
*)
    echo "用法: op_jq.sh <pending|pending_plan|deps|blocked|skipped|suspended|downstream|status|all> [args...]" >&2
    exit 1
    ;;
esac
