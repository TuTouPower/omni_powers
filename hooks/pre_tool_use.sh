#!/usr/bin/env bash
# PreToolUse hook: 统一守门
# - e2e/** 与 BUG-* 测试锁：feat/refactor/perf task 执行期行为层全锁
# - spec 写保护：approved/in_progress 状态的 spec 文件拦截
# - closer 对 op_blueprint/ 无写权（靠 spec 写保护覆盖，closer 也在阻断范围）
# - 行级敏感度：测试文件改 expect/assert 行需说明理由（警告层，不硬阻断）
# - Bash: 拦 --no-verify 与危险 git 重置
#
# 输入：stdin 收到 JSON，含 tool_name + tool_input
# 输出：exit 0 放行；exit 2 阻断（stderr 给模型看）；其他 exit 放行但不报

set -uo pipefail

input="$(cat)"
tool_name="$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null)"

# --- Bash 守门 ---
if [ "$tool_name" = "Bash" ]; then
  cmd="$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)"
  if echo "$cmd" | grep -qE '(^|[[:space:]])--no-verify([[:space:]]|$)'; then
    echo "[Hook] BLOCKED: 禁止 --no-verify，pre-commit hook 是质量门" >&2
    exit 2
  fi
  if echo "$cmd" | grep -qE 'git\s+(reset\s+--hard|push\s+--force|push\s+-f|clean\s+-fd|checkout\s+--\s+\.)'; then
    echo "[Hook] BLOCKED: 危险 git 操作，需用户明确授权" >&2
    exit 2
  fi
  exit 0
fi

# --- Edit/Write 守门 ---
if [ "$tool_name" != "Edit" ] && [ "$tool_name" != "Write" ] && [ "$tool_name" != "MultiEdit" ]; then
  exit 0
fi

# 取目标路径（Edit/Write 在 file_path，MultiEdit 在 file_path）
file_path="$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
[ -z "$file_path" ] && exit 0

# 相对化
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
rel="${file_path#$root/}"

# --- spec 写保护：op_blueprint/** 下 approved/in_progress 的 spec 拦截 ---
case "$rel" in
  docs/omni_powers/op_blueprint/specs/*.md|docs/omni_powers/op_blueprint/*.md|docs/omni_powers/op_blueprint/baselines/*)
    if [ -f "$file_path" ]; then
      status="$(awk -F': *' '/^status:/{print $2; exit}' "$file_path" 2>/dev/null | tr -d ' ')"
      if [ "$status" = "approved" ] || [ "$status" = "in_progress" ]; then
        echo "[Hook] BLOCKED: $rel 状态=$status，受写保护。改 spec 走变更子流程（人批）。" >&2
        exit 2
      fi
    fi
    # blueprint 写保护：subagent 拦，主会话放行
    # 不再依赖 OP_LEADER_WRITE 环境变量（主会话 env 难热加载，leader 卡死）
    # 主会话（无 agent_type）= leader = 人控，写 blueprint 是合法操作（基于 closer 提案 / leader 自审，A18）
    # subagent（有 agent_type）写 op_blueprint 靠 worktree 结构隔离（D18，hook 对 subagent 失效，此拦截留痕）
    agent_type="$(echo "$input" | jq -r '.agent_type // empty' 2>/dev/null)"
    if [ -n "$agent_type" ]; then
      echo "[Hook] BLOCKED: $rel op_blueprint/ subagent 不可写（leader 基于 closer 提案写）。subagent 隔离靠 worktree（D18）。" >&2
      exit 2
    fi
    ;;
esac

# --- e2e/** 与 BUG-* 行为层测试锁（advisory：仅主会话 leader 场景生效；subagent deny 失效，靠 worktree 对称 + git 层，design §10 / op_decisions.md D18）---
case "$rel" in
  e2e/*|*BUG-*)
    # 行为层归 evaluator；implementer worktree 不挂 e2e/（结构隔离）
    # 本 hook 仅主会话拦（防 leader 误写 e2e）；evaluator/implementer 是 subagent，deny 不生效
    echo "[Hook] BLOCKED: $rel 是行为层测试（e2e/BUG-*），归 op-evaluator。主会话门禁；subagent 靠 worktree 结构隔离。" >&2
    exit 2
    ;;
esac

# --- 行级敏感度：测试文件改 expect/assert 警告层（不阻断，留痕） ---
case "$rel" in
  *.test.*|*spec/*|tests/*)
    if [ "$tool_name" = "Edit" ]; then
      old="$(echo "$input" | jq -r '.tool_input.old_string // empty' 2>/dev/null)"
      new="$(echo "$input" | jq -r '.tool_input.new_string // empty' 2>/dev/null)"
      if echo "$old$new" | grep -qE '(expect\(|assert|toBe|toContain|\.skip|\.only)'; then
        echo "[Hook] WARN: $rel 触碰 expect/assert 行。须有红灯归因（实现 bug/测试写错/规格变了）。" >&2
        # 警告层不阻断
      fi
    fi
    ;;
esac

exit 0
