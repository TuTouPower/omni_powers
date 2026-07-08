#!/usr/bin/env bash
# op_jq（lite）：tasks_list.json 通用查询。读相对项目路径，无 OP_HOME 依赖。
# 用法: op_jq.sh <query> [args...]
#   pending | pending_plan | deps <TID> | blocked | obsolete | suspended
#   downstream <TID> | status <TID> | all
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TASKS="$ROOT/docs/omni_powers/op_execution/tasks_list.json"
CMD="${1:?用法: op_jq.sh <pending|pending_plan|deps|blocked|obsolete|suspended|downstream|status|all> [args...]}"
shift

case "$CMD" in
pending)
    jq '.tasks[] | select(.status=="ready") | {id, title, status}' "$TASKS"
    ;;
pending_plan)
    jq '.tasks[] | select(.status=="pending") | {id, title, status}' "$TASKS"
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
        if [ "$st" != "done" ]; then
            has_unready=1
        fi
    done
    if [ "$has_unready" -eq 1 ]; then
        echo "[WARN] 存在未就绪的前置依赖"
    fi
    ;;
blocked)
    jq '.tasks[] | select(.status=="blocked") | {id, title, status, blocked_by}' "$TASKS"
    ;;
obsolete)
    jq '.tasks[] | select(.status=="obsolete") | {id, title, status}' "$TASKS"
    ;;
suspended)
    jq '.tasks[] | select(.status=="suspended") | {id, title, status}' "$TASKS"
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
    echo "用法: op_jq.sh <pending|pending_plan|deps|blocked|obsolete|suspended|downstream|status|all> [args...]" >&2
    exit 1
    ;;
esac
