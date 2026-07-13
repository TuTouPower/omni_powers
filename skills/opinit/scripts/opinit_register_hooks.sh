#!/usr/bin/env bash
# opinit_register_hooks：校验全局 OP_HOME + 合并 hooks 到使用方 .claude/settings.json
# 用法: 在使用方项目根跑 bash "$OP_HOME/skills/opinit/scripts/opinit_register_hooks.sh"
# OP_HOME 由用户全局 settings.json 设（一次性，所有项目共享，subagent 继承）。opinit 不写项目级 OP_HOME。
# 合并策略：按事件 concat 数组（不覆盖用户已有 hooks）。
# 同时写 OP_*_MODEL 四个 env 变量到项目级 settings.json（未设时填推荐默认值，已有值保留不覆盖）。
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
# jq 依赖（Windows 默认无，需手装）
command -v jq >/dev/null 2>&1 || {
  echo "[FAIL] jq 未装（合并 hooks 必需）。Windows: choco install jq 或 scoop install jq 或 https://jqlang.github.io/jq/download/；macOS: brew install jq" >&2
  exit 1
}
echo "[OK] 全局 OP_HOME=$OP_HOME（不写项目级，全局共享）"

# 2. 合并 hooks 配置到项目 .claude/settings.json（concat 数组，不覆盖用户已有 hooks，不碰 env）
#    macOS/Linux 用 bash 调 polyglot wrapper；Windows 生成直接 .cmd 绝对路径，确保 CLAUDE_CODE_GIT_BASH_PATH 能生效。
mkdir -p .claude
TEMPLATE_FILE="$OP_HOME/hooks/settings.template.json"
TMP_TEMPLATE=""
case "$(uname -s 2>/dev/null || true)" in
  MINGW*|MSYS*|CYGWIN*)
    if command -v cygpath >/dev/null 2>&1; then
      WRAPPER_PATH="$(cygpath -w "$OP_HOME/hooks/run-hook.cmd")"
    else
      WRAPPER_PATH="$OP_HOME/hooks/run-hook.cmd"
    fi
    TMP_TEMPLATE="$(mktemp)"
    jq --arg wrapper "$WRAPPER_PATH" '
      walk(
        if type == "object" and has("command") then
          .command |= sub("^bash \"\$OP_HOME/hooks/run-hook\.cmd\""; "\"" + $wrapper + "\"")
        else
          .
        end
      )
    ' "$OP_HOME/hooks/settings.template.json" > "$TMP_TEMPLATE"
    TEMPLATE_FILE="$TMP_TEMPLATE"
    ;;
esac
trap '[ -n "${TMP_TEMPLATE:-}" ] && rm -f "$TMP_TEMPLATE"' EXIT

if [ -f .claude/settings.json ]; then
  cp .claude/settings.json ".claude/settings.json.bak.$(date +%s)"
  jq -s '
    .[0] as $u | .[1] as $t
    | reduce ($t.hooks // {} | keys[]) as $k ($u;
        .hooks[$k] = (($u.hooks // {})[$k] // []) + (
          ($t.hooks // {})[$k] | map(select(. as $item |
            # 按 matcher + hooks[].command 组合判重（同 matcher 同 command 集 = 重复）
            ($item.hooks // [] | map(.command)) as $tc
            | (($u.hooks // {})[$k] // []
              | map(select(.matcher == $item.matcher) | .hooks // [] | map(.command))
              | add // []) as $uc
            | ($tc | map(. as $c | $uc | index($c)) | all(. != null)) | not
          ))
        )
      )
  ' .claude/settings.json "$TEMPLATE_FILE" > .claude/settings.json.tmp
  mv .claude/settings.json.tmp .claude/settings.json
else
  cp "$TEMPLATE_FILE" .claude/settings.json
fi
chmod +x "$OP_HOME/hooks/"*.sh "$OP_HOME/hooks/run-hook.cmd" 2>/dev/null
echo "[OK] hooks 已注册到项目 .claude/settings.json（OP_HOME 走全局 env）"

# 2.5 写 OP_*_MODEL 四个 env 变量到项目级 settings.json（未设时填默认值，已有值保留）
#    项目级覆盖全局——同一台机器上不同项目可配不同模型强度。
#    不设 = 继承主会话 /model，设了就按指定模型派发 sub agent。
#    默认值来自 common/performance.md 模型选择策略：
#      implementer: sonnet（主开发）  reviewer: opus（深推理）
#      evaluator: sonnet（验收）     closer: haiku（轻量频繁）
jq --arg im "${OP_IMPLEMENTER_MODEL:-sonnet}" \
   --arg rv "${OP_REVIEWER_MODEL:-opus}" \
   --arg ev "${OP_EVALUATOR_MODEL:-sonnet}" \
   --arg cl "${OP_CLOSER_MODEL:-haiku}" \
   '.env //= {}
    | .env.OP_IMPLEMENTER_MODEL //= $im
    | .env.OP_REVIEWER_MODEL //= $rv
    | .env.OP_EVALUATOR_MODEL //= $ev
    | .env.OP_CLOSER_MODEL //= $cl' \
   .claude/settings.json > .claude/settings.json.tmp
mv .claude/settings.json.tmp .claude/settings.json
im=$(jq -r '.env.OP_IMPLEMENTER_MODEL' .claude/settings.json)
rv=$(jq -r '.env.OP_REVIEWER_MODEL' .claude/settings.json)
ev=$(jq -r '.env.OP_EVALUATOR_MODEL' .claude/settings.json)
cl=$(jq -r '.env.OP_CLOSER_MODEL' .claude/settings.json)
echo "[OK] OP_*_MODEL 已写入项目 .claude/settings.json env"
echo ""
echo "  Sub Agent 模型分配（当前值，改法见下）："
echo "    implementer : $im     写代码 + 修复 FAIL"
echo "    reviewer    : $rv       双裁决：规格合规 + 测试可信"
echo "    evaluator   : $ev      真机验收 + E2E 固化"
echo "    closer      : $cl       收口提案（只 heavy）"
echo ""
echo "  修改方式：编辑项目 .claude/settings.json → env 段改对应值。"
echo "  可选值: haiku（快省）/ sonnet（均衡）/ opus（重推理）。"
echo "  删掉变量 = 该 agent 继承主会话当前 /model。"
echo "  不设全局 OP_*_MODEL，仅项目级覆盖——同机器不同项目可配不同强度。"
echo ""

# 3. 注册 git 层 hooks（heavy 专属：pre-commit spec 写保护 + commit-msg e2e trailer 校验）
#    绕过 Claude hook 对 subagent 失效问题（design §0.2 / op_decisions D18）。
#    复制到 .git/hooks/（不覆盖用户已有非 omni_powers hook），+x。
#    更新 omni_powers git hook 后需重跑 /opinit 同步。
if git_dir="$(git rev-parse --git-dir 2>/dev/null)"; then
    hooks_dir="$git_dir/hooks"
    mkdir -p "$hooks_dir"
    cp "$OP_HOME/scripts/op_paths.sh" "$hooks_dir/op_paths.sh"
    chmod +x "$hooks_dir/op_paths.sh"
    for gh in "$OP_HOME/hooks/git/"*; do
        [ -f "$gh" ] || continue
        name="$(basename "$gh")"
        if [ -e "$hooks_dir/$name" ] && ! grep -q "omni_powers" "$hooks_dir/$name" 2>/dev/null; then
            echo "[WARN] .git/hooks/$name 已存在且非 omni_powers 生成，跳过（不覆盖用户已有）" >&2
            continue
        fi
        cp "$gh" "$hooks_dir/$name"
        chmod +x "$hooks_dir/$name"
        echo "[OK] git hook 已注册: $name（spec 写保护 / e2e trailer 校验，绕过 subagent deny 失效）"
    done
else
    echo "[WARN] 非 git 仓库，跳过 git hooks 注册（pre-commit/commit-msg）" >&2
fi
