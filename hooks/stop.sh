#!/usr/bin/env bash
# Stop hook: 完成门禁
# - 检查 tasks_list.json 当前 task 状态
# - 验证 5 分钟内有新鲜测试证据文件
# 缺则拒收工

set -uo pipefail

checkpoint="docs/omni_powers/op_execution/leader_checkpoint.md"
tid="$(awk -F': *' '/^current_task:/{print $2; exit}' "$checkpoint" 2>/dev/null | tr -d ' ')"

# 无活跃 task → 放行
[ -z "$tid" ] && exit 0

tasks_dir="docs/omni_powers/op_execution/tasks/$tid"

# 找 5 分钟内的证据
evidence="$(find "$tasks_dir" -name 'test_evidence_*.log' -mmin -5 2>/dev/null | head -1)"
if [ -z "$evidence" ]; then
  echo "[Hook] BLOCKED: $tid 无 5 分钟内新鲜测试证据。跑测试产出证据后再收工。" >&2
  exit 2
fi

exit 0
