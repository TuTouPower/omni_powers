# omni_powers 通用化方案

## 需求

用户在任意项目中调用 `/op-start` 等 skill 时，需要能：

1. **读到通用文档**：RULES.md 等协议文档，compact 恢复必读
2. **执行脚本**：skill 自带脚本 + 多个 skill 共用的通用脚本
3. **配置 Agent 模型**：op-coder 用 haiku/sonnet、op-code-reviewer 用哪个模型，用户可改
4. **配置生成目录**：task 工作区、蓝图文档、记录归档的目录名，用户可改
5. **模板文件**：spec.md、plan.md 等文档模板，按需读取

所有上述资源固定在 omni_powers 安装目录下，不随用户项目位置变化。

## 方案

Claude Code 插件系统 + SessionStart hook + 全局配置文件。

### 为什么用插件系统

- 平台自动设 `CLAUDE_PLUGIN_ROOT` 环境变量，指向 omni_powers 安装目录
- skill 目录自动发现，无需手动 symlink
- SessionStart hook 在每次会话启动时跑，适合注入配置和必读文档

### 为什么不用 Read 工具读文档

`Read` 工具不展开环境变量。`Read $CLAUDE_PLUGIN_ROOT/RULES.md` 会当成字面路径。用 `cat $CLAUDE_PLUGIN_ROOT/RULES.md` 通过 Bash 工具执行，shell 展开变量后输出内容。

### SessionStart 注入策略

SessionStart hook 每次会话都触发，**只注入环境变量配置（约 10 行）**，不注入 RULES.md。RULES.md 约 200 行，每次会话都灌入浪费上下文——用户开个会话改 README 不需要知道 omni_powers 协议。

RULES.md 在 op-start skill 被调用时按需读取（`cat $CLAUDE_PLUGIN_ROOT/RULES.md`），多一次 Bash 调用换每会话省 200 行。compact 恢复时必须执行 /op-start，自然读到 RULES.md。

### 为什么不用 CLI 二进制

OpenSpec 可以用 CLI 因为它的 skill 只做规范管理一件事。omni_powers 是多 Agent 编排——查状态、生成 DAG、扫信号、读 verdict、切 worktree——每个步骤的输入输出都高度依赖 LLM 判断，不适合框死在二进制里。bash 脚本直接输出文本，LLM 读文本做决策，这是最灵活的方案。

## 架构总览

```
用户安装 omni_powers 插件
        │
        ▼
  Claude Code 启动
        │
        ├─ 平台自动设 CLAUDE_PLUGIN_ROOT=/path/to/omni_powers
        ├─ 平台自动发现 skills/ 目录（无需 symlink）
        │
        ▼
  SessionStart hook 触发（hooks/hooks.json）
        │
        └─ 读 ~/.config/omni_powers/config.yaml
              → 注入 env: OMNI_POWERS_MODEL_CODER, OMNI_POWERS_DIR_TASKS ...
        │
        ▼
  Skill / Agent 运行时
        │
        ├─ 读协议:   cat $CLAUDE_PLUGIN_ROOT/RULES.md（op-start 调用时）
        ├─ 脚本路径: bash $CLAUDE_PLUGIN_ROOT/scripts/op_status.sh
        ├─ 查询:     bash $CLAUDE_PLUGIN_ROOT/scripts/op_jq.sh
        ├─ 文档读取: cat $CLAUDE_PLUGIN_ROOT/RULES.md
        ├─ 模板读取: cat $CLAUDE_PLUGIN_ROOT/docs_template/omni_powers/.../spec.md
        ├─ 模型选择: Agent({ model: "$OMNI_POWERS_MODEL_CODER" })
        └─ 生成路径: $OMNI_POWERS_DIR_TASKS/tasks_list.json
```

## 文件结构

```
omni_powers/
├── .claude-plugin/
│   └── plugin.json              # 插件元数据（技能自动发现）
├── hooks/
│   ├── hooks.json               # SessionStart hook 声明
│   └── session-start.sh         # 读配置 → 注入 env（约 10 行，不注入 RULES.md）
│
├── skills/                      # 平台自动发现，各 skill 互不感知
│   ├── op-start/
│   │   ├── SKILL.md
│   │   └── scripts/             # 本 skill 专属脚本
│   │       ├── dag_gen.sh
│   │       ├── close_check.sh
│   │       ├── op-coder-check.sh
│   │       └── op-read-verdict.sh
│   ├── op-task/SKILL.md
│   ├── op-generate-spec/
│   │   ├── SKILL.md
│   │   └── scripts/             # 本 skill 专属脚本
│   │       ├── start-server.sh
│   │       ├── stop-server.sh
│   │       └── ...
│   ├── op-generate-plan/SKILL.md
│   └── op-debt2tasks/SKILL.md
│
├── scripts/                     # 多个 skill 共用的通用脚本
│   ├── op_status.sh             # 状态流转（op-start/op-task/op-debt2tasks 都用）
│   ├── op_new_task.sh           # 工作区创建（op-task/op-start 都用）
│   └── op_jq.sh                 # tasks_list.json 查询
│
├── agents/                      # symlink 到 ~/.claude/agents/
│   ├── op-coder.md
│   ├── op-code-reviewer.md
│   ├── op-test-reviewer.md
│   ├── op-closer.md
│
├── docs_template/omni_powers/ # 文档模板（按需 cat 读取）
│   ├── op_execution/
│   └── op_blueprint/
│
├── RULES.md                     # 核心协议 + 操作细则（op-start 调用时 cat 读取）
└── CLAUDE.md
```

### Skill 脚本 vs 共用脚本

| 归属 | 路径 | 调用方 |
|---|---|---|
| op-start 专属 | `$CLAUDE_PLUGIN_ROOT/skills/op-start/scripts/dag_gen.sh` | op-start |
| op-start 专属 | `$CLAUDE_PLUGIN_ROOT/skills/op-start/scripts/close_check.sh` | op-start |
| op-start 专属 | `$CLAUDE_PLUGIN_ROOT/skills/op-start/scripts/op-coder-check.sh` | op-start |
| op-start 专属 | `$CLAUDE_PLUGIN_ROOT/skills/op-start/scripts/op-read-verdict.sh` | op-start |
| op-generate-spec 专属 | `$CLAUDE_PLUGIN_ROOT/skills/op-generate-spec/scripts/start-server.sh` | op-generate-spec |
| op-generate-spec 专属 | `$CLAUDE_PLUGIN_ROOT/skills/op-generate-spec/scripts/stop-server.sh` | op-generate-spec |
| **共用** | `$CLAUDE_PLUGIN_ROOT/scripts/op_status.sh` | op-start / op-task / op-debt2tasks |
| **共用** | `$CLAUDE_PLUGIN_ROOT/scripts/op_new_task.sh` | op-task / op-start |
| **共用** | `$CLAUDE_PLUGIN_ROOT/scripts/op_jq.sh` | 所有 skill（tasks_list.json 查询） |

> 原则：一个脚本只被一个 skill 用 → 放 `skills/<name>/scripts/`。被多个 skill 用 → 放 `scripts/`。

## `.claude-plugin/plugin.json`

```json
{
  "name": "omni_powers",
  "description": "多 Agent 协作开发工作流——leader 编排、op-coder 开发、op-code-reviewer 审查",
  "version": "1.0.0",
  "author": { "name": "tutoupower" },
  "homepage": "https://github.com/tutoupower/omni_powers",
  "license": "MIT"
}
```

## `hooks/hooks.json`

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh\"",
            "async": false
          }
        ]
      }
    ]
  }
}
```

## `hooks/session-start.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

# 读用户配置 → 注入环境变量（约 10 行，每次会话零负担）
CONFIG_FILE="$HOME/.config/omni_powers/config.yaml"

_awk_val() { awk '/^'"$1"':/{f=1;next} f&&/^  '"$2"':/{print $2;exit}' "$CONFIG_FILE" 2>/dev/null || true; }

OMNI_POWERS_MODEL_CODER="${OMNI_POWERS_MODEL_CODER:-$(_awk_val models op-coder)}"
OMNI_POWERS_MODEL_CODER="${OMNI_POWERS_MODEL_CODER:-haiku}"

OMNI_POWERS_MODEL_CODE_REVIEWER="${OMNI_POWERS_MODEL_CODE_REVIEWER:-$(_awk_val models op-code-reviewer)}"
OMNI_POWERS_MODEL_CODE_REVIEWER="${OMNI_POWERS_MODEL_CODE_REVIEWER:-sonnet}"

OMNI_POWERS_MODEL_TEST_REVIEWER="${OMNI_POWERS_MODEL_TEST_REVIEWER:-$(_awk_val models op-test-reviewer)}"
OMNI_POWERS_MODEL_TEST_REVIEWER="${OMNI_POWERS_MODEL_TEST_REVIEWER:-sonnet}"

OMNI_POWERS_MODEL_CLOSER="${OMNI_POWERS_MODEL_CLOSER:-$(_awk_val models op-closer)}"
OMNI_POWERS_MODEL_CLOSER="${OMNI_POWERS_MODEL_CLOSER:-haiku}"

OMNI_POWERS_DIR_TASKS="${OMNI_POWERS_DIR_TASKS:-$(_awk_val dirs tasks)}"
OMNI_POWERS_DIR_TASKS="${OMNI_POWERS_DIR_TASKS:-docs/omni_powers/op_execution}"

OMNI_POWERS_DIR_BLUEPRINT="${OMNI_POWERS_DIR_BLUEPRINT:-$(_awk_val dirs blueprint)}"
OMNI_POWERS_DIR_BLUEPRINT="${OMNI_POWERS_DIR_BLUEPRINT:-docs/omni_powers/op_blueprint}"

OMNI_POWERS_DIR_RECORD="${OMNI_POWERS_DIR_RECORD:-$(_awk_val dirs record)}"
OMNI_POWERS_DIR_RECORD="${OMNI_POWERS_DIR_RECORD:-docs/omni_powers/op_record}"

# 只注入环境变量，不注入 RULES.md（约 200 行省掉）
# RULES.md 在 skill 调用时按需 cat 读取
CONTEXT="export OMNI_POWERS_MODEL_CODER=${OMNI_POWERS_MODEL_CODER}"
CONTEXT="${CONTEXT}\\nexport OMNI_POWERS_MODEL_CODE_REVIEWER=${OMNI_POWERS_MODEL_CODE_REVIEWER}"
CONTEXT="${CONTEXT}\\nexport OMNI_POWERS_MODEL_TEST_REVIEWER=${OMNI_POWERS_MODEL_TEST_REVIEWER}"
CONTEXT="${CONTEXT}\\nexport OMNI_POWERS_MODEL_CLOSER=${OMNI_POWERS_MODEL_CLOSER}"
CONTEXT="${CONTEXT}\\nexport OMNI_POWERS_DIR_TASKS=${OMNI_POWERS_DIR_TASKS}"
CONTEXT="${CONTEXT}\\nexport OMNI_POWERS_DIR_BLUEPRINT=${OMNI_POWERS_DIR_BLUEPRINT}"
CONTEXT="${CONTEXT}\\nexport OMNI_POWERS_DIR_RECORD=${OMNI_POWERS_DIR_RECORD}"

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$CONTEXT"
```

## `~/.config/omni_powers/config.yaml`（用户可编辑）

```yaml
# omni_powers 全局配置
# 修改后重启 Claude Code 生效

models:
  op-coder: haiku
  op-code-reviewer: sonnet
  op-test-reviewer: sonnet
  op-closer: haiku

dirs:
  tasks: docs/omni_powers/op_execution
  blueprint: docs/omni_powers/op_blueprint
  record: docs/omni_powers/op_record
```

| 字段 | 说明 | 默认值 |
|---|---|---|
| `models.op-coder` | 写代码的 Agent 模型 | haiku |
| `models.op-code-reviewer` | 代码审查 Agent 模型 | sonnet |
| `models.op-test-reviewer` | 测试审查 Agent 模型 | sonnet |
| `models.op-closer` | 收口 Agent 模型 | haiku |
| `dirs.tasks` | task 工作区目录（相对于用户项目根） | docs/omni_powers/op_execution |
| `dirs.blueprint` | 蓝图文档目录 | docs/omni_powers/op_blueprint |
| `dirs.record` | 记录归档目录 | docs/omni_powers/op_record |

## Skill 内引用改写

### 共用脚本（`scripts/`）

```bash
bash $CLAUDE_PLUGIN_ROOT/scripts/op_status.sh {TID} 进行中
bash $CLAUDE_PLUGIN_ROOT/scripts/op_new_task.sh {TID}
```

### Skill 专属脚本（`skills/<name>/scripts/`）

```bash
bash $CLAUDE_PLUGIN_ROOT/skills/op-start/scripts/dag_gen.sh
bash $CLAUDE_PLUGIN_ROOT/skills/op-start/scripts/op-coder-check.sh {TID}
bash $CLAUDE_PLUGIN_ROOT/skills/op-start/scripts/op-read-verdict.sh {TID}
bash $CLAUDE_PLUGIN_ROOT/skills/op-start/scripts/close_check.sh {TID}
bash $CLAUDE_PLUGIN_ROOT/skills/op-generate-spec/scripts/start-server.sh --project-dir .
```

### 共用脚本（`scripts/`）

```bash
bash $CLAUDE_PLUGIN_ROOT/scripts/op_status.sh {TID} 进行中
bash $CLAUDE_PLUGIN_ROOT/scripts/op_new_task.sh {TID}
bash $CLAUDE_PLUGIN_ROOT/scripts/op_jq.sh all
bash $CLAUDE_PLUGIN_ROOT/scripts/op_jq.sh deps {TID}
```

### 文档读取（按需）

```bash
cat $CLAUDE_PLUGIN_ROOT/RULES.md
cat $CLAUDE_PLUGIN_ROOT/docs_template/omni_powers/op_execution/tasks/{TID}/spec.md
cat $CLAUDE_PLUGIN_ROOT/docs_template/omni_powers/op_blueprint/architecture.md
```

### Agent 模型

```
Agent({ subagent_type: "op-coder", model: "$OMNI_POWERS_MODEL_CODER" })
Agent({ subagent_type: "op-code-reviewer", model: "$OMNI_POWERS_MODEL_CODE_REVIEWER" })
Agent({ subagent_type: "op-test-reviewer", model: "$OMNI_POWERS_MODEL_TEST_REVIEWER" })
Agent({ subagent_type: "op-closer", model: "$OMNI_POWERS_MODEL_CLOSER" })
```

环境变量由 SessionStart hook 注入，在 Claude Code 进程中可用。

### 目录名（生成到用户项目）

```
$OMNI_POWERS_DIR_TASKS/tasks_list.json
$OMNI_POWERS_DIR_TASKS/{TID}/spec.md
$OMNI_POWERS_DIR_RECORD/decisions.md
```

## 安装

```bash
git clone <omni_powers_repo>
cd omni_powers

# 1. 注册插件（技能自动发现 + hook 注册）
claude plugins install .

# 2. 建 Agent symlink
mkdir -p ~/.claude/agents
for f in agents/op-*.md; do
  name=$(basename "$f")
  [ -L ~/.claude/agents/"$name" ] || ln -s "$(pwd)/$f" ~/.claude/agents/"$name"
done

# 3. 创建默认配置（可选，不创建则用默认值）
mkdir -p ~/.config/omni_powers
cat > ~/.config/omni_powers/config.yaml << 'EOF'
models:
  op-coder: haiku
  op-code-reviewer: sonnet
  op-test-reviewer: sonnet
  op-closer: haiku
dirs:
  tasks: docs/omni_powers/op_execution
  blueprint: docs/omni_powers/op_blueprint
  record: docs/omni_powers/op_record
EOF

# 重启 Claude Code
```

## 开发环境

omni_powers 自身开发时，作为插件加载后 `CLAUDE_PLUGIN_ROOT` 自动指向项目根。无需额外设置。

如需手动覆盖（调试用）：

```bash
export OMNI_POWERS_MODEL_CODER=haiku
export OMNI_POWERS_MODEL_CODE_REVIEWER=sonnet
export OMNI_POWERS_MODEL_TEST_REVIEWER=sonnet
export OMNI_POWERS_MODEL_CLOSER=haiku
export OMNI_POWERS_DIR_TASKS=docs/omni_powers/op_execution
export OMNI_POWERS_DIR_BLUEPRINT=docs/omni_powers/op_blueprint
export OMNI_POWERS_DIR_RECORD=docs/omni_powers/op_record
```

## 改造清单

### 新建

| 文件 | 用途 |
|---|---|
| `.claude-plugin/plugin.json` | 插件元数据 |
| `hooks/hooks.json` | SessionStart hook 声明 |
| `hooks/session-start.sh` | 读配置 → 注入环境变量（不注入 RULES.md，按需读） |
| `scripts/` 目录 | 共用脚本迁入 |

### 脚本迁移

| 从 | 到 | 原因 |
|---|---|---|
| `skills/op-start/scripts/op_status.sh` | `scripts/op_status.sh` | 被 3 个 skill 共用 |
| `skills/op-start/scripts/op_new_task.sh` | `scripts/op_new_task.sh` | 被 2 个 skill 共用 |

### 路径改写

| 文件 | 改动 |
|---|---|
| `skills/op-start/SKILL.md` | 专属脚本 → `$CLAUDE_PLUGIN_ROOT/skills/op-start/scripts/...`；共用脚本 → `$CLAUDE_PLUGIN_ROOT/scripts/...`；模型 → `$OMNI_POWERS_MODEL_*`；文档 → `cat $CLAUDE_PLUGIN_ROOT/...`；目录 → `$OMNI_POWERS_DIR_*` |
| `skills/op-task/SKILL.md` | 同 |
| `skills/op-generate-spec/SKILL.md` | 同 |
| `skills/op-generate-plan/SKILL.md` | 同 |
| `skills/op-debt2tasks/SKILL.md` | 同 |
| `agents/op-coder.md` | 模型 + 输出路径 |
| `agents/op-code-reviewer.md` | 模型 |
| `agents/op-test-reviewer.md` | 模型 |
| `agents/op-closer.md` | 模型 |
| `RULES.md` | compact 恢复步骤中的路径 |
| `CLAUDE.md` | 目录结构中的路径 |
