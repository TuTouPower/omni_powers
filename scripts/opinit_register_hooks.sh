#!/usr/bin/env bash
# opinit_register_hooks：校验全局 OP_HOME + 合并 hooks 到使用方 .claude/settings.json
# 用法: 在使用方项目根跑 bash "$OP_HOME/scripts/opinit_register_hooks.sh"
# OP_HOME 由用户全局 settings.json 设（一次性，所有项目共享，subagent 继承）。opinit 不写项目级 OP_HOME。
# 合并策略：按事件 concat 数组（不覆盖用户已有 hooks），不碰 env 段。
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

# 1. 校验全局 OP_HOME 已设 + 指向正确（不写项目级）
[ -n "${OP_HOME:-}" ] || {
  echo "[FAIL] 全局 settings.json 未设 OP_HOME。请在全局配置（如 ~/.claude/settings.json）env 段加 \"OP_HOME\": \"/path/to/omni_powers\"，重启 Claude Code 后重跑 /opinit" >&2
  exit 1
}
[ -d "$OP_HOME/hooks" ] || {
  echo "[FAIL] \$OP_HOME/hooks 不存在（OP_HOME=$OP_HOME 指向错误，应为 omni_powers 仓库根）" >&2
  exit 1
}
echo "[OK] 全局 OP_HOME=$OP_HOME（不写项目级，全局共享）"

# 2. 合并 hooks 配置到项目 .claude/settings.json（concat 数组，不覆盖用户已有 hooks，不碰 env）
#    hook command 用 $OP_HOME/hooks/run-hook.cmd（polyglot wrapper，Claude Code 跑时从全局 env 展开 $OP_HOME）
mkdir -p .claude
if [ -f .claude/settings.json ]; then
  cp .claude/settings.json ".claude/settings.json.bak.$(date +%s)"
  jq -s '
    .[0] as $u | .[1] as $t
    | reduce ($t.hooks // {} | keys[]) as $k ($u;
        .hooks[$k] = (($u.hooks // {})[$k] // []) + ($t.hooks // {})[$k]
      )
  ' .claude/settings.json "$OP_HOME/hooks/settings.template.json" > .claude/settings.json.tmp
  mv .claude/settings.json.tmp .claude/settings.json
else
  cp "$OP_HOME/hooks/settings.template.json" .claude/settings.json
fi
chmod +x "$OP_HOME/hooks/"*.sh "$OP_HOME/hooks/run-hook.cmd" 2>/dev/null
echo "[OK] hooks 已注册到项目 .claude/settings.json（OP_HOME 走全局 env）"
