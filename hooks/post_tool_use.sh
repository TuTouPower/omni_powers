#!/usr/bin/env bash
# PostToolUse hook: 代码/测试编辑后自动跑受影响测试，留机器证据
# 证据存 $OP_DOCS_DIR/op_execution/tasks/{TID}/test_evidence_*.log
# SubagentStop hook 校验 5 分钟内新鲜证据；本 hook 保留 60 分钟审计轨迹

set -uo pipefail

project_root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
op_paths_script="${OP_HOME:-}/scripts/op_paths.sh"
if [ -f "$op_paths_script" ]; then
  source "$op_paths_script"
  if ! op_load_paths "" "$project_root"; then
    echo "[Hook] BLOCKED: OP_DOCS_DIR 配置无效，保护性拒绝" >&2
    exit 2
  fi
else
  echo "[Hook] BLOCKED: $op_paths_script 缺失，无法解析 OP_DOCS_DIR" >&2
  exit 2
fi

input="$(cat)"
tool_name="$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null)"
[ "$tool_name" != "Edit" ] && [ "$tool_name" != "Write" ] && [ "$tool_name" != "MultiEdit" ] && exit 0

file_path="$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
[ -z "$file_path" ] && exit 0

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
rel="${file_path#$root/}"

# #20: 管理测试相关路径——src/** + tests/** + e2e/**（原仅 src/**，漏 tests/e2e 致 Stop 误伤 #19）
case "$rel" in
  src/*|tests/*) ;;
  *) op_is_e2e_path "$rel" || exit 0 ;;
esac

# 找当前 TID
checkpoint="$OP_EXECUTION_DIR/leader_checkpoint.md"
tid="$(awk '/^### current_task$/{f=1;next} /^### /{f=0} f&&NF{print;exit}' "$checkpoint" 2>/dev/null | tr -d ' ')"
[ -z "$tid" ] && exit 0

tasks_dir="$OP_EXECUTION_DIR/tasks/$tid"
mkdir -p "$tasks_dir"

# 检测测试命令
test_cmd=""
if [ -f "$root/package.json" ] && jq -e '.scripts.test' "$root/package.json" >/dev/null 2>&1; then
  test_cmd="npm test -- ${rel%.ts}.test.ts 2>/dev/null || npm test 2>/dev/null"
elif [ -f "$root/pytest.ini" ] || [ -d "$root/tests" ]; then
  test_cmd="pytest -q 2>/dev/null"
elif [ -n "${OP_TEST_COMMAND:-}" ]; then
  test_cmd="$OP_TEST_COMMAND 2>/dev/null"
fi
if [ -z "$test_cmd" ]; then
  # P1-6：无测试框架——写 NONE 标记，Stop 据此放行（不阻塞无测试项目）
  evidence="$tasks_dir/test_evidence_NONE.log"
  { echo "=== PostToolUse: 未识别测试入口（无 package.json/pytest/OP_TEST_COMMAND）==="; echo "file: $rel"; } > "$evidence" 2>&1
  exit 0
fi

ts="$(date +%Y%m%d_%H%M%S 2>/dev/null || echo manual)"
evidence="$tasks_dir/test_evidence_${ts}.log"
{
  echo "=== PostToolUse test evidence ==="
  echo "file: $rel"
  echo "tid: $tid"
  echo "time: $ts"
  echo "cmd: $test_cmd"
  echo "--- output ---"
  eval "$test_cmd" 2>&1 | head -200
  echo "--- exit: $? ---"
} > "$evidence" 2>&1

# 清理旧证据：保留 60 分钟审计轨迹（Stop hook 只认 5 分钟内新鲜，#47）
find "$tasks_dir" -name 'test_evidence_*.log' -mmin +60 -delete 2>/dev/null

exit 0
