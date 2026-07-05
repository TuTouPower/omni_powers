# mattpocock_skills

## 1. 概览

- **一句话定位**：Matt Pocock 的 Claude Code 日常工程技能集 -- 小而可组合的 agent 指令，用于真正的软件工程而非 vibe coding。
- **设计哲学**：解决四种 AI 编码常见失效模式：
  1. Agent 没按你想的做（通过 `grill-me`/`grill-with-docs` 追问式访谈对齐意图）
  2. Agent 过于啰嗦（通过领域建模建立 shared language，让 agent 用约定术语而非 20 个词描述同一概念）
  3. 代码跑不通（TDD 红绿循环 + 诊断调试 loop 提供紧反馈）
  4. 代码变泥球（`improve-codebase-architecture` 定期扫描深化机会，`codebase-design` 提供 deep module 词汇表）
- **核心理念**：The Pragmatic Programmer + DDD + 软件设计哲学 -> AI 时代的工程纪律。技能刻意保持小巧，不接管流程，而是增强。与 GSD/BMAD/Spec-Kit 等"全流程拥有"方案对立。
- **术语边界**：`grill-me` / `grilling`、`CONTEXT.md`、ADR 均是 mattpocock_skills vendor 术语/产物；omni_powers 当前需求入口是 `/opintake`，决策归 `op_record/decisions.md`。
- **成熟度**：
  - 约 50 个 commits，时间跨度 2026-06-17 至 2026-07-01（约 2 周），高度活跃开发中
  - 使用 changesets 做语义化版本管理，当前 v1.0.1
  - 有完整的 CHANGELOG、README、CONTEXT.md（项目自身的领域模型）、工程文档页、changeset 记录
  - 有 ADR（`.agents/adr/`）记录架构决策
  - 发布渠道：通过 skills.sh CLI 工具分发 (`npx skills@latest add mattpocock/skills`)

## 2. 安装机制

### 用户安装（推荐）

```bash
npx skills@latest add mattpocock/skills
```

通过 skills.sh 工具选择需要的 skills，安装到 Claude Code 或其他编码 agent 的 skill 目录。用户必须同时选择 `/setup-matt-pocock-skills`。

安装后在 repo 内运行 `/setup-matt-pocock-skills` 完成 per-repo 配置（issue tracker、triage labels、domain doc 布局）。

### 开发者安装

`scripts/link-skills.sh`（仅限维护者）：

- 扫描 `skills/` 下所有 `SKILL.md`（排除 `deprecated/`）
- 在 `~/.claude/skills/` 和 `~/.agents/skills/` 下创建 symlink
- 每个 skill 名对应一个指向该 skill 目录的 symlink
- 有防循环检测：如果目标目录本身是指向 repo 内部的 symlink，拒绝执行

### 改了哪些配置

**`.claude-plugin/plugin.json`**：声明所有 promoted skill 路径（engineering/ 和 productivity/），共 17 个。Claude Code 读取此文件加载 skills。这是 mattpocock_skills 的 vendor 分发机制，不是 omni_powers 当前安装模式。

**不直接修改** `CLAUDE.md` 或 `settings.json`。`/setup-matt-pocock-skills` 会在 repo 的 `CLAUDE.md`（或 `AGENTS.md`）中添加 `## Agent skills` 块，并写入 `docs/agents/issue-tracker.md`、`docs/agents/triage-labels.md`、`docs/agents/domain.md` 三个配置文件。

**Hook 方面**：`git-guardrails-claude-code` 提供 PreToolUse hook，拦截 `git push --force`、`git reset --hard`、`git clean -f` 等危险命令。

### Symlink 策略

- 每个 skill 在 harness skill 目录下是一个 symlink，指向 repo 中的 skill 目录
- 好处：`git pull` 即可更新所有已安装 skill，无需重新安装
- 添加/删除/重命名 skill 后需重新运行 `link-skills.sh`

## 3. 提供的工具全景

### 类型 A：Skills（核心，slash command 形式）

所有技能遵循 `skills/<bucket>/<name>/SKILL.md` 的目录结构。分两部分：**User-invoked**（仅人能输入 `/name` 触发）和 **Model-invoked**（agent 可自动检测触发）。

User-invoked 用 `disable-model-invocation: true` 标记；Model-invoked 省去此标记且在 description 中列出触发短语。

#### Engineering Skills（日常编码）

**User-invoked**：

| 名称 | 用途 |
|------|------|
| `ask-matt` | 路由器：根据你的情况告诉你应该用哪个 skill/流程 |
| `grill-with-docs` | 追问式访谈，同时构建领域模型（CONTEXT.md + ADR） |
| `triage` | Issue 状态机：needs-triage → needs-info → ready-for-agent → ready-for-human → wontfix |
| `improve-codebase-architecture` | 扫描代码库找出深化（deepening）机会，生成 HTML 可视化报告，然后对选中的候选方案追问 |
| `setup-matt-pocock-skills` | 配置本 repo 的 issue tracker、triage labels、domain doc 布局。首次使用前必运行 |
| `to-issues` | 将 plan/spec/PRD 拆分为独立的垂直切片 issue |
| `to-prd` | 将当前对话合成为 PRD 并发布到 issue tracker（不重复访谈） |
| `implement` | 基于 PRD/issue 实现功能，内部驱动 TDD + code review |

**Model-invoked**：

| 名称 | 用途 |
|------|------|
| `prototype` | 构建一次性原型回答设计问题（终端交互式状态机 或 多版本 UI 切换） |
| `diagnosing-bugs` | 严格的六阶段调试 loop：构建反馈循环 → 复现+最小化 → 提出假说 → 埋点 → 修复+回归测试 → 清理+复盘 |
| `tdd` | 红-绿 TDD 循环，要求预确认 seam，列举反模式，禁止水平切片 |
| `domain-modeling` | 主动构建和打磨项目领域模型：挑战模糊术语、检查代码一致性、更新 CONTEXT.md |
| `codebase-design` | Deep module 设计词汇表：module/interface/depth/seam/adapter/leverage/locality |
| `code-review` | 双轴审查（Standards + Spec），通过并行 sub-agent 实现 |

#### Productivity Skills（通用工作流）

**User-invoked**：

| 名称 | 用途 |
|------|------|
| `grill-me` | 无状态追问式访谈（无代码库场景） |
| `handoff` | 将当前对话压缩为交接文档，供另一个 agent 接管 |
| `teach` | 多会话教学工作台，在当前目录构建 lessons/assets/learning-records |
| `writing-great-skills` | 编写可预测 skill 的参考：词汇表、信息层级、修剪原则 |

**Model-invoked**：

| 名称 | 用途 |
|------|------|
| `grilling` | 可复用的追问循环，`grill-me` 和 `grill-with-docs` 的底层原语 |

### 类型 B：Hooks

| 名称 | 类型 | 用途 |
|------|------|------|
| `git-guardrails-claude-code` | PreToolUse | 拦截 `git push`、`git reset --hard`、`git clean -f`、`git branch -D`、`git checkout .` 等危险命令 |

### 类型 C：可执行脚本

| 名称 | 用途 |
|------|------|
| `scripts/link-skills.sh` | 将所有 skill symlink 到 `~/.claude/skills/` 和 `~/.agents/skills/` |
| `scripts/list-skills.sh` | 列出所有 SKILL.md 文件路径 |
| `skills/engineering/diagnosing-bugs/scripts/hitl-loop.template.sh` | 人机协作调试模板脚本 |

### 类型 D：模板

| 名称 | 用途 |
|------|------|
| `triage/AGENT-BRIEF.md` | Agent 可执行 issue brief 的格式规范 |
| `triage/OUT-OF-SCOPE.md` | `.out-of-scope/` 知识库规范（记录被拒绝的功能请求） |
| `domain-modeling/ADR-FORMAT.md` | ADR 文档格式 |
| `domain-modeling/CONTEXT-FORMAT.md` | CONTEXT.md（领域术语表）格式 |
| `codebase-design/DEEPENING.md` | 深化浅模块的操作指南（依赖分类、seam 纪律） |
| `codebase-design/DESIGN-IT-TWICE.md` | 并行 sub-agent 设计多种接口方案的指南 |
| `tdd/mocking.md` | Mock 规范（只在系统边界 mock） |
| `tdd/tests.md` | 好/坏测试示例 |
| `teach/MISSION-FORMAT.md` | 教学任务说明格式 |
| `teach/RESOURCES-FORMAT.md` | 资源列表格式 |
| `teach/LEARNING-RECORD-FORMAT.md` | 学习记录格式 |
| `teach/GLOSSARY-FORMAT.md` | 词汇表格式 |
| `writing-great-skills/GLOSSARY.md` | Skill 编写词汇表 |

### 类型 E：配置文件

| 名称 | 用途 |
|------|------|
| `.claude-plugin/plugin.json` | 声明所有 promoted skill 路径 |
| `.changeset/config.json` | Changesets 版本管理配置 |
| `package.json` | npm 包元信息（含 changesets 脚本） |

### 类型 F：文档页

`docs/engineering/` 和 `docs/productivity/` 下的每个 `.md` 文件对应一个 promoted skill 的人工文档页，发布到 `https://aihero.dev/skills-<name>`。

### 类型 G：Agent 开发指导

| 名称 | 用途 |
|------|------|
| `.agents/invocation.md` | skill 调用模式（user-invoked vs model-invoked）规范 |
| `.agents/writing-docs.md` | 文档页编写规范 |
| `.agents/adr/0001-*.md` | 项目自身的 ADR 记录 |

### Misc / In-Progress / Deprecated

- **misc/**：`git-guardrails-claude-code`、`migrate-to-shoehorn`、`scaffold-exercises`、`setup-pre-commit`
- **in-progress/**：`decision-mapping`、`loop-me`、`wizard`、`writing-beats`、`writing-fragments`、`writing-shape`
- **deprecated/**：`design-an-interface`、`qa`、`request-refactor-plan`、`ubiquitous-language`

## 4. 核心工具详解

### 4.1 grill-with-docs（追问访谈+领域建模）

**执行流程**：

1. Agent 运行 `/grilling` 底层循环：每次只问一个问题，等待用户回答后继续下一个
2. 每个问题前先探索代码库（如果可以从代码库获得答案就不问）
3. 同时运行 `/domain-modeling`：
   - 当用户使用的术语与 CONTEXT.md 已有定义冲突时立即指出
   - 用户使用模糊术语时主动提出精确定义
   - 当领域关系被讨论时，发明边界场景测试精确定义
   - 当用户声称某行为与代码不一致时提出矛盾
   - 术语确定后立即更新 CONTEXT.md（不批处理）
   - 必要时提供 ADR（满足三个条件：难以逆转 + 无上下文令人意外 + 经历真实权衡）
4. 继续追问直到决策树完全展开

**输入**：用户的口头计划/想法/设计，可选的现有 CONTEXT.md

**输出**：精炼后的计划 + 更新的 CONTEXT.md + 新增 ADR（如有）

**调用的底层能力**：Read（读代码库）、Write/Edit（更新 CONTEXT.md 和 ADR）

**关键设计决策**：
- 一次只问一个问题（"asking multiple questions at once is bewildering"）
- 有代码库场景用 `grill-with-docs`（有状态，留下文档痕迹），无代码库用 `grill-me`（无状态）
- `grilling` 作为可复用原语被 model-invoked，`grill-with-docs` 和 `grill-me` 是 user-invoked wrapper
- 这是整个 repo 最受欢迎、被认为"最酷"的技能

### 4.2 improve-codebase-architecture（架构扫描+深化）

**执行流程**：

1. **探索**：读取 CONTEXT.md（领域词汇）和 ADR（已有决策），然后用 `Agent(subagent_type=Explore)` 遍历代码库，以有机方式记录摩擦点：
   - 理解一个概念需要跨多个浅模块跳跃？
   - 模块是否浅（接口几乎和实现一样复杂）？
   - 是否有为测试提取但失去 locality 的纯函数？
   - 应用删除测试：删除这个模块，复杂度会消失还是会在 N 个调用者处重新出现？
2. **呈现**：生成自包含 HTML 文件写入 OS 临时目录，用 Tailwind CDN 排版、Mermaid CDN 画图。每个候选方案一张卡片：
   - 涉及文件、问题、解决方案、收益（locality + leverage + 可测试性）、Before/After 对比图、推荐强度（Strong / Worth exploring / Speculative）
   - 用 CONTEXT.md 词汇表达领域概念，用 `/codebase-design` 词汇表达架构概念
   - 结尾 Top recommendation
3. **追问循环**：用户选中一个候选方案后，运行 `/grilling` 追问设计树（约束、依赖、深化后的模块形态）
4. **同步领域模型**：运行 `/domain-modeling` 保持领域模型更新
5. 可选：需要探索替代接口时调用 `/codebase-design` 的 design-it-twice 并行 sub-agent 模式

**输入**：代码库本身（无额外输入即可运行）

**输出**：HTML 可视化报告 + 深化方案 + 更新的 CONTEXT.md 和 ADR

**关键设计决策**：
- 明确禁止"先提出接口" -- 先呈现候选方案，用户选择后才深入设计
- 用 `/codebase-design` 的词汇表（module/interface/depth/seam/adapter/leverage/locality）而非自造术语
- ADR 冲突处理：只有当摩擦真的足够重新审视 ADR 时才提出

### 4.3 tdd（测试驱动开发）

**执行流程**：

1. **确定 seam**：写测试前先写出要测试的 seam，并向用户确认。只能测试确认过的 seam。不写未经确认的 seam 的测试。
2. **红色**：在 seam 处写一个失败的测试
3. **绿色**：只写足够让测试通过的代码，不预判未来测试
4. **循环**：一个 seam → 一个测试 → 一个最小实现，完成后回到步骤 1
5. **重构**：不属于 red-green 循环，属于 code-review 阶段

**输入**：用户的功能需求或 bug

**输出**：通过测试的代码 + 测试本身

**关键设计决策**：
- 垂直切片而非水平切片（一次一个完整行为，不是先写全部测试再写全部实现）
- 三个反模式显式列举：实现耦合测试、同义反复测试、水平切片
- 重构从循环中分离出来，归入 code-review 阶段
- 依赖 `/codebase-design` 词汇表指导接口设计

### 4.4 code-review（双轴审查）

**执行流程**：

1. **确定基准点**：用户指定的 commit/branch/tag/`HEAD~5` 等。执行 `git rev-parse` 验证基准存在，检查 diff 非空。
2. **定位 spec**：按优先级：commit message 中的 issue 引用 → 用户参数 → 匹配分支名的 PRD/spec 文件 → 向用户询问。若不存在 spec，Spec 轴跳过。
3. **定位 standards**：读取 repo 中的 `CODING_STANDARDS.md`、`CONTRIBUTING.md` 等 + 内置 Fowler 代码味道基线（12 种味道）。
4. **并行启动两个 sub-agent**：用一条消息发送两个 `Agent` 调用，使用 `general-purpose` 子类型：
   - Standards sub-agent：接收完整 diff + 标准源文件 + 味道基线。要求报告每个违规点（引用标准文件+规则），每个味道（命名+代码片段）。区分硬违规和判断性味道。400 词以内。
   - Spec sub-agent：接收 diff + spec 内容。报告缺失/不完整的需求、规范外的行为、看起来不对的实现。引用 spec 原文。400 词以内。
5. **汇总**：分别在 `## Standards` 和 `## Spec` 标题下展示两份报告，不合并不重排。结尾一行总结：每轴发现数 + 各轴最严重问题。

**输入**：基准点（必填）+ 可选 spec 路径

**输出**：双轴审查报告

**关键设计决策**：
- **双轴分离**是核心原则：避免一轴遮蔽另一轴
- **并行 sub-agent**隔离上下文：Standards 检查不污染 Spec 检查，反之亦然
- **Fowler 味道基线**作为 universal minimum standard，即使 repo 没有任何编码规范文档也适用
- 味道是启发式标签不是硬违规，repo 文档可以覆盖基线

### 4.5 diagnosing-bugs（诊断调试循环）

**执行流程**：

1. **构建反馈循环**（Phase 1，核心）：
   - 10 种构建策略（按优先级）：失败测试 → curl/HTTP → CLI 调用 → 无头浏览器 → 回放 trace → 一次性 harness → 属性/模糊测试 → 二分搜索 → 差分循环 → 人机协作脚本
   - 然后收紧：更快？信号更明确？更确定性？
   - 非确定性 bug：提高复现率（循环 100 次、并行、加压、缩小时间窗口）
   - 确实无法构建时：停止并明确列出尝试了什么，向用户请求所需条件
   - 完成标准：**一条命令**，已运行过至少一次，具有 red-capable（能捕获此 bug）、确定性、快速（秒级别）、agent 可运行
   - **在 red-capable 命令存在前禁止进入 Phase 2**
2. **复现+最小化**（Phase 2）：运行循环，确认 failure mode 为用户描述的那个，然后缩减到最小且仍 red 的场景
3. **提出假说**（Phase 3）：生成 3-5 个有排名的假说，每个必须可证伪（"如果 <X> 是原因，那么改变 <Y> 会使 bug 消失"）。向用户展示排名后再测试。
4. **埋点**（Phase 4）：每次只改变一个变量。工具偏好：debugger > 定向日志 > "全量日志+grep"。所有调试日志用唯一前缀标记（如 `[DEBUG-a4f2]`）以便清理。
5. **修复+回归测试**（Phase 5）：在正确 seam 处写回归测试（如果存在），在修复前写，然后修复。如果没有正确的 seam，这本身就是发现。
6. **清理+复盘**（Phase 6）：确认原始场景不再复现、回归测试通过、移除所有调试代码、删除一次性原型、在 commit message 中声明正确的假说。然后问：什么能防止这个 bug？如果需要架构改动，转交 `/improve-codebase-architecture`。

**关键设计决策**：
- Phase 1 是整个 skill 的精髓 -- "Build a tight feedback loop, and the bug is 90% fixed"
- "没有 red-capable 命令就不准进 Phase 2"是强制门槛，防止盲目读代码猜测
- Phase 3 要求生成多个假说防止锚定效应
- Phase 6 的 post-mortem 将 bug 与架构改进直接关联

## 5. 文件规范

### 目录结构

```
skills/<bucket>/<name>/
├── SKILL.md          # 必选。skill 定义，含 YAML frontmatter
├── <sub-doc>.md      # 可选。通过 context pointer 引用的参考文档
└── scripts/          # 可选。skill 专属脚本
```

### 命名约定

- Skill 名：kebab-case（如 `grill-with-docs`、`improve-codebase-architecture`）
- 目录名 = skill 名 = frontmatter 中的 `name`
- 文件名：大写命名（`SKILL.md`、`AGENT-BRIEF.md`、`OUT-OF-SCOPE.md`、`ADR-FORMAT.md`、`CONTEXT-FORMAT.md` 等）
- 文档页路径：`docs/<bucket>/<skill-name>.md`，映射到 URL `https://aihero.dev/skills-<skill-name>`
- 发布 URL 与 bucket 无关 -- 路径只是 repo 内组织方式

### Frontmatter / Metadata Schema

```yaml
---
name: skill-name                    # 必选。kebab-case，与目录名一致
description: rich trigger phrasing  # 必选。model-invoked 需含触发短语，user-invoked 含一句话摘要
disable-model-invocation: true      # 可选。存在则 user-invoked
argument-hint: "text"               # 可选。提示用户应传入什么参数
---
```

### Prototype 分支文件

`LOGIC.md` 和 `UI.md` 是 prototype skill 的两个分支（不是独立 skill），由 `SKILL.md` 根据问题类型路由到对应文件。

## 6. SessionStart 注入

**无**。该 repo 不提供 SessionStart hook。Skills 通过 Claude Code 的 skill 加载机制按需引入。

**每个 model-invoked skill 的 context 消耗**来自其 `description`（约 10-50 词的触发短语）。user-invoked skill 的 description 不进入 agent context（`disable-model-invocation: true` 将其从 agent 视野中移除）。

**估算**：17 个 promoted skills 中，model-invoked 有 7 个（`prototype`、`diagnosing-bugs`、`tdd`、`domain-modeling`、`codebase-design`、`code-review`、`grilling`），user-invoked 有 10 个。所有 user-invoked skill 的 description 不消耗 context（约 0 词），model-invoked 每个 description 约 15-40 词，总计约 **105-280 词**的固定 context 开销。

## 7. 状态管理

**无内置持久化/checkpoint 机制**。所有状态管理通过"写入文件"方式实现，由具体 skill 驱动：

| 状态类型 | 负责 skill | 写入位置 | 格式 |
|---------|-----------|---------|------|
| 项目领域模型 | `domain-modeling`（由 `grill-with-docs`、`triage`、`improve-codebase-architecture` 等调用） | repo 根 `CONTEXT.md` | 术语表（纯术语，无实现细节） |
| 架构决策 | `domain-modeling` | `docs/adr/000N-*.md` | ADR 格式 |
| 问题跟踪配置 | `setup-matt-pocock-skills` | `docs/agents/issue-tracker.md`、`docs/agents/triage-labels.md`、`docs/agents/domain.md` | prose YAML-like |
| 被拒功能记录 | `triage` | `.out-of-scope/<concept>.md` | 自由文本 |
| 跨会话交接 | `handoff` | OS 临时目录 | Markdown 交接文档 |
| 教学进度 | `teach` | 当前目录 `MISSION.md`、`learning-records/`、`lessons/`、`assets/` | 结构化 Markdown/HTML |

`/handoff` 和 `/compact` 是两个互补的 context 管理策略：
- `handoff`：fork 模式，写入交接文件→开新会话→引用文件。保留完整上下文副本。
- `compact`：continue 模式，同会话内摘要历史。阶段间有意中断。

## 8. 编排模式

### 总体模式：路由 + 分层

```
                    ┌──────────────┐
                    │   ask-matt   │ ← user-invoked 路由器
                    └──────┬───────┘
                           │
            ┌──────────────┼──────────────┐
            ▼              ▼              ▼
    ┌──────────┐   ┌──────────┐   ┌──────────┐
    │ 主流程   │   │ On-ramp  │   │ 独立     │
    └──────────┘   └──────────┘   └──────────┘
```

### 主流程：idea → ship（链式编排）

```
grill-with-docs → [prototype] → to-prd → to-issues → implement → code-review
     │                │            │           │           │
     ▼                ▼            ▼           ▼           ▼
 grilling      domain-modeling  (直接合成  (垂直切片  (tdd + code-review)
(追问环)       (更新CONTEXT.md)  已有上下文)  发布issue)
```

- 链式但保持 context hygiene：步骤 1-3 在一个不中断的 context 窗口，`/implement` 则为每个 issue 新开会话
- 如果 context 接近 smart zone（~120k tokens），用 `/handoff` 分叉而非压缩

### On-ramp：从外部进入主流程

```
/triage           → 产出 ready-for-agent issues → /implement 拾取
/diagnosing-bugs  → 修复 bug → post-mortem → /improve-codebase-architecture（如需要架构改动）
```

### 词汇层：底层的 model-invoked 参考

```
/domain-modeling  ← 被 grill-with-docs, triage, improve-codebase-architecture 调用
/codebase-design  ← 被 tdd, improve-codebase-architecture, code-review 调用
/grilling          ← 被 grill-me, grill-with-docs 调用
```

### 调用约束

- **User-invoked 可以调用 Model-invoked，不能调用另一个 User-invoked**
- 依赖通过 `"/skill" 风格的 prose invocation` 表达（如 "Run the `/grilling` skill"），而非跨目录文件引用
- Skill 之间的共享参考文档放在拥有该文档的 skill 目录下，其他 skill 通过调用该 skill 来获取

### 并行模式

`code-review` 是两个并行 sub-agent（Standards + Spec）的唯一使用者：
```
主干 agent
  ├── Agent(Standards)  ← 并行
  └── Agent(Spec)       ← 并行
        ↓
     汇总报告
```

`codebase-design` 的 `DESIGN-IT-TWICE.md` 描述了设计多种接口方案时使用并行 sub-agent 的模式，但这是指导而非 skill 内建行为。

### 设计理念

- **不拥有全流程**：与 GSD/BMAD/Spec-Kit 相反，每个 skill 是独立工具，用户自己决定何时使用
- **user-invoked = 编排者，model-invoked = 纪律/词汇提供者**
- **reuse 优先**：`grilling` 被两个 wrapper 复用，`codebase-design` 词汇被多个 skill 引用
- **信息层级**：skill 内按"inline step > inline reference > external reference"组织，用 context pointer 实现渐进披露
