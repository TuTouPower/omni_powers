#!/usr/bin/env bash
# op_status（lite）：更新 tasks_list.json 中的 task 状态。无 OP_HOME 依赖。
# 用法:
#   op_status.sh <TID> <status> [blocked_by]
#   op_status.sh --batch <TID1,TID2,...> <status>
#
# lite 状态枚举（ASCII，去 heavy 的 closing——收口是 leader 瞬时操作）: pending ready in_progress reviewing done blocked obsolete suspended
# blocked_by 仅在 status=blocked 时填（resource/quality/spawn）
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TASKS_FILE="$ROOT/docs/omni_powers/op_execution/tasks_list.json"

die() { echo "[FAIL] $*" >&2; exit 1; }

batch=false
tids=""
status=""
blocked="null"

if [ "${1:-}" = "--batch" ]; then
    batch=true
    tids="${2:?用法: op_status.sh --batch <TID1,TID2,...> <status>}"
    status="${3:?缺少 status}"
    shift 3
else
    tid="${1:?用法: op_status.sh <TID> <status> [blocked_by]}"
    status="${2:?缺少 status}"
    blocked="${3:-null}"
    shift 2
fi

case "$status" in
    pending|ready|in_progress|reviewing|done|blocked|obsolete|suspended) ;;
    closing) die "lite 无 closing 态（收口是 leader 瞬时操作）；有效值: pending ready in_progress reviewing done blocked obsolete suspended" ;;
    *) die "无效 status: $status（有效值: pending ready in_progress reviewing done blocked obsolete suspended）" ;;
esac

if [ "$blocked" = "null" ] || [ -z "$blocked" ]; then
    blocked_json="null"
else
    case "$blocked" in resource|quality|spawn) ;;
        *) die "无效 blocked_by: $blocked（有效值: resource quality spawn）" ;;
    esac
    blocked_json="\"$blocked\""
fi

[ -f "$TASKS_FILE" ] || die "tasks_list.json 不存在: $TASKS_FILE"

LOCK_FILE="$TASKS_FILE.lock"
exec 3>"$LOCK_FILE"
if command -v flock >/dev/null 2>&1; then
    flock 3 || die "获取文件锁失败"
else
    echo "[WARN] flock 不可用（macOS/Git Bash），无锁写——串行执行并发风险低（Q8）" >&2
fi

if $batch; then
    tids_json=$(echo "$tids" | jq -R 'split(",")')
    jq --argjson tids "$tids_json" --arg status "$status" \
        '.tasks |= map(if .id as $id | $tids | index($id) then .status = $status | .blocked_by = null else . end)' \
        "$TASKS_FILE" > "$TASKS_FILE.tmp" || die "jq 执行失败"
    echo "[OK] $tids → $status"
else
    if [ "$status" = "blocked" ]; then
        [ "$blocked" != "null" ] && [ -n "$blocked" ] || die "status=blocked 必须提供 blocked_by（resource/quality/spawn）"
        jq --arg tid "$tid" --arg status "$status" --argjson blocked "$blocked_json" \
            '.tasks |= map(if .id == $tid then .status = $status | .blocked_by = $blocked else . end)' \
            "$TASKS_FILE" > "$TASKS_FILE.tmp" || die "jq 执行失败"
    else
        jq --arg tid "$tid" --arg status "$status" \
            '.tasks |= map(if .id == $tid then .status = $status | .blocked_by = null else . end)' \
            "$TASKS_FILE" > "$TASKS_FILE.tmp" || die "jq 执行失败"
    fi
    echo "[OK] $tid → $status"
    if [ "$status" = "blocked" ]; then
        echo "[INFO]   blocked_by=$blocked"
    fi
fi

mv "$TASKS_FILE.tmp" "$TASKS_FILE"
exec 3>&-
