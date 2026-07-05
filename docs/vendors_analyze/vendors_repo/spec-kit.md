# spec-kit

## 1. 概览

- **一句话定位**：GitHub 官方出品的 Spec-Driven Development（SDD）脚手架 CLI，为 35+ AI 编程 Agent 自动生成结构化 slash commands / skills 和项目模板。
- **设计哲学**：以"规格先行"倒置传统 AI 编码流程 -- 先写宪法原则 -> spec -> plan -> tasks -> implement。通过严格模板约束 LLM 输出质量（禁止过早实现细节、强制标注不确定性、检查清单门禁、宪法合规校验）。
- **成熟度**：非常活跃，v0.12.3.dev0，每天合并多个 PR。文档 完整：README（36KB）、AGENTS.md（21KB 开发者指南）、spec-driven.md（26KB 方法论）、docs/ 下有 quickstart / concepts / reference / guides、CHANGELOG（69KB）、newsletters 月度简报。

## 2. 安装机制

### pip/uv 安装

```bash
uv tool install specify-cli  # 或 pip install specify-cli
```

CLI 入口点：`specify` 命令（通过 pyproject.toml 的 `[project.scripts]` 定义，指向 `specify_cli:main`）。

### `specify init` 做了什么

交互式引导，选择 AI Agent 集成 + 脚本类型（bash/powershell）后：

1. **Agent 预检**：对 CLI 型 Agent 执行 `shutil.which(key)` 检查可执行文件是否存在
2. **集成安装**：调用对应 Integration 子类的 `setup()` 方法，将命令模板渲染为 Agent 原生格式
3. **共享基础设施安装**：拷贝 shell 脚本 + 页面模板到 `.specify/` 目录
4. **宪法模板**：将 `constitution-template.md` 拷贝到 `.specify/memory/constitution.md`
5. **workflow 安装**：安装 bundled `speckit` workflow（完整 SDD 循环）
6. **集成元数据**：写入 `speckit.manifest.json` 和 `init-options.json`

### 改动的配置文件

| 文件 | 说明 |
|------|------|
| `CLAUDE.md` / `AGENTS.md` / `.github/copilot-instructions.md` 等 | 取决于 Agent 类型，由 `agent-context` 扩展管理（可选） |
| `.specify/memory/constitution.md` | 项目宪法 |
| `.specify/templates/` | 命令模板、计划模板、任务模板等 |
| `.specify/scripts/{bash,powershell}/` | shell 脚本 |
| `.specify/extensions/agent-context/agent-context-config.yml` | 上下文注入配置 |
| `.claude/skills/speckit-*/SKILL.md` | Claude Code 专属：安装为 Skills |
| `speckit.manifest.json` | 文件清单（用于升级/清理） |
| `init-options.json` | 项目初始化选项记录 |

### Symlink 策略

部分 Agent 支持 `dev_no_symlink`，但默认情况下：集成安装**直接写入文件**，不做 symlink。源码中的 `_locate_core_pack()` 和 `_repo_root()` 支持从开发工作树解析路径，用于 dev 模式。

## 3. 提供的工具全景

### CLI 工具（`specify` 命令）

| 子命令 | 说明 |
|--------|------|
| `specify init` | 初始化项目 |
| `specify check` | 检查 Agent CLI 工具是否安装 |
| `specify version` | 显示版本 + feature flags |
| `specify integration list/search/info/install/uninstall/switch/upgrade` | 集成管理 |
| `specify extension search/add/remove/list/upgrade` | 扩展管理（非核心功能） |
| `specify preset search/add/remove/list` | 预设管理（模板覆盖） |
| `specify bundle add/remove/list` | 捆绑包管理（角色级方案） |
| `specify workflow add/remove/list/run/validate` | 工作流管理 |
| `specify self check/upgrade` | 自身升级检测 |
| `specify catalog search/info` | 社区目录搜索 |

### Slash Commands / Skills（10 个核心命令）

安装后 Agent 可用的命令（格式因 Agent 而异，如 `/speckit.specify` 或 `/speckit-specify`）：

| 命令 | 类型 | 说明 |
|------|------|------|
| `/speckit.constitution` | 核心 | 创建或更新项目治理原则 |
| `/speckit.specify` | 核心 | 定义需求（从自然语言生成 spec.md） |
| `/speckit.plan` | 核心 | 创建技术实现计划 |
| `/speckit.tasks` | 核心 | 生成可执行任务列表 |
| `/speckit.implement` | 核心 | 按任务列表执行实现 |
| `/speckit.converge` | 核心 | 评估代码库 vs spec/plan/tasks 差距 |
| `/speckit.taskstoissues` | 核心 | 将 tasks.md 转为 GitHub Issues |
| `/speckit.clarify` | 可选 | 澄清 spec 中模糊区域 |
| `/speckit.analyze` | 可选 | 跨文件一致性/覆盖度分析 |
| `/speckit.checklist` | 可选 | 生成质量检查清单 |

### Shell 脚本（5 个 bash + 5 个 powershell）

| 脚本 | 用途 |
|------|------|
| `check-prerequisites.sh` | 统一前提检查（feature 目录、文件存在性等） |
| `common.sh` | 公共函数：路径解析、Git 操作 |
| `create-new-feature.sh` | 创建 feature 分支和目录 |
| `setup-plan.sh` | 拷贝 plan 模板到 feature 目录 |
| `setup-tasks.sh` | 校验前置文件并准备 tasks 模板 |

### 扩展（Extensions，4 个内置）

| 扩展 | 说明 |
|------|------|
| `agent-context` | 管理 Agent 上下文文件（CLAUDE.md 等），注入 Spec Kit 托管区块 |
| `git` | Git 操作：初始化仓库、创建 feature 分支、自动提交、远程检测 |
| `bug` | Bug 处理：评估（assess）、修复（fix）、验证（test） |
| `selftest` | 扩展生命周期自测试（从 catalog 发现 -> 安装 -> 注册验证） |

### 预设（Presets）

覆盖模板和命令提示词的一层。示例：`lean`（精简版模板）、社区预设（如 `pirate-speak`）。

### 捆绑包（Bundles）

角色级组合方案：将多个扩展 + 预设 + 模板打包为一个整体。通过 `specify bundle add` 安装。

### 工作流（Workflows）

YAML 定义的多步骤编排。内置 `speckit` workflow：`specify -> review gate -> plan -> review gate -> tasks -> implement`。

### 模板（Templates）

| 模板 | 说明 |
|------|------|
| `spec-template.md` | Feature 规格模板（用户场景、需求、成功标准） |
| `plan-template.md` | 技术实现计划模板（架构、数据模型、合约） |
| `tasks-template.md` | 任务分解模板（按 User Story 组织） |
| `constitution-template.md` | 项目宪法模板 |
| `checklist-template.md` | 质量检查清单模板 |
| `vscode-settings.json` | VS Code 设置（Copilot 专属） |

### Agent 集成（35+）

支持的 Agent：claude、copilot、gemini、opencode、codex、qwen、cursor-agent、cline、codebuddy、forge、goose、devin、kilocode、tabnine、qodercli、zed、windsurf、vibe、kimi、pi、kiro-cli、bob、rovodev、shai、junie、trae、zcode、firebender、lingma、auggie、omp、hermes、agy、amp、generic 等。

每个 Agent 是一个独立的 Python 子包（`src/specify_cli/integrations/<key>/__init__.py`），继承自基类之一（`MarkdownIntegration`、`TomlIntegration`、`SkillsIntegration`、`IntegrationBase`）。

### MCP Server

无。spec-kit 不提供 MCP server。

## 4. 核心工具详解

### 4.1 `/speckit.specify` -- 需求规格生成

这是 SDD 流程的起点，将用户的自然语言描述变为结构化的 feature spec。

**执行流程**：

1. **解析输入**：从 `$ARGUMENTS` 获取用户的功能描述
2. **运行前置脚本**：`check-prerequisites.sh --json`，解析得到 `FEATURE_DIR` 等路径变量
3. **加载上下文**：读取 `.specify/memory/constitution.md`（项目原则）、`spec-template.md`（模板）
4. **生成 feature 分支**（若尚不存在）：调用 `create-new-feature.sh`，自动编号和命名分支
5. **生成 spec.md**：按 `spec-template.md` 的结构填充 -- 用户场景（P1/P2/P3）、功能需求、成功标准、关键实体、边界条件。按模板约束严格执行：
   - 禁止过早涉及技术实现细节
   - 对于无法确定的事项用 `[NEEDS CLARIFICATION]` 标记（最多 3 个）
   - 每个需求必须是"可测试且无歧义"的
6. **质量验证**：按模板内置 checklist 逐项自检，最多 3 轮迭代修正
7. **澄清循环**（如有 `[NEEDS CLARIFICATION]`）：生成选项表 `A/B/C/Custom` 供用户选择
8. **写入** `specs/<###-feature-name>/spec.md`
9. **写入** `.specify/feature.json`（当前 feature 元数据）
10. **Post-Execution**：检查扩展 hooks（agent-context update、git auto-commit 等）

**输入**：自然语言功能描述（`$ARGUMENTS`）

**输出**：`specs/<###-feature>/spec.md`（包含完整规格）

**调用底层能力**：Bash（运行 shell 脚本）、Read（读取模板和宪法）、Write（写入 spec 文件）

**关键设计决策**：
- 模板强制使用 checklist 门禁（必须在报告中输出 pass/fail 矩阵）
- "最多 3 个澄清"原则避免过度追问用户
- 自动生成分支编号和时间戳

### 4.2 `/speckit.plan` -- 技术实现计划

将 spec 转化为技术实现方案。

**执行流程**：

1. **运行前置脚本**：`setup-plan.sh --json`，解析路径变量、获取模板
2. **加载上下文**：spec.md、constitution.md、现有代码库结构
3. **Phase 0: 研究**：填充技术上下文、澄清 spec 中的技术不确定性，输出 `research.md`
4. **Phase 1: 设计与合约**：
   - 从 spec 提取实体 -> `data-model.md`
   - 定义接口合约（API/CLI/UI）-> `/contracts/`
   - 编写快速验证指南 -> `quickstart.md`
5. **填充 plan.md**：技术架构、依赖选型、项目结构、复杂度跟踪
6. **宪法合规检查**：校验 plan 是否与 constitution.md 的 MUST 原则冲突
7. **Post-Execution hooks**：agent-context update、git 扩展 hooks

**输入**：spec.md（自动发现）、constitution.md

**输出**：`specs/<###-feature>/plan.md`、`research.md`、`data-model.md`、`contracts/`、`quickstart.md`

**关键设计决策**：
- 强制在 Phase 0 完成 research 后才进入设计
- 接口合约按项目类型自适应（library 输出 API、CLI 输出命令 schema 等）
- `quickstart.md` 禁止包含完整实现代码

### 4.3 `/speckit.tasks` -- 任务分解

将 plan 分解为可独立实现和测试的任务。

**执行流程**：

1. **运行前置脚本**：`setup-tasks.sh --json`，校验 spec.md 和 plan.md 存在
2. **加载上下文**：spec.md、plan.md、data-model.md、contracts/
3. **按 User Story 组织任务**：
   - Phase 1: Setup（项目初始化）
   - Phase 2: Foundational（跨 Story 的基础组件）
   - Phase 3+: 每个 User Story 一个 Phase（P1 -> P2 -> P3）
   - Final Phase: Polish（优化、文档）
4. **任务格式标准化**：`- [ ] [TaskID] [P?] [Story?] Description with file path`
   - `[P]` = 可并行（不同文件、无依赖）
   - `[US1]` = 所属 User Story
5. **依赖管理**：顺序任务 vs 并行任务的分组
6. **TDD 集成**：如 spec 要求测试，测试任务排在对应实现任务之前
7. **写入** `tasks.md`
8. **Post-Execution hooks**

**输入**：spec.md、plan.md、data-model.md

**输出**：`specs/<###-feature>/tasks.md`（含所有 phase、并行标记、文件路径）

**关键设计决策**：
- 任务必须按 User Story 分组，便于独立实现和交付
- 文件路径必须精确到 `src/models/user.py` 级别
- 每个 Story phase 有独立 checkpoint，支持增量交付
- `[P]` 标记用于 implement 阶段的并行执行

### 4.4 `/speckit.implement` -- 执行实现

按 tasks.md 逐个执行所有任务。

**执行流程**：

1. **运行前置脚本**：`check-prerequisites.sh --json --require-tasks --include-tasks`
2. **加载上下文**：spec.md、plan.md、tasks.md、data-model.md、contracts/
3. **解析 tasks.md**：提取 phase、依赖关系、并行标记、文件路径
4. **Phase 逐阶段执行**：
   - Setup -> Foundational -> User Stories (P1..Pn) -> Polish
   - 每个 phase 内：先执行测试任务（如有），再执行实现任务
5. **并行执行**：带 `[P]` 标记的任务可并行运行
6. **文件协调**：涉及同一文件的任务强制串行
7. **进度跟踪**：每完成一个任务，将 `- [ ]` 改为 `- [X]` 写入 tasks.md
8. **错误处理**：非并行任务失败立即停止；并行任务失败只报告，继续其他
9. **完成验证**：检查所有任务完成、功能符合 spec、测试通过
10. **Post-Execution hooks**：git auto-commit、agent-context update

**输入**：spec.md、plan.md、tasks.md

**输出**：实际代码文件 + 更新后的 tasks.md（所有 checkbox 打勾）

**关键设计决策**：
- 严格 TDD 顺序（测试先于代码）
- 文件级协调（避免并发写入同一文件）
- 失败立即停止（非并行任务）的策略保护代码一致性

### 4.5 Agent 集成系统

spec-kit 最核心的工程架构，使其支持 35+ AI Agent。

**集成基类体系**：

```
IntegrationBase (ABC)
├── MarkdownIntegration  -- 标准 Markdown 格式（Claude、Cursor、Copilot 等）
│   配置：folder + commands_subdir + args="$ARGUMENTS"
│   生成：.md 文件，带 YAML frontmatter
├── TomlIntegration      -- TOML 格式（Gemini、Tabnine）
│   配置：args="{{args}}"
│   生成：.toml 文件
├── YamlIntegration      -- YAML 格式（Goose）
└── SkillsIntegration    -- Skills 模式（Claude、Codex、Copilot Skills）
    生成：speckit-<name>/SKILL.md 目录结构
    命令调用：/speckit-<name> 而非 /speckit.<name>
```

**添加新集成的步骤**：
1. 选择基类
2. 创建 `src/specify_cli/integrations/<key>/__init__.py`
3. 实现子类（设置 `key`、`config`、`registrar_config`）
4. 在 `integrations/__init__.py` 的 `_register_builtins()` 中注册
5. 可选覆盖：`build_command_invocation()`、`inject_argument_hint()`、`process_template()` 等

**模板渲染**：
- 命令模板文件位于 `templates/commands/`（无 `speckit.` 前缀）
- 渲染时 `{SCRIPT}` 替换为集成专属脚本路径
- `$ARGUMENTS` 或 `{{args}}` 取决于 Agent 格式
- `__SPECKIT_COMMAND_<NAME>__` 占位符替换为实际命令调用（如 `/speckit.specify`）

## 5. 文件规范

### 目录结构（安装到用户项目后）

```
<project>/
├── .specify/
│   ├── memory/
│   │   └── constitution.md          # 项目宪法（治理原则）
│   ├── templates/
│   │   ├── commands/                # 命令模板（10 个 .md）
│   │   ├── spec-template.md
│   │   ├── plan-template.md
│   │   ├── tasks-template.md
│   │   ├── constitution-template.md
│   │   └── checklist-template.md
│   ├── scripts/
│   │   ├── bash/                    # 5 个 shell 脚本
│   │   └── powershell/              # 5 个 PowerShell 脚本
│   ├── extensions/                  # 已安装的扩展
│   │   └── agent-context/           # （可选）上下文管理
│   ├── feature.json                 # 当前 feature 元数据
│   ├── init-options.json            # 初始化选项
│   └── speckit.manifest.json       # 安装文件清单
├── specs/
│   └── <###-feature-name>/         # 每个 feature 一个目录
│       ├── spec.md
│       ├── plan.md
│       ├── tasks.md
│       ├── research.md
│       ├── data-model.md
│       ├── quickstart.md
│       └── contracts/
├── .claude/skills/                  # Claude Code 专属（Skills 模式）
│   └── speckit-<name>/SKILL.md
└── CLAUDE.md                        # （可选）由 agent-context 扩展注入
```

### 命名约定

- **命令文件**：模板中为 `specify.md`、`plan.md`；安装后根据集成变为 `speckit.specify.md` 或 `speckit-specify/SKILL.md`
- **Feature 分支**：`<###>-<cleaned-description>`（如 `001-add-user-auth`）
- **Python 包**：使用下划线（`kiro_cli/`），但集成 key 保持规范形式（`"kiro-cli"`）
- **模板占位符**：`{SCRIPT}`、`$ARGUMENTS`（Markdown）、`{{args}}`（TOML）、`__SPECKIT_COMMAND_<NAME>__`

### Frontmatter / Metadata Schema

**命令模板（YAML frontmatter）**：
```yaml
---
description: "命令描述"
scripts:
  sh: scripts/bash/check-prerequisites.sh --json
  ps: scripts/powershell/check-prerequisites.ps1 -Json
handoffs:
  - label: Create Tasks
    agent: speckit.tasks
    prompt: Break the plan into tasks
    send: true
---
```

**扩展 manifest（extension.yml）**：
```yaml
schema_version: "1.0"
extension:
  id: agent-context
  name: "Coding Agent Context"
  version: "1.0.0"
  description: "..."
  author: spec-kit-core
requires:
  speckit_version: ">=0.2.0"
provides:
  commands:
    - name: speckit.agent-context.update
      file: commands/speckit.agent-context.update.md
hooks:
  after_specify:
    command: speckit.agent-context.update
    optional: true
```

**工作流定义（workflow.yml）**：
```yaml
schema_version: "1.0"
workflow:
  id: "speckit"
  name: "Full SDD Cycle"
requires:
  speckit_version: ">=0.8.5"
  integrations:
    any: ["claude", "copilot", "gemini", "opencode"]
inputs:
  spec: { type: string, required: true, prompt: "Describe what you want to build" }
steps:
  - id: specify
    command: speckit.specify
  - id: review-spec
    type: gate
    options: [approve, reject]
    on_reject: abort
  # ... plan, review-plan, tasks, implement
```

## 6. SessionStart 注入

spec-kit 本身**没有** SessionStart hook。上下文注入由**可选的** `agent-context` 扩展负责。

### 注入机制

1. **不自动注入**：`specify init` 不会安装 `agent-context` 扩展。用户需手动安装：`specify extension add agent-context`
2. **注入方式**：扩展的脚本 `update-agent-context.sh` 在 Agent 上下文文件的标记区块内写入内容
3. **标记区块**：通过 `agent-context-config.yml` 中的 `context_markers` 配置，默认：
   ```
   <!-- SPECKIT START -->
   ...托管内容...
   <!-- SPECKIT END -->
   ```
4. **触发时机**：通过 extension hooks 配置，在 `after_specify` 和 `after_plan` 事件后触发

### 注入内容

扩展脚本读取 plan.md 并生成托管区块，包含：
- 当前 project 的 plan 文件引用
- spec-kit 工作流指引
- 各命令的快速参考

### Context 消耗量预估

注入的托管区块通常 < 1KB（几行到十几行 markdown），对 context 消耗极小。但**命令文件本身**（每个 spec-kit 命令的完整模板提示词）非常长：单个命令如 specify.md 就有 200+ 行，全量 10 个命令约 3000+ 行。在 Claude Code 中这些被安装为 Skills（按需加载），不占用初始 context；在 Copilot 等 Agent 中作为 `.prompt.md` 存在，也不在每次对话中自动注入。

## 7. 状态管理

### 项目初始化状态

| 文件 | 内容 |
|------|------|
| `.specify/init-options.json` | 所选 Agent key、脚本类型、是否 skills 模式 |
| `.specify/speckit.manifest.json` | 所有已安装文件的清单（路径 + hash），用于升级检测 |

### Feature 状态

| 文件 | 内容 |
|------|------|
| `.specify/feature.json` | 当前 feature 路径、分支名、编号 |
| `specs/<###-feature>/spec.md` | Feature 规格 |
| `specs/<###-feature>/plan.md` | 实现计划 |
| `specs/<###-feature>/tasks.md` | 任务列表（checkbox 格式，implement 后打勾） |
| `specs/<###-feature>/research.md` | 技术研究 |
| `specs/<###-feature>/data-model.md` | 数据模型 |
| `specs/<###-feature>/contracts/` | 接口合约 |
| `specs/<###-feature>/checklists/` | 质量检查清单 |

### 扩展状态

| 文件 | 内容 |
|------|------|
| `.specify/extensions/agent-context/agent-context-config.yml` | 上下文注入配置 |
| `.specify/extensions/<ext>/` | 各扩展自己的 scripts/commands/ 目录 |

### 记忆机制

- **constitution.md**：项目宪法，所有 spec/plan/tasks 阶段都会读取，作为不可变原则
- **checklists**：每次 spec/plan 生成后附带 checklists 验证结果
- 无 session 记忆或持久化对话历史

### 版本追踪

- `specify self check`：对比本地版本与 GitHub Release 最新版
- `specify self upgrade`：自动升级 CLI

## 8. 编排模式

### 单 Agent 模式

默认模式。用户逐个执行 `/speckit.specify` -> `/speckit.plan` -> `/speckit.tasks` -> `/speckit.implement`，每步包含人工 review gate。

### Pipeline 模式（Workflow 引擎）

通过 `specify workflow run speckit` 启动自动化 pipeline：

```
specify ──→ [review gate] ──→ plan ──→ [review gate] ──→ tasks ──→ implement
```

Workflow YAML 定义支持：
- **step 编排**：顺序步骤 + 并行 fan-out（通过 `max_concurrency` 控制）
- **gate 步骤**：approve/reject 人工门禁
- **条件分支**：基于上一步输出决定下一步
- **while/do-while 循环**：条件循环执行
- **模板变量**：`{{ inputs.spec }}` 等 Jinja2 风格占位符
- **多集成支持**：不同 step 可指定不同 Agent

### 扩展 Hook 模式

扩展可以通过 `hooks` 声明在特定事件后触发：

```yaml
hooks:
  after_specify:
    command: speckit.agent-context.update
    optional: true
  after_plan:
    command: speckit.git.commit
    optional: true
```

当前支持的 hook 事件：`before_specify`、`after_specify`、`before_plan`、`after_plan`、`after_implement` 等。

### 无多 Agent / Leader-Worker / DAG

spec-kit 本身**不内置**多 Agent 协作编排。它生成的命令由单个 Agent 执行。但在生成的 `tasks.md` 中用 `[P]` 标记并行任务，理论上单个 Agent 可将这些并行任务分发给子 Agent 执行（取决于 Agent 自身能力）。

### 集成注册表模式

35+ Agent 适配通过统一的 `INTEGRATION_REGISTRY` 管理，每个 Agent 子类声明自己的元数据和能力，实现了 "添加一个子类、注册一次、测试一行" 的扩展契约。这里的 Agent 是 harness/工具适配，不是 35+ 并发 agent，也不是内置多 Agent 编排；核心价值是用面向对象的多态替代 if-else 分支，使添加新适配的代码量极小（通常 < 80 行）。
