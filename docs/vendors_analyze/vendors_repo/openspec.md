# OpenSpec

> 分析日期：2026-07-02
> 仓库地址：https://github.com/Fission-AI/OpenSpec
> npm 包：`@fission-ai/openspec`
> 版本：v1.5.0

---

## 1. 概览

### 一句话定位
**AI 辅助开发的轻量级 specification 层**——让人类和 AI 在写任何代码之前先对规约达成一致。

### 设计哲学 / 解决什么问题
- **问题**：AI 编码助手的 prompt 驱动开发中，需求只存在于聊天历史里，不可审查、不可追溯、不可审计。
- **方案**：在项目中引入 `openspec/specs/`（源真）和 `openspec/changes/`（变更建议）两层文件系统结构，用 delta spec（ADDED/MODIFIED/REMOVED）描述变更，而非重写整个规约。
- **哲学**（官方原文）：fluid not rigid、iterative not waterfall、easy not complex、brownfield-first（主要面向已有代码库的增量变更）。

### 成熟度
- **commit 频率**：非常活跃，几乎每天有提交，releases 按时发布（Changeset 机制）。
- **文档完整度**：极高。19 个 docs/ 页面，覆盖入门、概念、CLI、命令、工作流、定制化、多语言、适配工具列表等。
- **生态**：支持 30+ AI 编码工具，npm 全局安装，社区 Discord 活跃。
- **star 数**：README 内含 star badge（但未截图到具体数字）。
- **license**：MIT。

---

## 2. 安装机制

### install.sh 或等效安装方式做了什么
OpenSpec **没有 install.sh**。安装方式是 npm 全局包：

```bash
npm install -g @fission-ai/openspec@latest
cd your-project
openspec init
```

### 改动了哪些配置文件
`openspec init` 会写如下文件：

1. **项目目录结构**：
   - `openspec/specs/` — 规约源真目录
   - `openspec/changes/` — 变更目录
   - `openspec/changes/archive/` — 归档目录
   - `openspec/config.yaml` — 项目级配置（schema 默认值、context、rules）

2. **AI 工具 Skills 文件**（由 `delivery` 配置控制是否生成）：
   - 对每个所选工具，在 `{skillsDir}/skills/openspec-{workflow}/SKILL.md` 生成 Agent Skills 标准格式文件
   - 例如 Claude Code：`.claude/skills/openspec-propose/SKILL.md`
   - YAML frontmatter 包含 `generatedBy: "x.y.z"` 版本追踪

3. **AI 工具 Commands 文件**（由 `delivery` 配置控制是否生成）：
   - 对每个所选工具，在对应目录下生成 slash command 文件
   - 例如 Claude Code：`.claude/commands/opsx/propose.md`

4. **全局配置**：
   - `~/.config/openspec/config.json`（遵循 XDG Base Directory）- 全局 profile/delivery 设置

### symlink 策略
**没有 symlink**。所有文件都是直接写入的物理文件。Skills 文件是小尺寸 Markdown 文件（几百字节），无所谓 symlink。

---

## 3. 提供的工具全景

### CLI 工具（可执行脚本）

| 命令 | 用途 |
|------|------|
| `openspec init` | 初始化项目（创建目录结构 + Skills + Commands + config.yaml） |
| `openspec update` | 刷新 Skills/Commands（版本升级后或配置变更后） |
| `openspec list` | 列出 active changes 或 specs |
| `openspec view` | 交互式 TUI dashboard |
| `openspec show <id>` | 用 JSON/Markdown 展示 change 或 spec |
| `openspec validate` | 校验 changes 或 specs |
| `openspec archive` | 归档完成的 change，merge delta spec |
| `openspec status` | 显示 change 的 artifact 完成状态 |
| `openspec instructions [artifact]` | 输出某 artifact 的生成指令（给 AI 用的） |
| `openspec templates` | 列出 schema 的 template 路径 |
| `openspec schemas` | 列出可用 schema |
| `openspec new change <id>` | 创建新 change 脚手架 |
| `openspec schema init/fork/validate/which` | 创建、fork、验证、定位 schema |
| `openspec config` | 查看/修改全局和项目配置 |
| `openspec store setup/register/unregister/remove/list/doctor` | 管理外部 planning 仓库（stores） |
| `openspec context` | 组装 working context（root + 引用的 stores） |
| `openspec workset create/list/open/remove` | 管理个人 workset（多 repo 工作视图） |
| `openspec doctor` | 诊断关系健康状态 |
| `openspec completion` | Shell 补全安装 |
| `openspec feedback` | 提交反馈 |

### Slash Commands（AI 聊天中使用的）

| 命令 | 用途 | Profile |
|------|------|---------|
| `/opsx:explore` | 探索想法，阅读代码库，理清需求，不做任何 artifact | core |
| `/opsx:propose` | 创建 change + 生成所有 planning artifacts | core |
| `/opsx:apply` | 按 tasks.md 实现代码 | core |
| `/opsx:sync` | 将 delta specs 合并到主 specs | core |
| `/opsx:archive` | 归档完成的 change | core |
| `/opsx:new` | 创建 change 脚手架（只生成 .openspec.yaml） | expanded |
| `/opsx:continue` | 按依赖图逐步创建下一个 artifact | expanded |
| `/opsx:ff` | 一次性创建所有 planning artifacts | expanded |
| `/opsx:verify` | 验证实现是否匹配 artifacts | expanded |
| `/opsx:bulk-archive` | 批量归档多个 change | expanded |
| `/opsx:onboard` | 引导式教程（在真实代码库上走完整工作流） | expanded |

### 自定义 Agents
**没有自定义 Agent 定义**。OpenSpec 不定义 Agent 角色，所有"agent"行为由 AI 助手根据 Skills 文件中的指令自主执行。AI 助手本身就是一个 Agent，Skills 文件是 Agent 的工作说明。

### Hooks
**没有 hooks**。OpenSpec 不在 settings.json 中写任何 hook。它只写 Skills 和 Commands 文件，由各 AI 工具的 Skill/Command 系统自动发现和触发。

### MCP Servers
**没有 MCP Server**。OpenSpec 是一个纯 CLI + 文件系统工具，不提供 MCP 能力。

### 模板 / 脚手架
- `schemas/spec-driven/schema.yaml` — 内置唯一 schema（proposal → specs → design → tasks）
- 每个 schema 关联 `templates/` 目录下的 Markdown 模板
- 用户可在 `openspec/schemas/` 或 `~/.local/share/openspec/schemas/` 中定义自定义 schema

### 配置文件 / Rules
- `openspec/config.yaml` — 项目级：schema 默认值、context（注入所有 artifact 指令）、per-artifact rules
- `~/.config/openspec/config.json` — 全局级：profile、delivery、workflows、openers
- `.openspec-store/store.yaml` — store 身份声明

---

## 4. 核心工具详解

### 4.1 `openspec init`（初始化 + Skills/Commands 生成）

**完整执行流程**：
1. **validate** — 检查目标路径权限，判断是否为 extend mode（已有 openspec/ 目录则只追加）
2. **pointer guard** — 检测 store 指针冲突，防止 store repo 的子目录被误初始化为新 root
3. **handleLegacyCleanup** — 检测旧版 artifacts，交互式（或 --force 自动）清理
4. **detectTools** — 扫描项目目录检测已存在的 IDE 工具目录（如 `.claude/`、`.cursor/`）
5. **migration check** — 在 extend mode 下执行迁移（旧配置 → profile 系统）
6. **welcome screen** — 交互模式下显示动画欢迎界面
7. **resolveProfileOverride** — 校验 --profile 参数
8. **getSelectedTools** — 交互式多选（searchable）或 --tools 参数指定工具；非交互模式自动选中检测到的工具
9. **validateTools** — 校验工具 ID 和 skillsDir 存在性
10. **createDirectoryStructure** — 创建 `openspec/specs/`、`openspec/changes/`、`openspec/changes/archive/`
11. **generateSkillsAndCommands** — 核心生成逻辑：
    - 读取全局 config（profile + delivery）
    - 根据 profile 过滤 workflows（core: 5 个，custom: 用户自定义）
    - 对每个 selected tool：写 SKILL.md 文件到 `{skillsDir}/skills/openspec-{workflow}/`
    - 对每个 selected tool：通过 CommandAdapter 生成 slash command 文件
12. **createConfig** — 写 `openspec/config.yaml`（如不存在）
13. **displaySuccessMessage** — 展示创建/刷新/失败详情

**输入**：目标路径、--tools、--force、--profile
**输出**：
- 创建的目录结构
- 每个 tool 下的 Skills 文件（如 `.claude/skills/openspec-propose/SKILL.md`）
- 每个 tool 下的 Commands 文件（如 `.claude/commands/opsx/propose.md`）
- `openspec/config.yaml`
- 终端成功消息

**调用的底层能力**：fs（mkdir/writeFile）、@inquirer/prompts（交互式选择）、YAML 序列化、工具检测（fs stat 扫描目录）
**关键设计决策**：
- delivery 模式：`both`（默认）、`skills`、`commands`，用户可只生成一种
- profile 系统：`core`（5 个 workflows）vs `custom`（用户自选）
- Skills 文件使用 YAML frontmatter + `generatedBy` 版本追踪，update 时靠版本号增量更新

### 4.2 `/opsx:propose`（Slash Command - 核心创建工作流）

**完整执行流程**（这是 AI 助手根据 SKILL.md 中的指令执行的）：
1. AI 读取 propose SKILL.md 中的指令
2. 调用 `openspec status --change <name> --json` 检查当前状态
3. 如果 change 不存在，调用 `openspec new change <name>`（或直接创建目录）
4. 按 schema 的 artifact DAG 顺序（spec-driven: proposal → specs → design → tasks）创建每个 artifact：
   - 对每个 artifact 调用 `openspec instructions <artifact> --change <name> --json` 获取富上下文指令（含 template + 项目 context + rules）
   - 读取依赖 artifact 的内容作为上下文
   - AI 生成 artifact 内容并写入文件
5. 报告完成状态，提示下一步 `/opsx:apply`

**输入**：change name 或自然语言描述
**输出**：`openspec/changes/<name>/` 下的 proposal.md、specs/、design.md、tasks.md
**调用的底层能力**：CLI（openspec 命令）、Read（读依赖文件）、Write（写 artifact）、Bash（shell 操作）
**关键设计决策**：
- proposal 的 Capabilities 段是整个工作流的关键契约——列出的每个 capability 都对应一个 spec 文件
- 使用 RFC 2119 关键字（SHALL/MUST/SHOULD）表达需求强度
- Modifications 用 delta 格式（ADDED/MODIFIED/REMOVED/RENAMED）

### 4.3 `/opsx:continue`（增量 artifact 创建）

**完整执行流程**：
1. 调用 `openspec status --change <name> --json` 获取 artifact 状态（done/ready/blocked）
2. 展示状态概览（done = ✓，ready = ◆，blocked = ○，missing deps 注明）
3. 选择第一个 ready 状态的 artifact
4. 调用 `openspec instructions <artifact-id> --change <name> --json` 获取完整指令
5. 读取所有依赖 artifact 的内容
6. 生成并写入 artifact 文件
7. 显示解锁的 artifact

**核心机制**：Artifact 依赖图引擎（DAG + topological sort + filesystem state detection）
- `spec-driven` schema: proposal(root) → specs, design(parallel) → tasks(needs both)
- 状态判定：文件存在于文件系统 = DONE，所有依赖 DONE = READY，依赖缺失 = BLOCKED

### 4.4 `openspec archive`（归档 + Delta Merge）

**完整执行流程**：
1. 读取 change 目录下所有 artifacts 和 delta specs
2. 检查 artifact 完成状态和 tasks 完成度
3. 如果 delta specs 未 sync，交互式或自动执行 sync：
   - 解析 delta spec 的 ADDED/MODIFIED/REMOVED/RENAMED 段
   - 将 ADDED 追加到主 spec、MODIFIED 替换对应 requirement、REMOVED 删除、RENAMED 映射
4. 将 change 目录移动到 `openspec/changes/archive/YYYY-MM-DD-<name>/`
5. 保留全部 artifacts 作为审计轨迹

**关键设计决策**：
- 归档不阻塞于 tasks 未完成（只是警告）
- delta merge 是智能的而非简单 copy：可以给已存在的 requirement 追加 scenarios
- 归档后 spec 源真自动更新，下一轮变更基于更新后的 spec

### 4.5 Stores 系统（多仓库 planning）

**设计动机**：当一次变更跨多个代码仓库时，planning 放在哪个 repo 的 `openspec/` 下？Stores 是独立的 planning 仓库。

**架构**：
```
team-plans (store)
├── .openspec-store/store.yaml  # "I am team-plans"
└── openspec/
    ├── specs/
    └── changes/
         ↑ registered by name on each machine
    ┌────┼────┐
web-app  api   mobile  (code repos)
```

**关键设计决策**：
1. Store 就是一个普通 git repo，用户自行 commit/push/pull
2. OpenSpec 从不 clone/sync/push 任何东西
3. 代码仓库可通过声明引用 store（声明只改变 OpenSpec 能告诉你什么，不影响命令的行为）
4. Workset 是个人本地视图，支持多 repo 组成的 `.code-workspace` 文件

---

## 5. 文件规范

### 目录结构

```
openspec/                  # 项目内（被 git 追踪）
├── config.yaml            # 项目配置（schema, context, rules）
├── specs/                 # 源真：系统当前行为规约
│   └── <domain>/
│       └── spec.md
├── changes/               # 进行中的变更
│   ├── <change-name>/
│   │   ├── .openspec.yaml       # 变更元数据
│   │   ├── proposal.md
│   │   ├── design.md
│   │   ├── tasks.md
│   │   └── specs/               # delta specs
│   │       └── <domain>/
│   │           └── spec.md
│   └── archive/            # 已归档的变更
│       └── YYYY-MM-DD-<name>/
└── schemas/               # 自定义 schema（可选）
    └── <schema-name>/
        ├── schema.yaml
        └── templates/
            └── *.md

~/.config/openspec/        # 全局配置（XDG）
└── config.json             # profile, delivery, workflows, openers

~/.local/share/openspec/   # 全局数据（用户级 schema 覆盖）
├── schemas/
└── worksets/
    ├── worksets.yaml
    └── *.code-workspace

{AI工具SkillsDir}/skills/  # 生成的 Skills 文件
└── openspec-<workflow>/
    └── SKILL.md

{AI工具CommandsDir}/commands/  # 生成的 Commands 文件
└── opsx/<id>.md
```

### 命名约定
- **change name**：kebab-case（`add-dark-mode`、`fix-auth-bug`）
- **capability/spec name**：kebab-case（`user-auth`、`data-export`）
- **domain directory**：kebab-case（`auth/`、`payments/`、`ui/`）
- **skill dir name**：`openspec-{workflow}`（`openspec-propose`、`openspec-apply-change`）
- **tasks 编号**：`X.Y` 层次化（`1.1`、`2.3`）
- **workset name**：kebab-id

### Frontmatter / Metadata Schema
SKILL.md 的 YAML frontmatter：
```yaml
---
name: openspec-propose
description: Create a change and generate planning artifacts...
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.5.0"
---
```

`.openspec.yaml`（change 元数据）：
```yaml
schema: spec-driven
created: 2025-01-24
```

`openspec/config.yaml`：
```yaml
schema: spec-driven
context: |
  Tech stack: TypeScript, React...
rules:
  proposal:
    - Include rollback plan
  specs:
    - Use Given/When/Then format
```

Schema YAML：
```yaml
name: spec-driven
version: 1
artifacts:
  - id: proposal
    generates: proposal.md
    template: proposal.md
    requires: []
    instruction: |
      Create the proposal document...
  # ...更多 artifacts
apply:
  requires: [tasks]
  tracks: tasks.md
  instruction: |
    Read context files, work through pending tasks...
```

---

## 6. SessionStart 注入

OpenSpec **不在 SessionStart 中注入任何内容**。它不是通过在 settings.json 中配置 hook 来工作的。取而代之的是：

1. **Skills 文件**：写入 `{skillsDir}/skills/openspec-*/SKILL.md`，由 AI 工具的 Skills 系统在启动时自动扫描和发现
2. **Commands 文件**：写入 `{commandsDir}/commands/opsx/*.md`，由 AI 工具的 Commands 系统在启动时注册为 slash commands

**预估 context 消耗量**：
- 每个 SKILL.md：约 2-5 KB（11 个 workflows 各一份）
- 每个 Command 文件：约 1-2 KB
- 以 Claude Code + core profile 为例：5 个 Skills × ~3KB = ~15KB，5 个 Commands × ~1.5KB = ~7.5KB
- 总计约 22.5KB 磁盘空间，但只在相关命令被用户触发时才加载到 context——**实际 context 消耗为 0（按需加载）**

---

## 7. 状态管理

### 持久化机制

| 维度 | 机制 | 存储位置 |
|------|------|----------|
| **Change 状态** | 文件系统存在性（artifact 文件是否存在 = 状态） | `openspec/changes/<name>/` |
| **Tasks 进度** | Markdown checkbox（`- [ ]` / `- [x]`） | `tasks.md` |
| **全局配置** | JSON 文件（profile, delivery, workflows） | `~/.config/openspec/config.json` |
| **项目配置** | YAML 文件（schema, context, rules） | `openspec/config.yaml` |
| **Store 注册** | 本地注册表文件 | `~/.local/share/openspec/registry/` |
| **Workset 视图** | YAML 文件 + 派生的 .code-workspace | `~/.local/share/openspec/worksets/` |
| **Skills 版本** | SKILL.md frontmatter 中 `generatedBy` 字段 | 各 tool 的 skills 目录 |
| **Change 元数据** | `.openspec.yaml` | change 目录内 |

### 核心设计原则
- **无服务器**：所有状态都是文件系统上的本地文件
- **无数据库**：不需要 SQLite 或任何外部存储
- **Git 友好**：所有项目级文件（openspec/ 下的所有内容）都可以被 git 追踪和版本控制
- **Delta 驱动**：spec 的变更以 ADDED/MODIFIED/REMOVED 格式显式表达，归档时 merge 进主 spec
- **文件锁**：worksets 文件使用文件锁（lock file）防止并发写冲突

---

## 8. 编排模式

### 单 Agent 模式
OpenSpec **不定义 Agent 角色**。它不创建 Agent prompt 文件（不像 omni_powers 有 `agents/op-implementer.md` / `agents/op-reviewer.md` 等角色定义）。

工作流由 AI 助手单一 Agent 根据 Skills 文件中的指令自主执行。每个 `/opsx:*` slash command 就是一份"工作说明书"，AI 助手读取并遵循。

### Pipeline 模式（artifact DAG）
Schema 的 `requires` 字段定义了 artifact 之间的 DAG：

```
proposal ──→ specs ──→ tasks ──→ apply
    │                     ↑
    └──→ design ─────────┘
```

- `openspec continue` 按拓扑序逐个创建 artifact
- `openspec ff`（fast-forward）一次性创建所有 planning artifacts
- `openspec propose`（core profile）也是一次性创建

这不是真正的 Agent 编排，而是在文件系统上表达工作流顺序。

### Leader-Worker 模式
**不存在**。OpenSpec 没有 leader/worker 架构，没有多 Agent 协调。

### 对比 omni_powers
| 维度 | OpenSpec | omni_powers |
|------|----------|-------------|
| Agent 角色 | 无（单 Agent 按 Skills 工作） | 多个（leader, op-implementer, op-reviewer, op-evaluator, op-closer） |
| 编排方式 | 文件系统 artifact 顺序 | Sub Agent 调用 |
| 工作流定义 | YAML schema + artifact 依赖 | RULES.md + skills/agents 契约 |
| 状态追踪 | 文件存在性 + checkbox | `tasks_list.json` + `leader_checkpoint.md` |
| 代码审查 | 无内置机制 | `op-reviewer` 规格合规 + 测试可信双裁决 |
| TDD | 无内置机制 | `op-implementer` 内 TDD 流程 |
