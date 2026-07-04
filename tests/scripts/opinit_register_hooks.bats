#!/usr/bin/env bats

# 测 opinit_register_hooks.sh（OP_HOME 校验 + hooks 合并 concat）

OP_HOME="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
  TEST_ROOT="$(mktemp -d)"
  cd "$TEST_ROOT"
}

teardown() {
  [ -n "${TEST_ROOT:-}" ] && [ -d "$TEST_ROOT" ] && rm -rf "$TEST_ROOT"
}

@test "opinit_register_hooks: OP_HOME 未设 die" {
  OP_HOME="" run bash "$OP_HOME/skills/opinit/scripts/opinit_register_hooks.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"未设 OP_HOME"* ]]
}

@test "opinit_register_hooks: OP_HOME 指向错（hooks 不存在）die" {
  OP_HOME="/nonexistent" run bash "$OP_HOME/skills/opinit/scripts/opinit_register_hooks.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"指向错误"* ]]
}

@test "opinit_register_hooks: 首次注册生成 .claude/settings.json 含 omni_powers hooks" {
  run bash "$OP_HOME/skills/opinit/scripts/opinit_register_hooks.sh"
  [ "$status" -eq 0 ]
  [ -f .claude/settings.json ]
  jq -e '.hooks.PreToolUse' .claude/settings.json >/dev/null
  jq -e '.hooks.SessionStart' .claude/settings.json >/dev/null
}

@test "opinit_register_hooks: concat 不覆盖用户已有 hooks" {
  mkdir -p .claude
  echo '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"user-formatter"}]}]}}' > .claude/settings.json
  run bash "$OP_HOME/skills/opinit/scripts/opinit_register_hooks.sh"
  [ "$status" -eq 0 ]
  # 用户 hook 保留 + omni_powers hook 追加（PreToolUse ≥2 条）
  count=$(jq '.hooks.PreToolUse | length' .claude/settings.json)
  [ "$count" -ge 2 ]
  # 用户 hook 保留（user-formatter 在 concat 后的 settings 里）
  grep -q "user-formatter" .claude/settings.json
  # 不写 env 段（OP_HOME 走全局，项目级无 OP_HOME）
  ! jq -e '.env.OP_HOME' .claude/settings.json >/dev/null 2>&1
}
