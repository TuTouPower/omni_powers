# omni_powers 通用化方案

## 问题

Skill 内引用的脚本、模板、文档都是相对于 omni_powers 项目根目录的路径。当用户在**其他项目**中调用 `/op-start` 时，`bash skills/op-start/scripts/op-status.sh` 解析到的是**那个项目**下的路径，不存在。

同理，agent 使用的模型（haiku/sonnet）、生成文件的目录名（`docs/op_execution/`）都硬编码在各处，用户无法自定义。

## 方案总览

```
用户 git clone omni_powers
        │
        ▼
  ./install.sh
        │
        ├─ 检测 omni_powers 位置 → 写入 ~/.config/omni_powers/config.yaml
        ├─ 写入 SessionStart hook 到 ~/.claude/settings.json
        └─ 创建 symlink: ~/.claude/skills/op-* → omni_powers/skills/op-*

每次 Claude Code 启动
        │
        ▼
  SessionStart hook 触发
        │
        ├─ 读取 ~/.config/omni_powers/config.yaml
        └─ 注入环境变量: OMNI_POWERS_ROOT, OMNI_POWERS_MODEL_*, OMNI_POWERS_DIR_*

Skill / Agent 运行时
        │
        ├─ 脚本路径: bash $OMNI_POWERS_ROOT/skills/op-start/scripts/op-status.sh
        ├─ 文档路径: Read $OMNI_POWERS_ROOT/RULES.md
        ├─ 模型选择: Agent({ model: "$OMNI_POWERS_MODEL_CODER" })
        └─ 目录名:   $OMNI_POWERS_DIR_TASKS/${TID}/spec.md
```

### 为什么不走插件系统

Superpowers 依赖 Claude Code 插件机制（`CLAUDE_PLUGIN_ROOT` 环境变量由平台注入）。但插件系统要求 `CLAUDE_CODE_PLUGINS` 配置和特定目录结构，且用户安装插件需要 /plugin 命令或 marketplace。

我们的方案不依赖插件系统，用最基础的 hook + env 机制，兼容任何 Claude Code 版本。用户只需 clone + 运行 install.sh。

## 配置文件

### `~/.config/omni_powers/config.yaml`

```yaml
# install.sh 自动写入，用户可手动修改

omni_powers_root: /home/user/karson_ubuntu/omni_powers

models:
  coder: haiku
  code_reviewer: sonnet
  test_reviewer: sonnet
  closer: haiku

dirs:
  tasks: docs/op_execution
  blueprint: docs/op_blueprint
  record: docs/op_record
```

| 字段 | 说明 |
|---|---|
| `omni_powers_root` | omni_powers 安装绝对路径，install.sh 自动填入 |
| `models.coder` | 写代码的模型 |
| `models.code_reviewer` | 代码审查的模型 |
| `models.test_reviewer` | 测试审查的模型 |
| `models.closer` | 收口的模型 |
| `dirs.tasks` | task 工作区目录（相对于用户项目根） |
| `dirs.blueprint` | 蓝图文档目录 |
| `dirs.record` | 记录归档目录 |

### SessionStart hook（写入 `~/.claude/settings.json`）

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/.config/omni_powers/hooks/session-start.sh"
          }
        ]
      }
    ]
  }
}
```

### `~/.config/omni_powers/hooks/session-start.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="$HOME/.config/omni_powers/config.yaml"

# 用 awk 简易解析 yaml（无外部依赖）
OMNI_POWERS_ROOT=$(awk '/^omni_powers_root:/ {print $2}' "$CONFIG_FILE")
OMNI_POWERS_MODEL_CODER=$(awk '/^models:/{f=1} f&&/coder:/{print $2;exit}' "$CONFIG_FILE")
OMNI_POWERS_MODEL_CODE_REVIEWER=$(awk '/^models:/{f=1} f&&/code_reviewer:/{print $2;exit}' "$CONFIG_FILE")
OMNI_POWERS_MODEL_TEST_REVIEWER=$(awk '/^models:/{f=1} f&&/test_reviewer:/{print $2;exit}' "$CONFIG_FILE")
OMNI_POWERS_MODEL_CLOSER=$(awk '/^models:/{f=1} f&&/closer:/{print $2;exit}' "$CONFIG_FILE")
OMNI_POWERS_DIR_TASKS=$(awk '/^dirs:/{f=1} f&&/tasks:/{print $2;exit}' "$CONFIG_FILE")
OMNI_POWERS_DIR_BLUEPRINT=$(awk '/^dirs:/{f=1} f&&/blueprint:/{print $2;exit}' "$CONFIG_FILE")
OMNI_POWERS_DIR_RECORD=$(awk '/^dirs:/{f=1} f&&/record:/{print $2;exit}' "$CONFIG_FILE")

# 注入环境变量
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"export OMNI_POWERS_ROOT=%s\\nexport OMNI_POWERS_MODEL_CODER=%s\\nexport OMNI_POWERS_MODEL_CODE_REVIEWER=%s\\nexport OMNI_POWERS_MODEL_TEST_REVIEWER=%s\\nexport OMNI_POWERS_MODEL_CLOSER=%s\\nexport OMNI_POWERS_DIR_TASKS=%s\\nexport OMNI_POWERS_DIR_BLUEPRINT=%s\\nexport OMNI_POWERS_DIR_RECORD=%s\\n"}}\n' \
  "$OMNI_POWERS_ROOT" "$OMNI_POWERS_MODEL_CODER" "$OMNI_POWERS_MODEL_CODE_REVIEWER" "$OMNI_POWERS_MODEL_TEST_REVIEWER" "$OMNI_POWERS_MODEL_CLOSER" \
  "$OMNI_POWERS_DIR_TASKS" "$OMNI_POWERS_DIR_BLUEPRINT" "$OMNI_POWERS_DIR_RECORD"
```

## 安装脚本 `install.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

OMNI_POWERS_ROOT="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$HOME/.config/omni_powers"
CONFIG_FILE="$CONFIG_DIR/config.yaml"
HOOKS_DIR="$CONFIG_DIR/hooks"
SKILLS_DIR="$HOME/.claude/skills"
AGENTS_DIR="$HOME/.claude/agents"
SETTINGS_FILE="$HOME/.claude/settings.json"

echo "=== omni_powers 安装 ==="
echo "omni_powers 位置: $OMNI_POWERS_ROOT"

# 1. 写配置文件
mkdir -p "$CONFIG_DIR"
if [ -f "$CONFIG_FILE" ]; then
  echo "配置已存在: $CONFIG_FILE → 覆盖 omni_powers_root，保留其他字段"
  # 只更新 omni_powers_root 行，保留用户自定义的 models/dirs
  if grep -q '^omni_powers_root:' "$CONFIG_FILE"; then
    sed -i "s|^omni_powers_root:.*|omni_powers_root: $OMNI_POWERS_ROOT|" "$CONFIG_FILE"
  else
    echo "omni_powers_root: $OMNI_POWERS_ROOT" >> "$CONFIG_FILE"
  fi
else
  cat > "$CONFIG_FILE" << EOF
omni_powers_root: $OMNI_POWERS_ROOT

models:
  coder: haiku
  code_reviewer: sonnet
  test_reviewer: sonnet
  closer: haiku

dirs:
  tasks: docs/op_execution
  blueprint: docs/op_blueprint
  record: docs/op_record
EOF
  echo "配置已创建: $CONFIG_FILE"
fi

# 2. 安装 session-start hook 脚本
mkdir -p "$HOOKS_DIR"
cp "$OMNI_POWERS_ROOT/hooks/session-start.sh" "$HOOKS_DIR/session-start.sh"
chmod +x "$HOOKS_DIR/session-start.sh"

# 3. 写入 settings.json hook
SETTINGS='{"hooks":{"SessionStart":[{"matcher":"","hooks":[{"type":"command","command":"'"$HOOKS_DIR/session-start.sh"'"}]}]}}'
if [ -f "$SETTINGS_FILE" ]; then
  # 合并已有 settings（保留其他配置）
  jq ".hooks.SessionStart = [{\"matcher\":\"\",\"hooks\":[{\"type\":\"command\",\"command\":\"$HOOKS_DIR/session-start.sh\"}]}]" "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
else
  echo "$SETTINGS" | jq '.' > "$SETTINGS_FILE"
fi
echo "Hook 已配置: $SETTINGS_FILE"

# 4. 建 skill symlink
mkdir -p "$SKILLS_DIR"
for skill_dir in "$OMNI_POWERS_ROOT"/skills/op-*; do
  name=$(basename "$skill_dir")
  target_tail="skills/$name"
  if [ -L "$SKILLS_DIR/$name" ]; then
    current=$(readlink "$SKILLS_DIR/$name")
    expected="$OMNI_POWERS_ROOT/$target_tail"
    if [ "$current" != "$expected" ]; then
      rm "$SKILLS_DIR/$name"
      ln -s "$OMNI_POWERS_ROOT/$target_tail" "$SKILLS_DIR/$name"
    fi
  elif [ ! -e "$SKILLS_DIR/$name" ]; then
    ln -s "$OMNI_POWERS_ROOT/$target_tail" "$SKILLS_DIR/$name"
  fi
done
echo "Skill symlink 已创建: $SKILLS_DIR/op-*"

# 5. 建 agent symlink
mkdir -p "$AGENTS_DIR"
for agent_file in "$OMNI_POWERS_ROOT"/agents/op-*.md; do
  name=$(basename "$agent_file")
  target_tail="agents/$name"
  if [ -L "$AGENTS_DIR/$name" ]; then
    current=$(readlink "$AGENTS_DIR/$name")
    expected="$OMNI_POWERS_ROOT/$target_tail"
    if [ "$current" != "$expected" ]; then
      rm "$AGENTS_DIR/$name"
      ln -s "$OMNI_POWERS_ROOT/$target_tail" "$AGENTS_DIR/$name"
    fi
  elif [ ! -e "$AGENTS_DIR/$name" ]; then
    ln -s "$OMNI_POWERS_ROOT/$target_tail" "$AGENTS_DIR/$name"
  fi
done
echo "Agent symlink 已创建: $AGENTS_DIR/op-*"

echo ""
echo "=== 安装完成 ==="
echo "配置文件: $CONFIG_FILE"
echo "Hook 脚本: $HOOKS_DIR/session-start.sh"
echo ""
echo "重启 Claude Code 生效。"
echo "编辑 $CONFIG_FILE 可修改模型和目录名。"
```

## Skill 内引用改写

所有相对路径改为 `$OMNI_POWERS_ROOT` 前缀：

### 脚本调用

```diff
- bash skills/op-start/scripts/op-status.sh {TID} 进行中
+ bash $OMNI_POWERS_ROOT/skills/op-start/scripts/op-status.sh {TID} 进行中
```

### 文件读取

```diff
- RULES.md
+ $OMNI_POWERS_ROOT/RULES.md
```

### Agent 模型

```diff
- Agent({ model: "haiku", ... })
+ Agent({ model: "$OMNI_POWERS_MODEL_CODER", ... })
```

> 环境变量在 Claude Code 进程中可用（由 SessionStart hook 注入），JSON 字段传值。

### 目录名

```diff
- docs/op_execution/tasks_list.json
- template/op_execution/tasks/{TID}/spec.md
+ $OMNI_POWERS_DIR_TASKS/tasks_list.json
+ $OMNI_POWERS_ROOT/template/op_execution/tasks/{TID}/spec.md
```

> 注意：模板文件固定在 `$OMNI_POWERS_ROOT/template/` 下，只有**生成到用户项目的路径**用 `$OMNI_POWERS_DIR_*`。

## 影响范围

| 文件 | 改动 |
|---|---|
| `skills/op-start/SKILL.md` | 所有脚本路径 → `$OMNI_POWERS_ROOT/...`，Agent model → 变量 |
| `skills/op-task/SKILL.md` | 同 |
| `skills/op-generate-spec/SKILL.md` | 同 |
| `skills/op-generate-plan/SKILL.md` | 同 |
| `skills/op-debt2tasks/SKILL.md` | 同 |
| `agents/op-coder.md` | model 字段 + 输出路径 |
| `agents/op-code-reviewer.md` | model 字段 |
| `agents/op-test-reviewer.md` | model 字段 |
| `agents/op-closer.md` | model 字段 |
| `RULES.md` | compact 恢复步骤中的路径 |
| `CLAUDE.md` | 目录结构中的路径 |
| `template/index.md` | 导航中的文档路径 |

## 新增文件

| 文件 | 用途 |
|---|---|
| `install.sh` | 安装脚本 |
| `hooks/session-start.sh` | SessionStart hook 脚本（注入 env） |

## 与现有工作的兼容

omni_powers 自身开发**不受影响**。环境变量未设置时，SKILL.md 中的 `$OMNI_POWERS_ROOT` 为空字符串。可在开发环境中手动设：

```bash
export OMNI_POWERS_ROOT=/home/karon/karson_ubuntu/omni_powers
export OMNI_POWERS_MODEL_CODER=haiku
export OMNI_POWERS_MODEL_CODE_REVIEWER=sonnet
export OMNI_POWERS_MODEL_TEST_REVIEWER=sonnet
export OMNI_POWERS_MODEL_CLOSER=haiku
export OMNI_POWERS_DIR_TASKS=docs/op_execution
export OMNI_POWERS_DIR_BLUEPRINT=docs/op_blueprint
export OMNI_POWERS_DIR_RECORD=docs/op_record
```
