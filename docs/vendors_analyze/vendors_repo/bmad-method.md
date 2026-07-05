# bmad-method

## 1. 概览

### 一句话定位

BMad Method（v6.9.0）是一个面向 AI 编程 Agent 的结构化开发方法论与工作流系统。通过 **命名角色 Agent、分阶段工作流、渐进式上下文构建** 三重机制，将模糊的产品意图转化为可实施的代码；推进方式仍依赖用户按阶段选择/触发对应 skill，而非完全无人值守编排。

### 设计哲学

- **渐进式上下文工程**：4 个阶段逐步产出文档（brief → PRD → architecture → stories），每个阶段产出是下阶段的输入，Agent 始终知道要构建什么以及为什么。
- **命名 Agent 角色**：每个 Agent 有固定身份（姓名、性格、沟通风格、原则），角色人格化以提升交互一致性和用户体验。
- **工作流即技能**：每个 Agent 能力以"菜单项"形式暴露（如 PRD、DS、CR），用户通过自然语言触发，Agent 内部按 step-file 逐步执行。
- **可定制三层合并**：base（默认）、team（团队）、user（个人）三个层级按结构合并规则整合，不改动上游文件即可覆盖。

### 成熟度

- **commit 频率**：极高。2026 年 6 月几乎每日提交（参见 git log），最近一个月 30+ 次提交。
- **版本演进**：从 v6.7.0 → v6.9.0，已迭代多个大版本，v6 是重大重构版本。
- **文档完整度**：极高。docs/ 下有 tutorials、how-to、explanation、reference 四个分区，含中/法/捷/越 4 种语言的翻译文档，另有完整的 Astro 文档站点。
- **测试覆盖**：test/ 目录包含安装器集成测试、技能校验测试、URL 解析测试、channel 测试等。
- **社区**：多语言 README（中/越），Discord 社区，开源 MIT 协议。

---

## 2. 安装机制

### install 命令

```
npx bmad-method install
# 或
node tools/installer/bmad-cli.js install
```

核心流程（installer.js，1711 行）：

1. 收集用户输入（交互式 prompt 或 CLI 参数）：目标目录、要安装的模块、目标 IDE、语言设置、输出目录等。
2. 创建 `_bmad/` 目录结构（`_config/`、`core/`、`scripts/`、`custom/`）。
3. 解析模块来源（核心内置模块 + 官方模块仓库 + 自定义模块）。
4. 复制技能文件（SKILL.md + 附属文件）到目标 IDE 的技能目录。
5. 生成配置和清单文件（manifest.yaml、skill-manifest.yaml、files-manifest.csv、bmad-help.csv）。
6. 为目标 IDE 生成"命令指针"文件（command pointer files）。
7. 清理 `_bmad/` 中冗余的技能副本（技能已存入 IDE 目录后删除）。

### 改动的文件

安装**不修改**用户的 `settings.json`、CLAUDE.md、hooks 配置。

安装只写入：
- **`_bmad/` 目录**：项目级配置和脚本（`{project-root}/_bmad/`）
  - `_bmad/_config/manifest.yaml` — 已安装清单
  - `_bmad/_config/skill-manifest.yaml` — 技能静态信息
  - `_bmad/_config/files-manifest.csv` — 文件清单及哈希
  - `_bmad/_config/bmad-help.csv` — 帮助系统数据
  - `_bmad/core/config.yaml` — 全局配置（语言、用户名、输出目录等）
  - `_bmad/scripts/resolve_customization.py` — TOML 合并脚本
  - `_bmad/scripts/resolve_config.py` — 配置解析
  - `_bmad/scripts/memlog.py` — 会话记忆管理
  - `_bmad/custom/` — 团队/个人覆盖目录

- **IDE 技能目录**：
  - Claude Code: `.claude/skills/bmad-*/`（每个技能一个子目录）
  - 支持 17+ IDE（Claude Code、Cursor、Codex、GitHub Copilot、Windsurf、Cline 等）

### symlink 策略

不使用 symlink。直接复制文件。更新时覆盖写入。

---

## 3. 提供的工具全景

### 3.1 Skills / Slash Commands（技能）

分两大类：**核心技能**（core-skills）和 **BMM 方法论技能**（bmm-skills）。

#### 核心技能（`src/core-skills/`）

| 名称 | 用途 |
|------|------|
| `bmad-help` | 检测项目状态、已完成的工件、推荐下一步 |
| `bmad-brainstorming` | 受引导的头脑风暴，100+ 创意生成 |
| `bmad-party-mode` | 多 Agent 群组讨论，指定或自动选择角色 |
| `bmad-spec` | 从意图生成结构化 SPEC.md，支持多源合并 |
| `bmad-advanced-elicitation` | 高级需求启发技术库 |
| `bmad-forge-idea` | 压力测试一个创意直到硬化、证伪或低成本死亡 |
| `bmad-review-adversarial-general` | 通用对抗性审查 |
| `bmad-review-edge-case-hunter` | 边界案例搜索 |
| `bmad-editorial-review-prose` | 文档文字审查 |
| `bmad-editorial-review-structure` | 文档结构审查 |
| `bmad-shard-doc` | 大文档分片工具 |
| `bmad-index-docs` | 文档索引生成 |
| `bmad-customize` | 技能自定义管理 |

#### BMM 方法论技能 —— 按 4 阶段组织

**Phase 1: Analysis（分析）**—— `src/bmm-skills/1-analysis/`
- `bmad-agent-analyst` — 分析角色 Mary，可触发所有 Phase 1 工作流
- `bmad-agent-tech-writer` — 技术写作角色 Paige
- `bmad-document-project` — 项目文档化扫描
- `bmad-prfaq` — PR/FAQ 工作回溯法
- `bmad-product-brief` — 产品简述
- `research/bmad-domain-research` / `bmad-market-research` / `bmad-technical-research` — 三类研究

**Phase 2: Planning（规划）**—— `src/bmm-skills/2-planning/`（目录存在但为空，可能合并到 solutioning）

**Phase 3: Solutioning（方案设计）**—— `src/bmm-skills/3-solutioning/`
- `bmad-agent-architect` — 架构师角色 Winston
- `bmad-architecture` — 架构决策（产出 ARCHITECTURE-SPINE.md）
- `bmad-create-architecture` — 创建架构
- `bmad-create-epics-and-stories` — 分解为 Epic 和 Story
- `bmad-check-implementation-readiness` — 实施就绪检查（PASS/CONCERNS/FAIL）
- `bmad-generate-project-context` — 生成项目上下文

**Phase 4: Implementation（实施）**—— `src/bmm-skills/4-implementation/`
- `bmad-agent-dev` — 开发者角色 Amelia
- `bmad-checkpoint-preview` — 检查点预览（多步逐步审查）
- `bmad-code-review` — 对抗性代码审查（Blind Hunter + Edge Case Hunter + Acceptance Auditor 三层并行）
- `bmad-correct-course` — 中期纠正
- `bmad-create-story` — 创建 Story
- `bmad-dev-auto` — 无人值守自动化开发循环
- `bmad-dev-story` — Story 开发实施
- `bmad-qa-generate-e2e-tests` — 生成 E2E 测试
- `bmad-quick-dev` — 快速开发（跳过 Phase 1-3）
- `bmad-retrospective` — 回顾
- `bmad-sprint-planning` — Sprint 计划
- `bmad-sprint-status` — Sprint 状态跟踪

### 3.2 Agents（命名角色 Agent）

每个命名 Agent 是一个加载了特定 persona 的技能，具有固定名称、角色、沟通风格和菜单触发器：

| Agent | 姓名 | 技能 ID | 主要触发器 |
|-------|------|---------|-----------|
| 分析师 | Mary | `bmad-agent-analyst` | BP, MR, DR, TR, CB, WB, DP |
| 产品经理 | John | `bmad-agent-pm` | PRD, CE, IR, CC |
| 架构师 | Winston | `bmad-agent-architect` | CA, IR |
| 开发者 | Amelia | `bmad-agent-dev` | DS, QD, QA, CR, SP, CS, ER |
| UX 设计师 | Sally | `bmad-agent-ux-designer` | CU |
| 技术写作 | Paige | `bmad-agent-tech-writer` | DP, WD, MG, VD, EC |

Agent 角色通过 `customize.toml` 中的 `[agent]` 块定义，区别于 `[workflow]` 块的工作流技能。

### 3.3 CLI 工具

- **`bmad` / `bmad-method`**：Node.js CLI（`tools/installer/bmad-cli.js`）
  - `install`：安装 BMad 核心和模块
  - `uninstall`：卸载
  - `status`：查看安装状态
  - 支持 `--modules`、`--tools`、`--yes`、`--channel`、`--pin`、`--set` 等参数

### 3.4 Python 脚本

安装后复制到 `_bmad/scripts/`：
- **`resolve_customization.py`**：三层 TOML 合并引擎（base → team → user），解析 customize.toml 的 `workflow` 或 `agent` 块
- **`resolve_config.py`**：配置解析
- **`memlog.py`**：会话记忆读写（`.memlog.md` 文件），支持 key-value 型持久化

### 3.5 Web Bundles

独立的单文件 HTML 工具包（`web-bundles/`），不需安装即可使用：
- `brainstorming-coach` — 头脑风暴教练
- `market-and-industry-research` — 市场与行业研究
- `prd-coach` — PRD 教练
- `prfaq-coach` — PR/FAQ 教练
- `product-brief-coach` — 产品简述教练
- `ux-coach` — UX 教练

### 3.6 模块系统 / Marketplace Plugin

- **`bmad-modules.yaml`**：官方模块注册表，定义所有可安装扩展模块（BMad Auto、Builder、Creative Intelligence Suite、Game Dev Studio、Test Architect 等）
- **`.claude-plugin/marketplace.json`**：Claude Code 插件市场定义，列出所有技能路径
- 模块支持 `marketplace-plugin` 模式（技能分散在不同目录，通过 plugin resolver 解析）
- 支持 channel（stable/next）和 version pin 机制

### 3.7 IDE/工具适配

`tools/installer/ide/` 支持 17+ IDE/工具的目标目录和命令指针生成：
- Claude Code、Cursor、Codex、GitHub Copilot、Windsurf、Cline、Roo Code、KiloCoder、OpenCode 等
- 每个平台有独立的 `target_dir`、`global_target_dir`、可选的 `commands_target_dir`
- 命令指针文件是各平台的"快捷方式"（如 Claude Code 的 `.claude/skills/` 下的 SKILL.md）

### 3.8 Augment IDE 集成

`.augment/code_review_guidelines.yaml`：Augment IDE 的代码审查指南配置。

### 3.9 Astro 文档站点

`website/` 目录包含完整的 Astro 文档站点，多语言支持（英/中/法/越/捷）。

---

## 4. 核心工具详解

### 4.1 三层自定义合并系统（customize.toml + resolve_customization.py）

BMad 的核心配置机制。每个技能（Agent 或 Workflow）都有一个 `customize.toml`，定义 persona、工作流步骤、持久事实和触发器菜单。

**执行流程：**

1. 技能激活时，首先运行 `uv run {project-root}/_bmad/scripts/resolve_customization.py --skill {skill-root} --key workflow`（或 `--key agent`）
2. resolve_customization.py 按优先级读取并合并三个文件：
   - `{skill-root}/customize.toml` — 默认值（base）
   - `{project-root}/_bmad/custom/{skill-name}.toml` — 团队覆盖（team）
   - `{project-root}/_bmad/custom/{skill-name}.user.toml` — 个人覆盖（user）
3. 合并规则：
   - 标量值：覆盖
   - 数组（persistent_facts、principles、activation_steps_*）：追加
   - 含 `code` 或 `id` 键的 table 数组：按 code/id 匹配替换，未匹配的追加
4. 输出 JSON 到 stdout，供技能 prompt 使用

**关键设计决策**：三层结构让团队可以覆盖默认行为（团队规范），个人可以进一步微调（个人偏好），而不修改上游文件。更新时不会丢失自定义。

**输入**：`--skill <path> --key workflow|agent`  
**输出**：JSON（合并后的 workflow 或 agent 配置块）  
**底层能力**：Bash（uv run python）

### 4.2 Step-File 工作流架构

BMad 工作流技能采用 **分步微文件架构**。

**执行流程：**

1. Agent 技能加载 persona 后，呈现菜单（来自 customize.toml 的 `[agent.capabilities]`）
2. 用户选择菜单项或直接说出意图，Agent 匹配到对应工作流
3. 工作流激活：读取步骤文件列表（如 `step-01-orientation.md`、`step-02-walkthrough.md` 等）
4. **每次只加载当前步骤文件**，完整读取后执行
5. 执行完当前步骤后，加载下一个步骤文件
6. 遇到检查点时暂停等待用户确认
7. 所有步骤执行完毕，产出最终工件

**关键约束：**
- 绝不跳过步骤或优化顺序
- 绝不同时加载多个步骤文件
- 检查点必须等待用户输入
- 工件逐步追加构建

**示例**（bmad-checkpoint-preview）：
- step-01-orientation.md → step-02-walkthrough.md → step-03-detail-pass.md → step-04-testing.md → step-05-wrapup.md

**设计原因**：分步加载控制上下文窗口消耗，每次只加载当前步骤，避免超长 prompt 导致注意力衰减。

**底层能力**：Read（读取步骤文件）、Write（写入产出工件）

### 4.3 命名 Agent 角色系统（bmad-agent-*）

将 AI Agent 人格化为具有固定身份的专家角色。

**执行流程：**

1. 用户激活技能 `bmad-agent-dev`
2. Skill 启动，执行 8 步激活序列：
   - Step 1：运行 resolve_customization.py 解析 `[agent]` 块
   - Step 2：执行 `activation_steps_prepend` 挂载步骤
   - Step 3：采用 persona（姓名、角色、沟通风格、原则）
   - Step 4：加载 `persistent_facts` 作为会话持续上下文
   - Step 5：加载 `_bmad/core/config.yaml` 全局配置
   - Step 6：用配置的语言问候用户
   - Step 7：执行 `activation_steps_append` 挂载步骤
   - Step 8：呈现菜单或分发到工作流
3. 整个会话中 Agent 保持角色一致（姓名、语气、原则）

**关键设计**：`[agent]` 块 vs `[workflow]` 块的区别 —— 前者有 persona（姓名、沟通风格），后者没有。这决定了安装器生成"Agent 技能"和"工作流技能"两类不同的命令指针。

**示例角色（Amelia）：**
- 姓名：Amelia
- 标题：Senior Software Engineer
- 沟通风格："Professional and methodical, Amelia ensures every detail is addressed before declaring anything complete"
- 角色："Help users implement stories with strict adherence to specs and established project conventions"
- 原则：8 条（Always review the story spec、Map unknown territory before coding、Generate fill lists 等）

**底层能力**：Read（读取 persona 定义、配置文件）、Bash（uv run resolve_customization）

### 4.4 Party Mode（多 Agent 群组讨论）

允许多个 BMad Agent 同时参与一个对话主题。

**执行流程：**

1. 加载 `bmad-party-mode` 技能
2. 运行 resolve_customization.py 获取 workflow 配置
3. 运行 `resolve_party.py` 解析参与 Agent 名单（从已安装 Agent 中按 `default_party` 组选择，或用户指定）
4. 确定运行模式（四种）：
   - **`session`**：单 Agent 切换 persona 发言（默认，所有平台可用）
   - **`auto`**：普通对话内联，仅在独立思考改变结果时生成真正的子 Agent
   - **`subagent`**：每轮为每个 persona 生成独立子 Agent，各自独立思考
   - **`agent-team`**（Claude Code only）：persistent team，Agent 之间直接互相 @mention
5. 如果 `memory_enabled`，加载 per-party 的 `.memlog.md` 记忆
6. 欢迎用户，展示参与 Agent 名单（icon + name + 角色）
7. 进入交互循环：用户输入 → 各 Agent 轮流发言 → 等待下轮输入
8. 用户说 `goodbye` / `end party` / `quit` 后退出

**关键约束：** party 是无限交互的，不因单次请求完成而结束。`--non-interactive` 标志是唯一例外。

**底层能力**：Agent tool（生成子 Agent）、Bash（uv run 脚本）、Read（记忆文件）

### 4.5 bmad-code-review（对抗性代码审查）

三层并行审查的代码审查系统。

**执行流程：**

1. 加载 `bmad-code-review` 技能
2. 收集上下文（变更内容、关联 spec/story）
3. 启动 3 个并行审查层：
   - **Blind Hunter**：不看 spec，只审代码质量
   - **Edge Case Hunter**：边界案例和异常路径
   - **Acceptance Auditor**：对照 spec/story 检查验收标准
4. 收集各层发现，按严重度分类（CRITICAL / HIGH / MEDIUM / LOW）
5. 结构化分类：安全、正确性、性能、可维护性等
6. 输出审查报告

**底层能力**：Agent tool（3 个并行子 Agent）、Read（变更上下文）

---

## 5. 文件规范

### 5.1 目录结构

```
bmad-method/
├── .claude-plugin/          # Claude Code 插件市场定义
│   └── marketplace.json
├── .augment/                # Augment IDE 集成
│   └── code_review_guidelines.yaml
├── src/
│   ├── scripts/             # 安装后复制到 _bmad/scripts/
│   │   ├── memlog.py
│   │   ├── resolve_config.py
│   │   └── resolve_customization.py
│   ├── core-skills/         # 核心工具技能（平台无关）
│   │   ├── module.yaml      # core 模块定义
│   │   ├── module-help.csv  # 帮助系统数据
│   │   └── bmad-*/          # 每个技能一个目录
│   │       ├── SKILL.md     # 技能主定义
│   │       ├── customize.toml  # 可自定义配置（agent 或 workflow）
│   │       ├── scripts/     # 技能专属 Python 脚本
│   │       ├── references/  # 参考文档
│   │       └── assets/      # 模板等资源
│   └── bmm-skills/          # BMM 方法论技能
│       ├── 1-analysis/      # Phase 1：分析
│       ├── 2-planning/      # Phase 2：规划（空）
│       ├── 3-solutioning/   # Phase 3：方案设计
│       └── 4-implementation/ # Phase 4：实施
├── tools/
│   ├── installer/           # CLI 安装器（bmad 命令）
│   │   ├── bmad-cli.js      # CLI 入口
│   │   ├── commands/        # install / uninstall / status
│   │   ├── core/            # 核心逻辑
│   │   ├── ide/             # IDE 适配器
│   │   └── modules/         # 模块管理
│   └── build-docs.mjs       # 文档构建
├── docs/                    # 文档站点源文件
│   ├── tutorials/
│   ├── how-to/
│   ├── explanation/
│   ├── reference/
│   └── {cs,fr,vi-vn,zh-cn}/ # 多语言翻译
├── web-bundles/             # 独立 HTML 工具
├── website/                 # Astro 文档站点
├── test/                    # 测试套件
└── bmad-modules.yaml        # 官方模块注册表
```

### 5.2 命名约定

- **技能目录**：`bmad-{name}`（全小写，短横线分隔）
- **Agent 技能**：`bmad-agent-{role}`（但实际检测靠 `customize.toml` 中的 `[agent]` 块，而非命名约定——`bmad-tea` 没有 `-agent-` 但仍是 persona）
- **SKILL.md frontmatter**：YAML 格式的 `name` 和 `description`
- **customize.toml**：TOML 格式，包含 `[agent]` 或 `[workflow]` 块
- **步骤文件**：`step-NN-description.md`
- **参考文件**：`references/` 子目录下
- **脚本**：`scripts/` 子目录，Python 文件以功能命名

### 5.3 SKILL.md Frontmatter

```yaml
---
name: bmad-code-review
description: 'Review code changes adversarially using parallel review layers...'
---
```

仅两个字段。更多配置在 `customize.toml` 中。

### 5.4 customize.toml Schema

```toml
# --- 不可配置的 frontmatter ---
name = "Amelia"
title = "Senior Software Engineer"

# --- 可配置部分 ---
[agent]  # 或 [workflow]
activation_steps_prepend = [...]  # 激活前步骤
activation_steps_append = [...]   # 激活后步骤
persistent_facts = [...]          # 持久事实
principles = [...]                # 原则

[agent.communication]            # 仅 [agent] 块
role = "..."
identity = "..."
communication_style = "..."

[[agent.capabilities]]           # 菜单项
code = "DS"
skill = "bmad-dev-story"
```

---

## 6. SessionStart 注入

### BMad 不注入 SessionStart

BMad **不使用** Claude Code 的 SessionStart hook。它不修改 `settings.json`，不在每次会话开始时注入内容。

### 实际上下文加载机制

BMad 的上下文加载发生在 **技能激活时**（而非会话启动时）：

1. 用户手动调用技能（如 `bmad-agent-dev`）
2. 技能 SKILL.md 被完整加载（约 100-300 行）
3. 激活步骤依次执行：
   - `resolve_customization.py` 输出 JSON（约 50-100 行）
   - 加载 `config.yaml`（约 20 行）
   - 加载 `persistent_facts`（用户配置的事实，可变长度）
   - 加载 `project-context.md`（如存在）
4. 工作流步骤文件按需逐文件加载（每次一个文件）

### 预估 Context 消耗

单次技能激活的初始上下文约 **2,000-5,000 tokens**（SKILL.md + persona 定义 + 配置），加上后续步骤文件和工件加载。

---

## 7. 状态管理

### 7.1 memlog 记忆系统

`memlog.py`（`_bmad/scripts/memlog.py`）提供 per-workflow 的键值持久化：

- 格式：`.memlog.md`（Markdown 文件，在指定路径下）
- 操作：通过 CLI 参数 `--path`、`--field`、`--text`、`--type`、`--by`、`--key`、`--value` 读写
- 使用场景：`bmad-spec`、`bmad-prd`、`bmad-brainstorming` 等工作流产出 `.memlog.md` 记录会话状态
- Party mode 的记忆是 per-party 的 `.memlog.md`

### 7.2 清单系统（Manifest）

`_bmad/_config/` 下维护的安装状态：
- `manifest.yaml`：已安装模块及版本
- `skill-manifest.yaml`：所有已安装技能的静态信息
- `files-manifest.csv`：文件清单及内容哈希（用于更新检测）
- `bmad-help.csv`：帮助系统目录（所有技能的用途、输出位置、优先级）

### 7.3 Sprint 状态

`sprint-status.yaml`：Phase 4 的阶段跟踪文件，记录 Story 状态。

### 7.4 项目上下文

`project-context.md`：自动生成或手动维护的项目知识文件，被 Agent 作为 `persistent_facts` 加载。

### 7.5 检出/Checkpoint 系统

`bmad-checkpoint-preview` 技能提供分步审查，在实施过程中创建检查点供用户确认。不是自动化的持久 checkpoint，而是交互式的人类确认节点。

---

## 8. 编排模式

### 整体编排：Agent + Workflow 菜单模式

- **单 Agent 模式**：用户加载一个 Agent 技能（如 `bmad-agent-dev`），Agent 保持角色，通过菜单或自然语言触发工作流。整个会话由该 Agent 主导。
- **直接 Workflow 模式**：用户直接调用工作流技能（如 `bmad-code-review`），无需先加载 Agent。

### Party Mode 子 Agent 编排

Party Mode 的四种模式代表了不同的编排深度：

| 模式 | 编排方式 | 子 Agent 数量 |
|------|---------|-------------|
| `session` | 单 Agent 切换 persona | 0 |
| `auto` | 条件生成子 Agent | 0-3 |
| `subagent` | 每轮每 persona 一个独立子 Agent | 2-3 |
| `agent-team` | persistent team，互相 @mention | 2-3 |

### 并行审查模式

`bmad-code-review` 启动 3 个并行子 Agent（Blind Hunter、Edge Case Hunter、Acceptance Auditor），各独立工作后汇聚结果。

### Pipeline 模式（4 阶段）

Analysis → Planning → Solutioning → Implementation 的渐进式 pipeline，每阶段产出是下阶段的输入。但这不是自动化的 DAG 流水线——每个阶段需要人工触发。

### 无人值守模式

`bmad-dev-auto` 技能支持自动化开发循环：意图输入 → 规格生成 → 实施 → 审查 → 提交，全程无人值守。

---

## 9. 与 omni_powers 的对比关键差异

| 维度 | bmad-method | omni_powers |
|------|------------|-------------|
| 安装方式 | CLI 工具复制技能到项目 | git clone + `/opinit` 写 `$OP_HOME` 与 hooks |
| 配置注入 | 不修改 settings.json/CLAUDE.md | `/opinit` 写使用方 settings env，运行时按 `$OP_HOME` 定位 |
| Agent 模型 | 命名角色 persona（personality-driven） | 功能角色（op-implementer、op-reviewer、op-evaluator、op-closer） |
| 状态持久化 | memlog.py + manifest + sprint-status.yaml | `tasks_list.json` + `leader_checkpoint.md` + `op_record/` |
| hooks 使用 | 不使用 hooks | hooks 负责入口环境/路径纪律，流程由 skill + leader 驱动 |
| IDE 适配 | 17+ IDE | Claude Code only |
| 模块系统 | 官方模块注册表 + marketplace plugin | 无 |
| SessionStart 注入 | 无（按需加载） | 无大段 SessionStart 注入；依赖 skill 按需读取 `$OP_HOME` 文档 |
| 工作流控制 | step-file 架构 | `/oprun` leader 编排 + Sub Agent gate |
| 上下文消耗 | 低（渐进加载，2K-5K tokens 起步） | 按 skill/agent 读取，重历史放 op_record |
| 语言支持 | 多语言（含中文文档翻译） | 中文 |
