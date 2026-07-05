# trellis

## 1. 概览

**一句话定位**：面向 AI 编码的多平台工程框架，将 specs、tasks、memory 持久化到仓库中，使任何 AI 编码代理都能按照团队工程标准工作。

**设计哲学 / 解决什么问题**：
- AI 每次会话从零开始，不记得项目约定、团队要求。Trellis 把规范、任务、记忆写入仓库文件，跨会话持久化。
- 核心原则：specs injected not remembered（规范注入而非靠记忆）、persist everything（文件化一切）、incremental development（增量开发，一次一个 task）。
- 解决三个痛点：(1) 跨会话记忆断裂；(2) 团队标准无法共享；(3) 不同 AI 平台工作流碎片化。

**成熟度**：
- 版本 `0.6.5`，npm 包 `@mindfoldhq/trellis`。
- 提交频率高，2026 年至今 ~50 个 commit，每日活跃合并 PR。
- 文档完整：独立文档站 `docs.trytrellis.app`，README 中英文，CONTRIBUTING 中英文，3 层 spec 文档（CLI/backend、core/backend 等），workflow.md 超过 700 行。
- 支持 16 个 AI 编码平台：Claude Code、Cursor、OpenCode、Codex、Kiro、Gemini、Qoder、CodeBuddy、Copilot、Droid、Pi、Devin、Antigravity、Kilo、Trae、ZCode。
- 社区：Discord、GitHub Issues、Star History 展示持续增长，npm 周下载量较高。
- AGPL-3.0 许可。

## 2. 安装机制

**主安装流程** (`trellis init`)：

```bash
npm install -g @mindfoldhq/trellis@latest
trellis init -u your-name
# 或指定平台
trellis init --claude --cursor --opencode -u your-name
```

`trellis init` 做的事（以 Claude Code 为例）：

1. **Python 版本检测**：需要 Python >= 3.9。检测系统 Python 命令（python3/python/python3.12 等），在 Windows 上优先 venv/Scoop。

2. **项目类型检测**：自动识别单仓/多仓（pnpm workspaces、npm workspaces、lerna 等），创建 packages 配置。

3. **开发者初始化**：运行 `init_developer.py <name>`，创建 `.trellis/.developer`（gitignored）+ `.trellis/workspace/<name>/`。

4. **目录结构生成**：按模板生成 `.trellis/` 完整目录：
   - `.trellis/spec/` — 规范目录（按包/层组织）
   - `.trellis/tasks/` — 任务目录
   - `.trellis/workspace/` — 工作区日志
   - `.trellis/scripts/` — Python 脚本（task.py、get_context.py、add_session.py 等）
   - `.trellis/config.yaml` — 项目级配置
   - `.trellis/workflow.md` — 工作流定义（单文件真相源）

5. **平台配置写入** (per platform configurator)：
   - **settings.json** (`~/.claude/settings.json` 或项目 `.claude/settings.json`)：写入 SessionStart、UserPromptSubmit、PreToolUse 三个 hooks，设置 `CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR=1`。可选 statusLine hook。
   - **CLAUDE.md / AGENTS.md**：在文件顶部注入 `<!-- TRELLIS:START -->...<!-- TRELLIS:END -->` 块，指向 `.trellis/` 关键路径。
   - **Hooks 脚本**：写入 `.claude/hooks/session-start.py`、`inject-workflow-state.py`、`inject-subagent-context.py`（多平台共享，通过 `writeSharedHooks()` 复制到各平台目录）。
   - **Agents**：写入 `.claude/agents/trellis-implement.md`、`trellis-check.md`、`trellis-research.md`。
   - **Skills**：写入 `.claude/skills/` 下 13 个 skill 目录 + 完整 reference 文档。
   - **Commands**：写入 `.claude/commands/trellis/` 下 5 个 slash command。

6. **模板 hash 记录**：`.trellis/.template-hashes.json`，用于 `trellis update` 判断是否需要更新。

7. **Spec registry**：可选从远程 registry 拉取 spec 模板。

**symlink 策略**：不使用 symlink。所有 hooks 脚本是通过文件复制写入各平台目录的（`writeSharedHooks()` 函数），每个平台目录有独立副本。同样，agents 和 skills 也是每个平台独立复制（通过 `writeSkills()` + `resolveSkills()`）。

**变更的配置文件汇总**：

| 文件 | 变更方式 | 内容 |
|------|---------|------|
| `.claude/settings.json` | 全量写入/merge | hooks 配置、env 变量 |
| `CLAUDE.md` / `AGENTS.md` | 块注入 | TRELLIS:START/END 块 |
| `.claude/hooks/*.py` | 复制 | 3 个 hook 脚本 |
| `.claude/agents/*.md` | 复制 | 3 个 agent 定义 |
| `.claude/skills/*/` | 复制 | 13 个 skill 目录 |
| `.claude/commands/trellis/*.md` | 复制 | 5 个 slash command |
| `.trellis/config.yaml` | 模板生成 | 项目配置 |
| `.trellis/workflow.md` | 模板生成 | 工作流定义 |

## 3. 提供的工具全景

### 3.1 Python 脚本（`.trellis/scripts/`，项目级运行时）

| 工具 | 用途 |
|------|------|
| `task.py` | 任务全生命周期：create/start/finish/archive/list/add-context/add-subtask/set-branch/set-scope/create-pr |
| `get_context.py` | 上下文查询：全量 session runtime / packages 列表 / phase 步骤详情 / record 信息 |
| `add_session.py` | 写入 session journal + index.md，可选 auto-commit |
| `init_developer.py` | 初始化开发者身份，创建 workspace 目录 |
| `get_developer.py` | 查询当前开发者名称 |

### 3.2 Skills (Claude Code skills, `.claude/skills/`)

| Skill | 用途 |
|-------|------|
| `trellis-brainstorm` | Phase 1 需求探索：逐题访谈用户，写出 prd.md/design.md/implement.md |
| `trellis-before-dev` | Phase 2 实现前：按包/层加载 spec 规范，读 Pre-Development Checklist |
| `trellis-check` (skill) | Phase 2 质量检查：spec 合规、lint、type-check、tests、跨层一致性 |
| `trellis-update-spec` | Phase 3.3：审查是否需要把新发现写回 `.trellis/spec/` |
| `trellis-break-loop` | 反复调试时的根因分析 + 预防建议 |
| `trellis-channel` | 多 agent channel 通信系统操作（spawn/send/workers/kill/listen） |
| `trellis-session-insight` | 跨会话洞察：分析 journal、趋势、模式 |
| `trellis-spec-bootstrap` | 从现有代码库引导生成初始 spec |
| `trellis-meta` | Trellis 自身的元文档：架构、自迭代指南、平台兼容性 |
| `contribute` | 贡献指南 |
| `first-principles-thinking` | 第一性原理思维框架 |
| `python-design` | Python 设计约束 |
| `gitnexus-*` (6 个) | GitNexus 代码智能工具（exploring/impact-analysis/debugging/refactoring/guide/cli） |

### 3.3 Slash Commands (`.claude/commands/trellis/`)

| Command | 用途 |
|---------|------|
| `/trellis:continue` | 继续当前 task：自动判断 Phase/Step，加载对应上下文 |
| `/trellis:finish-work` | 收尾：archive task + 记录 session journal |
| `/trellis:create-manifest` | 从已有 task artifacts 生成 implement.jsonl / check.jsonl |
| `/trellis:improve-ut` | 改进单元测试 |
| `/trellis:publish-skill` | 发布 skill 到 marketplace |

### 3.4 Custom Agents (`.claude/agents/`)

| Agent | 用途 | 工具权限 |
|-------|------|---------|
| `trellis-implement` | Phase 2.1：读取 spec + prd/design/implement，写代码，禁止 git commit | Read、Write、Edit、Bash、Glob、Grep |
| `trellis-check` | Phase 2.2：review diff vs specs，自修复，跑 lint/typecheck | Read、Write、Edit、Bash、Glob、Grep |
| `trellis-research` | Phase 1.2：内外部搜索，结果持久化到 `research/` 目录，只读不写代码 | Read、Write、Glob、Grep、Bash、Skill、mcp__* |

### 3.5 Hooks

| Hook 类型 | 脚本 | 触发时机 | 功能 |
|-----------|------|---------|------|
| SessionStart | `session-start.py` | startup/clear/compact | 注入完整 session context（当前状态 + workflow 概览 + spec 索引 + task 状态） |
| UserPromptSubmit | `inject-workflow-state.py` | 每次用户输入 | 注入 `<workflow-state>` breadcrumb，提示当前 task 状态和下一步操作 |
| PreToolUse | `inject-subagent-context.py` | 派发 Task/Agent 前 | 拦截 implement/check/research 子 agent 派发，自动注入 jsonl 上下文 + prd/design/implement |

### 3.6 CLI 工具 (`trellis` 全局命令)

| 命令 | 用途 |
|------|------|
| `trellis init` | 初始化 Trellis 到当前仓库 |
| `trellis update` | 更新模板文件（hooks/agents/skills/commands）到最新版 |
| `trellis upgrade` | 升级 trellis npm 包自身 |
| `trellis uninstall` | 卸载 Trellis，清理注入块和生成文件 |
| `trellis workflow` | 查看当前工作流状态 |
| `trellis mem` | 跨项目记忆管理（mem search/list/delete/import） |
| `trellis channel` | 多 agent 通道管理（spawn/listen/send/workers/kill） |

### 3.7 NPM 包

| 包 | 用途 |
|----|------|
| `@mindfoldhq/trellis` (CLI) | 全局 CLI、平台配置器、init/update/upgrade/mem/channel |
| `@mindfoldhq/trellis-core` (SDK) | 核心原语：channel 事件系统、task 领域模型、mem 持久化、testing 工具 |

### 3.8 模板 / 脚手架

- `.trellis/` 完整目录结构生成
- Spec 模板（可从远程 registry 下载）
- spec/guides/index.md — 跨包思维指南
- spec/\<package\>/\<layer\>/index.md — 分层规范

### 3.9 配置文件

| 文件 | 格式 | 内容 |
|------|------|------|
| `.trellis/config.yaml` | YAML | 项目配置：session 行为、monorepo packages、channel worker guard、Codex dispatch mode |
| `.trellis/workflow.md` | Markdown | 工作流定义 + `[workflow-state:STATUS]` breadcrumb 标签块 |
| `.trellis/.template-hashes.json` | JSON | 模板文件 hash，用于 update 检测 |
| `.trellis/.runtime/sessions/` | JSON | 每会话 active-task 指针 |

## 4. 核心工具详解

### 4.1 SessionStart Hook（`session-start.py`）

**执行流程**：

1. **检查跳过条件**：`TRELLIS_HOOKS=0` 或 `TRELLIS_DISABLE_HOOKS=1` 或非交互模式则 skip。
2. **解析 hook 输入**：读取 stdin JSON（包含 cwd、platform 信息）。
3. **检测项目根目录**：通过 `CLAUDE_PROJECT_DIR` 环境变量或 hook cwd 定位。
4. **解析 session identity** (`context_key`)：通过 `resolve_context_key()` 确定当前会话标识（跨平台兼容：Claude Code session ID / Cursor 窗口 ID 等）。
5. **持久化 context_key 到 bash 环境**：写入 `CLAUDE_ENV_FILE`，使后续 Bash 工具调用能访问 `TRELLIS_CONTEXT_ID`。
6. **加载配置**：读取 `.trellis/config.yaml`，确定 mono/packages/spec_scope。
7. **收集 spec 索引路径**：扫描 `.trellis/spec/<package>/<layer>/index.md`，根据 scope 过滤。
8. **构建输出**（注入到会话上下文）：
   - `<session-context>` — 定向提示
   - `<first-reply-notice>` — 首次回复提示（中文 "Trellis SessionStart context is loaded"）
   - `<migration-warning>` — 旧版 spec 结构迁移警告（如存在）
   - `<current-state>` — 开发者名、git 分支和干净状态、当前 task（路径+状态）、活跃 task 数、journal 行数、spec 索引数
   - `<trellis-workflow>` — workflow.md 的 Phase Index 摘要（含各阶段路由规则）
   - `<guidelines>` — task 上下文读取顺序、可用的 spec 索引列表、`get_context.py` 命令
   - `<task-status>` — 当前 task 的详细状态（planning/in_progress/completed/stale）+ artifact 存在性检查 + 下一步操作
   - `<ready>` — 收尾标记
9. **输出 JSON**：兼容 Claude Code (`hookSpecificOutput.additionalContext`) 和 Cursor (`additional_context`) 两种格式。

**输入**：stdin JSON（hook payload，含 platform 信息 + cwd）。

**输出**：stdout JSON（`hookSpecificOutput` + `additional_context`），注入约 2-4KB 上下文到会话。

**调用的底层能力**：subprocess（git 命令）、文件读取（workflow.md、task.json、spec index）、Python import（common.active_task、common.config、common.paths）。

**关键设计决策**：
- workflow.md 是唯一真相源（single source of truth）：breadcrumb 文本从 workflow.md 的 `[workflow-state:STATUS]` 标签块解析，脚本内无硬编码回退文本。
- `<first-reply-notice>` 机制：只在首次 AI 回复时触发一次，避免每次 compact 后重复提示。
- 上下文压缩设计：只注入索引和摘要，完整 spec 内容按需加载（`load details on demand`）。

### 4.2 PreToolUse Sub-Agent Context Injection（`inject-subagent-context.py`）

**执行流程**：

1. **跳过检查**：同上。
2. **解析 hook 输入**：识别子 agent 类型（`subagent_type`），跨平台兼容（Claude Code 的 `tool_input.subagent_type`、Cursor 的 protobuf oneof 编码、Gemini 的 `tool_name` 即 agent 名、Kiro 的 `agent_name`、Copilot 的 camelCase）。
3. **检查是否为目标 agent**：仅处理 `trellis-implement`、`trellis-check`、`trellis-research`。
4. **定位仓库根目录**：通过 `.git` 向上查找。
5. **解析活跃 task**：调用 `resolve_active_task()`。
6. **按 agent 类型构建上下文**：
   - `trellis-implement`：`implement.jsonl` 中所有引用的 spec/research 文件内容 + `prd.md` + `design.md`（如有）+ `implement.md`（如有）
   - `trellis-check`：`check.jsonl` 引用文件 + `prd.md` + `design.md` + `implement.md`。如 prompt 含 `[finish]` 标记则用 finish context（轻量，侧重最终验证）
   - `trellis-research`：项目 spec 目录树概览 + 搜索提示，不需要 task 目录
7. **构建新 prompt**：将原始 prompt + 注入的上下文拼接为完整的 agent 指令（含 `<!-- trellis-hook-injected -->` 标记）。
8. **返回 updatedInput**：覆盖 `tool_input.prompt`，多格式兼容输出。

**输入**：stdin JSON（hook payload，含 tool_name、tool_input、cwd）。

**输出**：stdout JSON（`hookSpecificOutput.updatedInput` + `updated_input` + `updatedInput`），修改后的 prompt 替代原始 prompt。

**关键设计决策**：
- Hook 负责注入所有上下文，子 agent 自主工作不依赖回叫（"behavior controlled by code not prompt"）。
- 这类注入可借鉴为动态摘要和上下文补齐；不可作为访问控制、写权限隔离或硬安全边界。
- `<!-- trellis-hook-injected -->` 标记：子 agent 通过检查此标记判断上下文是否已注入，未注入时自行加载（Windows + `--continue` resume 等 hooks 无法触发的场景）。
- jsonl 种子行（`{"_example": ...}`）不含 `file` 字段 → 自动跳过，emit stderr 警告。
- 递归保护：implement/check agent 定义中明确禁止再次派发 implement/check。

### 4.3 Per-Turn Breadcrumb（`inject-workflow-state.py`）

**执行流程**：

1. **CWD-robust 根目录发现**：从当前目录向上查找 `.trellis/`。
2. **解析 workflow.md**：提取所有 `[workflow-state:STATUS]...[/workflow-state:STATUS]` 标签块，构建 `{status: body}` 字典。
3. **解析活跃 task**：获取 `(task_id, status, source)`。
4. **Codex dispatch_mode 路由**：如 `codex.dispatch_mode=inline`，将 status 映射为 `{status}-inline` 键，读取不同的 breadcrumb 文本（inline 模式不走子 agent）。
5. **构建 breadcrumb**：`<workflow-state>\nTask: <id> (<status>)\n<body>\n</workflow-state>`，如无活跃 task 则用 `no_task` 伪状态。
6. **平台适配**：Gemini CLI 0.40.x 的 hook 事件名为 `BeforeAgent`，其他平台用 `UserPromptSubmit`。

**输入**：stdin JSON（hook payload）。

**输出**：stdout JSON（`hookSpecificOutput.additionalContext`），约 200-800 字符的短 breadcrumb。

**关键设计决策**：
- workflow.md 是 breadcrumb 的唯一真相源，脚本不包含回退 dict。标签缺失时输出 "Refer to workflow.md for current step." 让用户可见问题。
- Codex 平台特殊处理：无 task 时额外注入 `<trellis-bootstrap>` 提示 + `<codex-mode>` 标签。
- STATUS charset 支持 `[A-Za-z0-9_-]+`，允许 `in-review`、`blocked-by-team` 等自定义状态。

### 4.4 trellis-brainstorm Skill

**执行流程**：

1. **前置条件检查**：确认已获得 task-creation consent。
2. **创建 task**（如不存在）：运行 `task.py create`，自动设置 status=planning。
3. **证据优先探索**：先检查代码、测试、配置、文档、已有 spec、历史 task，而非直接问用户。
4. **分类发现**：confirmed facts / product intent needed / scope decisions needed / out-of-scope。
5. **逐题访谈**：每次只问一个问题，包含推荐答案 + 权衡说明。
6. **即时写回**：每次用户回答后立即更新 `prd.md`。
7. **复杂任务扩展**：如需要，创建 `design.md` + `implement.md`。
8. **PRD 收敛 pass**：最终一次性重写 `prd.md`——合并重复事实、折叠临时章节、删除已解决的开放问题、保留所有 file:line 锚点和决策映射。
9. **质量门槛**：可测试的验收标准、通过收敛检查、仓库可回答的问题已通过检查回答、复杂任务有全部 artifacts。

**输入**：用户自然语言需求描述 + 仓库代码/文档。

**输出**：`prd.md`（必须）、`design.md`（复杂任务）、`implement.md`（复杂任务）。

**关键设计决策**：
- "非协商访谈契约"：必须逐题深入访谈，直到达成共识。
- "非协商证据规则"：能通过探索仓库回答的问题不诉诸用户。
- 第一性原理思维框架：剥离实现细节→列出基本原则→挑战假设→从原则构建→验证。
- PRD 收敛是刚性门槛，不是可选的清理步骤。

### 4.5 Three-Phase Workflow + Breadcrumb State Machine

**Phase 1 - Plan**：classify → task-creation consent → create task → brainstorm → research (optional) → configure jsonl context → review gate → `task.py start` (status → in_progress)

**Phase 2 - Execute**：dispatch `trellis-implement` → dispatch `trellis-check` → repeat until done. 最后一遍 check 必须是 full-scope（所有受影响包）。

**Phase 3 - Finish**：debug retrospective (optional) → spec update (`trellis-update-spec`) → commit changes (batched plan, one-shot confirmation) → `/trellis:finish-work` (archive + journal)

**状态机**（由 workflow.md 的 `[workflow-state:STATUS]` 标签块 + task.json.status 驱动）：

```
no_task → planning → in_progress → (archive 时直接 completed)
                          ↑              (completed 标签目前 DEAD)
                          └── 可回退到 planning (prd defect)
```

每个状态对应不同的 per-turn breadcrumb 文本，路由 AI 行为：
- `no_task`：分类请求，请求 task-creation consent
- `planning`：加载 `trellis-brainstorm`，留在 planning
- `in_progress`：派发 implement/check 子 agent（或 inline 模式直接编辑）
- `completed`：目前 dead code，task archive 时一并完成

## 5. 文件规范

### 5.1 目录结构

```
.trellis/                    # Trellis 核心目录
├── config.yaml              # 项目级配置
├── workflow.md              # 工作流定义（单文件真相源）
├── .developer               # 当前开发者名（gitignored）
├── .template-hashes.json    # 模板 hash（用于 update）
├── .runtime/sessions/       # 每会话 active-task 指针
├── spec/                    # 规范目录
│   ├── guides/index.md      # 跨包思维指南
│   └── <package>/           # 按包组织
│       └── <layer>/         # 按层组织（backend/frontend/testing/docs 等）
│           ├── index.md     # 入口：Pre-Development Checklist + Quality Check
│           └── *.md         # 具体规范文件（conventions.md、error-handling.md 等）
├── tasks/                   # 活跃任务
│   └── MM-DD-slug/          # 日期前缀 + slug
│       ├── task.json        # 任务元数据（title/status/package/branch/hooks）
│       ├── prd.md           # 需求文档
│       ├── design.md        # 技术设计（复杂任务）
│       ├── implement.md     # 执行计划（复杂任务）
│       ├── implement.jsonl  # 实现 agent 上下文清单
│       ├── check.jsonl      # 检查 agent 上下文清单
│       └── research/        # 调研结果
├── workspace/<developer>/   # 开发者工作区
│   ├── index.md             # 个人索引
│   └── journal-N.md         # 会话日志（2000 行上限，自动轮转）
└── scripts/                 # Python 运行时脚本
    ├── task.py
    ├── get_context.py
    ├── add_session.py
    └── common/              # 共享库
```

### 5.2 命名约定

- task 目录：`MM-DD-slug`（如 `03-15-add-auth`），`task.py create` 自动添加日期前缀。
- task slug：不含日期前缀，`--slug` 参数只传人类可读名。
- journal 文件：`journal-1.md`、`journal-2.md`... 自增数字。
- spec 层：按功能命名（`backend`、`frontend`、`testing`、`docs`、`unit-test` 等）。
- Python 模块：`snake_case`（如 `active_task.py`、`safe_commit.py`）。
- TypeScript 模块：`kebab-case` 文件名（如 `template-fetcher.ts`）。

### 5.3 Frontmatter / Metadata Schema

**Claude Code Skill** (`.md` frontmatter，YAML)：
```yaml
---
name: trellis-brainstorm
description: "描述文本"
---
```

**Claude Code Agent** (`.md` frontmatter，YAML)：
```yaml
---
name: trellis-implement
description: |
  描述文本
tools: Read, Write, Edit, Bash, Glob, Grep
---
```

**task.json** schema（关键字段）：
```json
{
  "id": "03-15-add-auth",
  "title": "Add Authentication",
  "status": "planning|in_progress|completed|archived",
  "package": "cli",
  "branch": "feat/auth",
  "base_branch": "main",
  "scope": "auth",
  "hooks": {
    "after_create": ["..."],
    "after_start": ["..."],
    "after_finish": ["..."],
    "after_archive": ["..."]
  }
}
```

**implement.jsonl / check.jsonl** 每行：
```json
{"file": ".trellis/spec/cli/backend/index.md", "reason": "Backend conventions for CLI"}
```

**workflow.md breadcrumb 标签块格式**：
```
[workflow-state:STATUS]
body text
[/workflow-state:STATUS]
```
STATUS charset: `[A-Za-z0-9_-]+`。标签块位于 `## Phase Index` 章节下。

## 6. SessionStart 注入

**注入内容**（每次会话启动 / clear / compact 时触发）：

1. `<session-context>` — 一句引导："Trellis compact SessionStart context. Use it to orient the session; load details on demand."
2. `<first-reply-notice>` — 首次回复提示。
3. `<migration-warning>` — 旧版 spec 结构警告（条件性）。
4. `<current-state>` — 包含：
   - 开发者名
   - Git 状态（分支 + 是否 clean / dirty N paths）
   - 当前 task（路径 + status）
   - 活跃 task 总数
   - Journal 行数 / 上限
   - Spec 索引文件数
5. `<trellis-workflow>` — workflow.md 中 `## Phase Index` 章节内容（约 80 行），含 3 阶段路由规则 + 子 agent dispatch 协议 + inline 模式差异。
6. `<guidelines>` — task 上下文读取顺序 + 可用 spec 索引列表 + `get_context.py` 命令。
7. `<task-status>` — 当前 task 的详细状态摘要（不同 status 给出不同的下一步操作指令）。
8. `<ready>` — 收尾。

**预估 context 消耗量**：
- workflow Phase Index 摘要：~1500-2000 字符 (~400 tokens)
- current-state 块：~200-400 字符 (~60 tokens)
- task-status 块：~300-800 字符 (~100 tokens)
- spec 索引列表：~100-500 字符 (~30 tokens)
- guidelines + 其他：~300 字符 (~80 tokens)
- **总计约 2-4KB 文本，估算 ~500-800 tokens**（取决于 spec 索引数量和 task 复杂度）。

**设计要点**：
- 只注入索引和摘要，不注入完整 spec 内容（`load details on demand`）。
- workflow.md 的 `[workflow-state:STATUS]` 标签块在 SessionStart 阶段被剥离（已由 UserPromptSubmit hook 独立处理），避免重复。
- `get_context.py --mode phase --step X.Y` 按需加载详细步骤指导。

## 7. 状态管理

### 7.1 Session 状态

**存储位置**：`.trellis/.runtime/sessions/<context_key>.json`

**内容**：当前活跃 task 指针（task 路径 + source type）。

**生命周期**：
- SessionStart hook 自动解析 `context_key`（平台相关：Claude Code 的 session ID、Cursor 的 window ID 等）。
- `task.py start` 写入指针。
- `task.py finish` 删除指针文件。
- `task.py archive` 也会清理指向该 task 的 runtime session 文件。

### 7.2 Task 状态

**存储位置**：`.trellis/tasks/MM-DD-slug/task.json`

**状态机**：`planning → in_progress → archived（直接 archive，中间无 completed 阶段）`

**持久化**：所有 task 数据以文件形式存储——`task.json`（元数据）、`prd.md`（需求）、`design.md`（设计）、`implement.md`（计划）、`research/`（调研）。

### 7.3 Workspace / Journal 记忆

**存储位置**：`.trellis/workspace/<developer>/`

**内容**：
- `journal-N.md` — 每次 AI 会话的日志（`add_session.py --title --commit --summary` 写入）。2000 行上限，超限自动创建 `journal-(N+1).md`。
- `index.md` — 个人索引（总 sessions 数、最后活跃时间）。

**Auto-commit**：`session_auto_commit` 配置项控制是否自动提交 journal 变更（默认 true）。

### 7.4 Spec 记忆

**存储位置**：`.trellis/spec/<package>/<layer>/*.md`

**更新机制**：Phase 3.3 的 `trellis-update-spec` skill 审查是否需要把新发现的模式/约定/踩坑写回 spec。

### 7.5 跨项目记忆 (trellis mem)

**CLI 命令**：`trellis mem search/list/delete/import`

**实现**：`@mindfoldhq/trellis-core` 的 `mem/` 模块，提供 session 对话存储、全文搜索、项目关联。

### 7.6 配置持久化

**`.trellis/config.yaml`**：YAML 格式，session 行为、monorepo packages、channel worker guard、Codex dispatch mode。

## 8. 编排模式

### 8.1 Leader-Worker 模式

Trellis 的核心编排模式是 **leader-worker**：

- **Leader**（主 AI 会话）：负责协调、分类、规划、决策、commit、spec 更新。运行在用户的主会话中。
- **Worker**（子 agent）：`trellis-implement`、`trellis-check`、`trellis-research`。由 leader 通过 Agent/Task tool 派发，接收 hook 自动注入的上下文，执行特定职责后返回结果。

**派发时机**：
- Phase 1.2（Research）：复杂技术问题派发 `trellis-research`
- Phase 2.1（Implement）：派发 `trellis-implement`
- Phase 2.2（Check）：派发 `trellis-check`

**递归保护**：implement 和 check agent 定义中包含明确的递归防护——禁止子 agent 再派发 implement/check。

### 8.2 双模式路由

Trellis 支持两种执行模式，通过平台能力自动选择：

| 模式 | 适用平台 | 实现方式 |
|------|---------|---------|
| Sub-agent dispatch | Claude Code、Cursor、OpenCode、Gemini、Qoder、CodeBuddy、Copilot、Droid、Pi、Kiro | leader 派发子 agent，hook 自动注入 jsonl 上下文 |
| Inline | Codex、Kilo、Antigravity、Devin | 主会话直接编辑代码，通过 `trellis-before-dev` + `trellis-check` skill 加载上下文 |

Codex 可通过 `codex.dispatch_mode` 配置项在两种模式间切换。

### 8.3 Channel 系统（多 Agent 通信）

`trellis channel` 命令 + `@mindfoldhq/trellis-core` 的 `channel/` 模块提供多 agent 异步通信：

- **Channel 类型**：thread、dm、group
- **事件类型**：create、message、thread action、context mutation、spawned、killed、done、error、progress、interrupt 等
- **Worker 管理**：spawn worker → supervise → idle timeout → auto-cleanup
- **Worker guard**：`max_live_workers` + `idle_timeout` 防 OOM

Channel 系统相对独立于核心 3-Phase 工作流，更多用于高级多 agent 协作场景。

### 8.4 Parent/Child Task 树

支持单次用户请求拆分为多个独立可验证的子任务：
- Parent task 持有源需求集、子任务映射、跨子任务验收标准、最终集成审查
- Child task 独立规划、实现、检查、归档
- 非依赖系统：子任务间的依赖需写入各自的 `prd.md` / `implement.md`

### 8.5 总结

Trellis 的编排哲学是 **结构化但非强约束**：
- 工作流有明确的 Phase/Step 结构，但允许回退（Phase 2 发现 prd 缺陷 → 回 Phase 1）
- 状态 breadcrumb 是建议性的（"Follow the matching per-turn workflow-state"），不是强制性 gate
- 轻量任务可以跳过 artifacts（PRD-only），复杂任务强制执行完整 artifact 链
- 平台差异通过双模式路由 + per-platform configurator 消解
