#!/usr/bin/env bash
# op-jq：tasks_list.json 通用查询
# 用法: op_jq.sh <query> [args...]
# 查询项:
#   pending              — 查所有待开始 task
#   deps <TID>           — 查某 task 的前置依赖是否全完成
#   blocked              — 查所有阻塞 task
#   skipped              — 查所有跳过 task
#   downstream <TID>     — 查某 task 的下游（谁依赖它）
#   status <TID>         — 查某 task 的 status
#   all                  — 全部 task 概览（id + status + depends_on）
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TASKS="$ROOT/docs/op_execution/tasks_list.json"
CMD="${1:?用法: op_jq.sh <pending|deps|blocked|skipped|downstream|status|all> [args...]}"
shift 2>/dev/null || true

case "$CMD" in
pending)
    jq '.tasks[] | select(.status=="待开始")' "$TASKS"
    ;;
deps)
    TID="${1:?用法: op_jq.sh deps <TID>}"
    DEPS=$(jq -r '.tasks[] | select(.id=="'"$TID"'") | .depends_on[]?' "$TASKS" 2>/dev/null || true)
    if [ -z "$DEPS" ]; then
        echo "无依赖"
        exit 0
    fi
    for d in $DEPS; do
        st=$(jq -r '.tasks[] | select(.id=="'"$d"'") | .status' "$TASKS")
        echo "$d: $st"
    done
    ;;
blocked)
    jq '.tasks[] | select(.status=="阻塞") | {id, blocked_by}' "$TASKS"
    ;;
skipped)
    jq '.tasks[] | select(.status=="跳过") | {id, title}' "$TASKS"
    ;;
downstream)
    TID="${1:?用法: op_jq.sh downstream <TID>}"
    jq --arg tid "$TID" '.tasks[] | select(.depends_on != null and (.depends_on | index($tid))) | .id' "$TASKS"
    ;;
status)
    TID="${1:?用法: op_jq.sh status <TID>}"
    jq -r '.tasks[] | select(.id=="'"$TID"'") | .status' "$TASKS"
    ;;
all)
    jq '[.tasks[] | {id, status, depends_on}]' "$TASKS"
    ;;
*)
    echo "用法: op_jq.sh <pending|deps|blocked|skipped|downstream|status|all> [args...]" >&2
    exit 1
    ;;
esac
