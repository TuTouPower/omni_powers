# SPEC 与 Plan 生成机制深度对比

> 分析 10 个 vendor harness 的 spec/plan 生成方式、模板规范、触发条件和强制程度。
> 日期：2026-07-02

---

## 一、总览

| repo | 流程 | SPEC 强制程度 | Plan 强制程度 | SPEC 格式 | Plan 格式 |
|---|---|---|---|---|---|
| **spec-kit** | SPEC → plan → tasks → implement（4 步 3 gate） | **强制** | **强制** | Markdown 模板填充（6 固定章节） | Markdown 模板填充（技术上下文 + 结构决策） |
| **OpenSpec** | SPEC（delta spec）→ tasks → implement（**无独立 plan 阶段**） | **强制** | **无独立 plan 阶段** | Delta spec：ADDED/MODIFIED/REMOVED 差异描述 | proposal Impact + tasks.md 承担轻量规划 |
| **agent-skills** | SPEC → plan → tasks → implement（4 步 2 gate） | **强制**（>30min 任务） | **强制**（有 spec 后） | 6 核心领域（目标/命令/结构/风格/测试/边界） | 依赖图 + 垂直切片 + 分阶段任务 |
| **superpowers** | brainstorming（≈spec）→ plan → SDD 执行 | **强制**（brainstorming gate） | **强制** | 对话式设计文档 + 6 步检查单 | 按文件的任务列表 + 精确接口签名 |
| **bmad-method** | 分析（SPEC/PRD）→ 规划（Epic/Story）→ 方案（架构）→ 实施 | 按需（有 bmad-spec 但不强制前置） | 按需 | SPEC.md 五字段内核（Why/Capabilities/Constraints/Non-goals/Success） | Epic/Story 分解 |
| **gstack** | `/spec`（5 阶段）→ `/autoplan`（4 层 review）→ 执行 | **不强制**，按需调用 | **不强制**，按需调用 | GitHub issue 格式 + 验收场景 | 4 层 review 维度（CEO/design/eng/DX） |
| **trellis** | brainstorm（轻 spec）→ task → 执行 | **不强制**，可选 bootstrap | **不强制**，可选 | PRD + spec 文件（代码库驱动） | task 状态机驱动，非文档 |
| **planning-with-files** | plan → 执行（**不要 spec**） | **无 spec 概念** | **强制**（多步任务） | 不存在 | task_plan.md 三文件（阶段/决策/进度） |
| **ECC** | 灵活，agent 自动判断 | 不强制 | 不强制 | `/plan` 命令生成 | 同上 |
| **mattpocock_skills** | 用户决定，提供 PRD 和 issue 分解工具 | 不强制 | 不强制 | `to-prd`：对话合成 PRD | `to-issues`：垂向切片 issue |

---

## 二、各 repo 详解

### 2.1 spec-kit — 最严格的结构化 SPEC + Plan

**类型**：CLI 格式，模板驱动，人工 gate 最多。

#### SPEC 生成

**触发**：用户执行 `/speckit.specify "描述功能需求"`

**生成流程**（7 步）：

1. 解析 `$ARGUMENTS` 获取用户输入
2. 运行 `check-prerequisites.sh --json` 获取路径变量
3. 加载上下文：`.specify/memory/constitution.md`（宪法原则）+ `spec-template.md`（模板）
4. 生成 feature 分支（若不存在）`create-new-feature.sh`
5. 按模板填充 spec.md
6. 按 checklist 自检（最多 3 轮迭代修正）
7. 不确定性用 `[NEEDS CLARIFICATION]` 标记（最多 3 个），人工澄清后继续

**SPEC 模板结构**（`templates/spec-template.md`，6 固定章节）：

```markdown
# Feature Specification: [FEATURE NAME]
## User Scenarios & Testing *(mandatory)*
  - User Story 1..N (Priority: P1/P2/P3)
  - Why this priority + Independent Test + Acceptance Scenarios
## Edge Cases
## Requirements *(mandatory)*
  - Functional Requirements (FR-001, FR-002...)
  - Key Entities
## Success Criteria *(mandatory)*
  - Measurable Outcomes (SC-001, SC-002...)
## Assumptions
```

**核心约束**：
- 禁止过早涉及技术实现细节（模板注释中明令禁止）
- 每个 User Story 必须独立可测试、可部署、可演示
- 每个需求必须是"可测试且无歧义"的

#### Plan 生成

**触发**：用户执行 `/speckit.plan`

**生成流程**（6 步）：

1. 加载 spec.md + constitution.md
2. Phase 0：调研（research.md）
3. Phase 1：设计（data-model.md + contracts/ + quickstart.md）
4. Constitution Check（门禁：不通过则不能继续）
5. 输出 plan.md
6. 可选：Phase 2 生成 tasks.md

**Plan 模板结构**（`templates/plan-template.md`）：

```markdown
# Implementation Plan: [FEATURE]
## Summary
## Technical Context (语言/依赖/存储/测试/平台/性能/约束/规模)
## Constitution Check (GATE)
## Project Structure (文档树 + 源码树，3 种选项)
## Complexity Tracking (违规说明)
```

**核心约束**：
- `[NEEDS CLARIFICATION]` 标记未确定的技术选型
- Constitution Check 为硬门禁，不通过则停止
- 复杂度违规必须在 Complexity Tracking 中说明理由

#### Tasks 生成

**触发**：`/speckit.tasks`

**Tasks 模板结构**：
- Phase 1：Setup（项目初始化）
- Phase 2：Foundational（阻塞性基础设施，CRITICAL：完成前不能开始任何 User Story）
- Phase 3+：按 User Story 分组（每 Story：Tests → Models → Services → Endpoints）
- Phase N：Polish（文档/重构/性能/安全）

**核心约束**：
- `[P]` 标记并行任务（不同文件、无依赖）
- `[US1]` 标记任务归属的 User Story
- 每个 User Story 独立可完成、独立可测试

---

### 2.2 OpenSpec — Delta SPEC，无 Plan

**类型**：CLI 格式，文件系统驱动，**无 plan 阶段**。

#### SPEC 生成

**触发**：`/opsx:propose "描述变更意图"`

**生成内容**（一个 change 目录）：

```
openspec/changes/<change-name>/
├── proposal.md   # Why / What Changes / Capabilities / Impact
├── design.md     # 技术设计（可选）
├── tasks.md      # 实现任务（checkbox）
└── specs/        # Delta spec
    └── <capability>/
        └── spec.md   # ADDED / MODIFIED / REMOVED
```

**Delta spec 格式**（核心差异化）：

```markdown
## ADDED Requirements
### Requirement: <标题>
#### Scenario: <场景名>
- **WHEN** <条件>
- **THEN** <预期结果>

## MODIFIED Requirements
### Requirement: <已有需求标题>
#### Scenario: <新增或修改的场景>
- **WHEN** ...
- **THEN** ...

## REMOVED Requirements
### Requirement: <移除的需求>
**Reason**: <移除原因>
**Migration**: <迁移方案>
```

合并后的主 spec（`openspec/specs/<capability>/spec.md`）是标准 Given-When-Then 格式。

**关键设计决策**：
- **不写完整 spec，只写差异**。archive 时自动 merge 到主 spec
- 可以同时有多个 change 目录并行进行
- 没有独立的 plan 阶段——proposal 里就有"Impact"章节列出受影响的文件
- `tasks.md` 从 proposal 直接生成，跳过 plan

#### 为什么没有 Plan

OpenSpec 认为对 brownfield 项目而言，明确"改什么"（delta）比"怎么改"（plan）更重要。Impact 章节列出了具体的源码文件路径，这本身就是轻量 plan。如果需要深度设计，`design.md` 是可选的。

---

### 2.3 agent-skills — 对话式 SPEC + 依赖图 Plan

**类型**：Skill 格式，强制人工 gate。

#### SPEC 生成

**触发**：`spec-driven-development` skill（自动或手动）

**要求触发条件**（否则直接跳过）：
- 新项目/新功能
- 需求模糊或不完整
- 改动涉及多文件/多模块
- 架构决策
- 预估 >30 分钟实现

**SPEC 6 核心领域**：

```markdown
1. Objective — 做什么、为什么、谁是用户、成功标准
2. Commands — 完整可执行命令（含 flags），不是工具名
3. Project Structure — 源码/测试/文档目录布局
4. Code Style — 一个真实代码片段 > 三段文字描述
5. Testing Strategy — 框架/目录/覆盖率/测试层级
6. Boundaries — Always/Ask First/Never 三级权限
```

**核心约束**：
- 写 SPEC 前必须先列出假设："ASSUMPTIONS I'M MAKING: ... → Correct me now or I'll proceed with these."
- 模糊需求必须转化为可测试的成功条件（如"让 dashboard 更快"→ LCP < 2.5s, CLS < 0.1）
- 4 阶段 gate：SPECIFY → PLAN → TASKS → IMPLEMENT，每个有人工 review

#### Plan 生成

**触发**：`planning-and-task-breakdown` skill

**5 步流程**：

1. **进入 Plan Mode**（只读，不写代码）
2. **识别依赖图**（database → models → API → frontend）
3. **垂直切片**（一个功能路径一个任务，不是水平切层）
4. **写任务卡片**（每个任务：描述 + 验收标准 + 验证步骤 + 依赖 + 涉及文件 + 预估规模）
5. **排序 + Checkpoint**（每 2-3 个任务一个验证检查点）

**任务规模标准**：

| 规模 | 文件数 | 范围 |
|---|---|---|
| XS | 1 | 单函数/配置 |
| S | 1-2 | 单组件/端点 |
| M | 3-5 | 单功能切片 |
| L | 5-8 | 多功能组件 |
| XL | 8+ | **必须拆分** |

---

### 2.4 superpowers — 对话式 Brainstorming + 精确文件级 Plan

**类型**：Skill 格式，强制人工 gate，**TDD 铁律**。

#### SPEC 生成（brainstorming）

**触发**：任何创造性工作前自动触发（由 using-superpowers meta-skill 强制）

**流程**（9 步检查单）：

1. Explore 项目上下文（文件、文档、最近提交）
2. 逐问题澄清（一次一个问题）
3. 提出 2-3 方案 + 推荐
4. 呈现设计（逐节确认）
5. 写设计文档到 `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`
6. Spec 自审（占位符/矛盾/模糊/范围）
7. 用户审阅 SPEC 文件
8. **transition to plan**（唯一出口：调用 writing-plans skill）
9. **HARD GATE**：以上完成前禁止写任何代码

**SPEC 格式**（对话式，无固定模板）：

设计文档按节呈现：架构 → 组件 → 数据流 → 错误处理 → 测试。每节独立确认。简单项目可短至几句话，但必须呈现和审批。

#### Plan 生成（writing-plans）

**触发**：brainstorming 完成后自动链式调用

**Plan 文档头**（强制格式）：

```markdown
# [Feature Name] Implementation Plan
## Global Constraints (spec 的项目级要求)
## Task N: [Component Name]
  - Files: Create/Modify/Test (精确路径)
  - Interfaces: Consumes/Produces (精确函数签名)
  - Step 1: 写失败测试 → Step 2: 验证失败 → Step 3: 最小实现 → Step 4: 测试通过 → Step 5: 提交
```

**核心约束**：
- 每个 step 2-5 分钟（不是任务，是步骤级粒度）
- Assumes 工程师"zero context，questionable taste"
- 任务级 reviewer gate（两个独立任务之间的 reviewer 可独立拒绝其中一个）
- **Consumes/Produces 接口块是核心特性**：子 agent 只看自己的 task，通过接口块知道相邻任务的函数签名

---

### 2.5 bmad-method — 五字段 SPEC 内核 + 三层配置

**类型**：CLI + Skill 格式，SPEC 可迭代更新。

#### SPEC 生成（bmad-spec）

**触发**：用户说 "create a spec" 或调用 bmad-spec

**SPEC 格式**（五字段内核）：

```markdown
SPEC.md:
  Why (为什么做)
  Capabilities (能力列表，每个有稳定 CAP-N ID)
  Constraints (约束)
  Non-goals (不做的事)
  Success signal (成功信号)
```

SPEC.md **不是手写产物**——它是从 `.memlog.md`（append-only 决策日志）**自动派生**的。.memlog.md 是唯一的真相源，每行一条决策/约束/能力/假设，按时间顺序追加，不可编辑和重排。bmad-spec 每次运行都重新从 memlog 渲染 SPEC.md。

**核心特点**：
- 同一 slug 的第二次调用**原地更新** SPEC（保留 CAP-N ID）
- spec 文件夹可包含 companion files（glossary.md 等），同样从 memlog 派生
- SPEC.md 只能通过 bmad-spec 写入，手动编辑会被下一次 derive 覆盖

#### Plan 生成

不是独立的 plan 文档。bmad 的阶段划分是：

1. **1-analysis**：分析师写 PRD → PM 编辑/验证 PRD → UX 设计
2. **2-plan-workflows**：PM agent 创建 Epic/Story → UX Designer 深入
3. **3-solutioning**：架构师写架构文档 → 实现就绪检查
4. **4-implementation**：Dev agent 开发 Story → 代码审查 → Sprint 管理

Plan 分散在多个产出物中（PRD + Architecture + Epics/Stories），不是单一 plan 文档。

---

### 2.6 gstack — 五阶段 SPEC + 四层 Review Plan

**类型**：重量级插件，SPEC 和 Plan **不强制**，按需路由。

#### SPEC 生成（/spec）

**触发**：用户说 "spec this out" / "file an issue" / "make this a GitHub issue"

**五阶段流程**：

1. **Scope**：界定范围、识别干系人、明确用户价值
2. **Research**：搜索代码库 + Web 搜索现有方案
3. **Design**：技术方案、数据模型、API 合约
4. **Risk Analysis**：安全/性能/兼容性/运维风险
5. **File the Spec**：生成 GitHub issue（标准模板），可选 `--execute` 自动生成 spec 文档

**SPEC 格式**：GitHub issue，包含完整验收场景 + 技术上下文 + 风险矩阵。

#### Plan 生成（/autoplan）

**触发**：用户说 "auto review" / "run all reviews"

**四层串行 Review pipeline**（非传统 plan 文档）：

```
/plan-ceo-review  → /plan-design-review → /plan-eng-review → /plan-devex-review
     ↓                    ↓                    ↓                   ↓
 产品机会评分         10维度设计评分        架构/边界情况       TTHW/摩擦点
```

每层有独立的评分维度和输出格式。`/autoplan` 用 6 条决策原则自动回答 15-30 个中间问题，最终一个人工 gate。

---

### 2.7 trellis — 代码库驱动的轻 SPEC + Task 状态机

**类型**：Hook 驱动，SPEC 和 Plan **可选项**。

#### SPEC 生成（trellis-brainstorm + trellis-spec-bootstrap）

**trellis-brainstorm**（需求澄清）：

1. 创建 task 目录：`task.py create "<title>" --slug <slug>`
2. 写入初始 `prd.md`
3. 探索代码库获取证据（代码/测试/文档/历史 task）
4. 逐问题访谈（一次一个，给出建议答案）
5. 区分：已确认事实 / 需要用户补充的产品意图 / 需要用户决策的范围/风险

**trellis-spec-bootstrap**（项目规范引导）：

- 分析代码库架构（GitNexus/ABCoder/源码直读）
- 填写 `.trellis/spec/` 中的规范文件（真实代码模式，不是占位符）
- 单 agent 完成全流程（分析→选择边界→写入→验证）

#### Plan 生成

**不需要传统 plan 文档**。trellis 的 task 状态机替代了 plan：

- `task.py create` 创建 task
- `inject-subagent-context.py` 自动向 implement/check/research 子 agent 注入 prd.md + design.md（可选）+ implement.md（可选）。这是上下文摘要机制，不是访问控制、写权限隔离或安全边界。
- `inject-workflow-state.py` 每轮注入 breadcrumb，提醒当前阶段

Plan 不是文档，是**运行时注入 + hook 驱动的状态机**。

---

### 2.8 planning-with-files — 只要 Plan，不要 SPEC

**类型**：文件状态机，**没有 spec 概念**。

#### Plan 生成

**触发**：复杂任务（3+ 步骤、多步工具调用）

**三文件系统**：

```
task_plan.md → 阶段、进度、决策
findings.md  → 调研和发现
progress.md  → 会话日志
```

**task_plan.md 结构**（模板驱动）：

```markdown
# Task Plan: [Brief Description]
## Goal (一句目标)
## Current Phase (当前阶段)
## Phases
  ### Phase 1: Requirements & Discovery
  ### Phase 2: Planning & Structure
  ### Phase 3: Implementation
  ### Phase N: Polish
  (每 Phase: checkbox + Status: pending/in_progress/complete)
## Errors Encountered (错误追踪表)
```

**核心约束**：
- **2-Action Rule**：每 2 个浏览器/搜索操作后必须立即写入文件
- **3-Strike Error Protocol**：3 次失败 → 向用户升级
- **The 5-Question Reboot Test**：task_plan.md 必须能回答 5 个问题（在哪/去哪/目标/学到了什么/做了什么）
- **Gated 模式**（v3）：5 层完成门禁，Agent 不能自己说"做完了"

#### 为什么没有 SPEC

planning-with-files 定位是**任务执行追踪系统**，不是开发方法论。它不关心"需求是否正确"，只关心"执行是否偏离目标"。SPEC 的职责交给用户或其他工具。

---

### 2.9 ECC — 灵活命令，agent 自动判断

**类型**：重量级插件，SPEC 和 Plan **都不强制**。

**SPEC 相关**：`/plan` slash command，调用 `planning-and-task-breakdown` 类型的逻辑。Agent 根据 AGENTS.md 中的触发规则自动判断是否需要 plan。没有强制 spec 的 skill。

**Plan 相关**：同 `/plan`。极端灵活——简单任务可跳过，复杂任务 agent 自动建议。

---

### 2.10 mattpocock_skills — 提供工具，不强制流程

**类型**：轻量 Skill 包，用户完全自主。

#### SPEC 相关（to-prd）

**触发**：用户手动调用 `/to-prd`

**流程**（对话合成，不是访谈）：

1. 探索代码库当前状态
2. 草拟测试接缝（seam）——让用户确认
3. 直接合成 PRD（不访谈），发布到 issue tracker，加 `ready-for-agent` 标签

**PRD 模板**：
```markdown
## Problem Statement (用户视角)
## Solution (用户视角)
## User Stories (长列表，As a...I want...So that...)
## Implementation Decisions (模块/接口/架构/API/不写具体文件路径)
## Testing Decisions (什么是好测试/哪些模块/先例)
## Out of Scope
## Further Notes
```

#### Plan 相关（to-issues）

**触发**：用户手动调用 `/to-issues`

**垂向切片规则**：
- 每个 slice 穿过所有层（schema → API → UI → tests）
- 每个 slice 独立可演示
- 先做预重构（prefactor），再做功能变更
- 按依赖顺序发布 issue（blocker 先发，真实 issue ID 引用）

#### 其他相关（grill-me / grilling）

> 以下是 mattpocock_skills 的 vendor 术语，不是 omni_powers 当前入口；omni_powers 当前需求入口为 `/opintake`，需求澄清由 opspec/opintake 流程承担。

- **grill-me**：调用 `/grilling`，对设计/plan 进行无情的追问访谈（与 brainstorming 类似但更对抗性）
- **grilling**：通用追问框架，面试式深挖设计假设

---

## 三、SPEC 格式对比

| repo | SPEC 产出物 | 格式 | 是否增量 | 是否从源码派生 |
|---|---|---|---|---|
| spec-kit | `specs/<###-feature>/spec.md` | 6 固定章节 Markdown 模板 | 否（每次完整重写） | 否 |
| OpenSpec | `openspec/specs/<capability>/spec.md` | **Delta spec**（ADDED/MODIFIED/REMOVED） | **是**（只写差异，archive 时 merge） | 否 |
| agent-skills | 项目级 spec 文件 | 6 核心领域（对话式填充） | 否 | 否 |
| superpowers | `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` | 对话式设计文档 | 否 | 否 |
| bmad-method | `<spec-folder>/SPEC.md` | 五字段内核 + companion files | **是**（同 slug 原地更新，保留 CAP-N ID） | **是**（从 .memlog.md 自动派生） |
| gstack | GitHub issue | 验收场景 + 技术上下文 | 否 | 否 |
| trellis | prd.md + `.trellis/spec/` | PRD + 代码库规范 | 否 | **是**（spec-bootstrap 从代码库提取） |
| planning-with-files | **无** | — | — | — |
| mattpocock_skills | GitHub issue（PRD 格式） | 对话合成 | 否 | 否 |

---

## 四、Plan 格式对比

| repo | Plan 产出物 | 粒度 | 是否有接口签名 | 是否有依赖图 |
|---|---|---|---|---|
| spec-kit | `specs/<feature>/plan.md` + `tasks.md` | Phase → Story → Task | 否 | 是（US 依赖 + Phase 依赖） |
| OpenSpec | **无独立 plan**（proposal Impact + tasks.md） | Task | 否 | 否 |
| agent-skills | Plan 文档 + Task 列表 | Phase → Checkpoint → Task（XS-XXL 规模标准） | 否 | **是**（显式依赖图 + 垂直切片） |
| superpowers | `docs/superpowers/plans/YYYY-MM-DD-<feature>.md` | **步骤级**（2-5min/step） | **是**（Consumes/Produces 精确函数签名） | 是（task 间依赖，非图形化） |
| bmad-method | 分散在 PRD + Architecture + Epics/Stories | Epic → Story | 否 | 否 |
| gstack | `/autoplan` 四层 review 输出 | review 维度 | 否 | 否 |
| trellis | **无文档**（运行时注入 implement.md 可选） | task | 否 | 是（parent/child 树） |
| planning-with-files | `task_plan.md` | Phase | 否 | 否（v3 自主模式有 phase coordination） |
| mattpocock_skills | GitHub issues（垂向切片） | 每个 issue 是完整垂向切片 | 否 | 是（Blocked by 引用） |

---

## 五、关键差异总结

### SPEC 方面

- **最重**：spec-kit（6 固定章节 + checklist + Constitution 门禁 + NEEDS CLARIFICATION 强制标记）
- **最轻**：planning-with-files（无 spec）、trellis（prd.md 可选）、mattpocock（对话合成 PRD，不访谈）
- **最独特**：OpenSpec（**delta spec**，唯一做差异管理的）、bmad-method（**从 memlog 派生**，唯一做 spec 自动生成的）

### Plan 方面

- **最重**：spec-kit（模板最复杂，含 Constitution Check + Complexity Tracking）
- **最细**：superpowers（步骤级，精确到文件路径 + 函数签名 + Consumes/Produces 接口块）
- **最独特**：planning-with-files（**只要 plan 不要 spec**，唯一这样做的）、trellis（**plan 不是文档是运行时注入**）

### 强制程度

```
spec-kit     ████████████  强制 spec + plan + 3 human gate
superpowers  ████████████  强制 brainstorming + plan + TDD
agent-skills ██████████    强制 spec + plan（>30min 任务）
OpenSpec     ████████      强制 spec（delta），无 plan
bmad-method  ██████        按需 spec，多阶段 plan 分散在产物中
trellis      ████          spec/plan 均可选，task 状态机为主
gstack       ████          spec/plan 按需路由，不强制
ECC          ██            agent 自动判断，用户控制
mattpocock   █            用户完全自主，仅提供工具
planning-    ██ (plan)     plan 强制但无 spec
with-files   ░░ (spec)
```
