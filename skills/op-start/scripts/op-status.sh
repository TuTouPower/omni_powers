#!/usr/bin/env bash
# op-status：更新 tasks_list.json 中的 task 状态
# 用法:
#   op-status <TID> <status> [blocked_by]         单 task
#   op-status --batch <TID1,TID2,...> <status>     批量 task（同状态）
#
# status 有效值: 待开始 进行中 审阅中 收口中 完成 阻塞 跳过
# blocked_by 仅在 status=阻塞 时填写 (key/domain/quality/spawn)，其余留空
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TASKS_FILE="$ROOT/docs/harness_execution/tasks_list.json"

die() { echo "[FAIL] $*" >&2; exit 1; }

# ── 参数解析 ──

batch=false
tids=""
status=""
blocked="null"

if [ "${1:-}" = "--batch" ]; then
    batch=true
    tids="${2:?用法: op-status --batch <TID1,TID2,...> <status>}"
    status="${3:?缺少 status}"
    shift 3
else
    tid="${1:?用法: op-status <TID> <status> [blocked_by]}"
    status="${2:?缺少 status}"
    blocked="${3:-null}"
    shift 2
fi

# ── 校验 status ──

case "$status" in
    待开始|进行中|审阅中|收口中|完成|阻塞|跳过) ;;
    *) die "无效 status: $status（有效值: 待开始 进行中 审阅中 收口中 完成 阻塞 跳过）" ;;
esac

# blocked_by 映射到 JSON null / string
if [ "$blocked" = "null" ] || [ -z "$blocked" ]; then
    blocked_json="null"
else
    case "$blocked" in key|domain|quality|spawn) ;;
        *) die "无效 blocked_by: $blocked（有效值: key domain quality spawn）" ;;
    esac
    blocked_json="\"$blocked\""
fi

[ -f "$TASKS_FILE" ] || die "tasks_list.json 不存在: $TASKS_FILE"

# ── 构造 jq ──

if $batch; then
    # 逗号分隔 → JSON 数组
    tids_json=$(echo "$tids" | jq -R 'split(",")')
    jq --argjson tids "$tids_json" --arg status "$status" \
        '.tasks |= map(if .id as $id | $tids | index($id) then .status = $status | .blocked_by = null else . end)' \
        "$TASKS_FILE" > "$TASKS_FILE.tmp" || die "jq 执行失败"
    echo "[OK] $tids → $status"
else
    # 阻塞需要同时设 blocked_by
    if [ "$status" = "阻塞" ]; then
        jq --arg tid "$tid" --arg status "$status" --argjson blocked "$blocked_json" \
            '.tasks |= map(if .id == $tid then .status = $status | .blocked_by = $blocked else . end)' \
            "$TASKS_FILE" > "$TASKS_FILE.tmp" || die "jq 执行失败"
    else
        jq --arg tid "$tid" --arg status "$status" \
            '.tasks |= map(if .id == $tid then .status = $status | .blocked_by = null else . end)' \
            "$TASKS_FILE" > "$TASKS_FILE.tmp" || die "jq 执行失败"
    fi
    echo "[OK] $tid → $status"
    if [ "$status" = "阻塞" ]; then
        echo "[INFO]   blocked_by=$blocked"
    fi
fi

mv "$TASKS_FILE.tmp" "$TASKS_FILE"
