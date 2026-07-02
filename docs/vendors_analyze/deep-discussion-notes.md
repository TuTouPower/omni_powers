# 深度讨论笔记：spec-kit / gstack / agent-skills

> 讨论背景：已深度使用 ECC、superpowers、OpenSpec、mattpocock_skills，逐个讨论剩余 6 个。
> 日期：2026-07-02

---

## 一、已有背景：四个已用 repo 的核心特征

| | ECC | superpowers | OpenSpec | mattpocock_skills |
|---|---|---|---|---|
| **类型** | **重量级大规模插件包** | **Skill 格式的开发方法论** | **CLI 格式的开发方法论** | **轻量级 Skill 包** |
| 编排模式 | leader-worker + pipeline + DAG | leader-worker（SDD 单个 spec/plan → 逐 task 派子 agent） | 单 agent 聊天中持续迭代多个 spec/change | 用户路由，单 agent |
| TDD | 有 skill，非强制 | **铁律强制** | **不涉及** | 有 skill，按需 |
| spec 机制 | 无内置 | 无内置，靠 brainstorming 输出 | Delta spec（ADDED/MODIFIED/REMOVED） | 无内置 |
| 多 spec 并发 | — | **一次只一个** spec/plan | **可同时多个** change 目录 | — |
| 独门技术 | 记忆持久化 + 持续学习 + 16 语言包 | Iron Law / Red Flags 行为塑造 | Delta spec 差异管理 | grill-with-docs 追问 + codebase-design 词汇表 |

---

## 二、spec-kit

**类型：CLI 格式的开发方法论**（与 OpenSpec 同类，但更重、更企业级）

**不是 Claude Code 插件，是 Python CLI 脚手架。**

`pip install specify-cli` → `specify init`（选 Agent）→ 模板渲染为 slash commands 写入项目 → 聊天中执行生成的 `/speckit.*`。

### 和 OpenSpec 的本质区别

| | OpenSpec | spec-kit |
|---|---|---|
| 入口 | 聊天中 `/opsx:propose` | 终端 `specify init` |
| 规格格式 | **Delta spec**：只写 ADDED/MODIFIED/REMOVED，archive 时 merge 进主 spec | **完整重写**：每次 feature 独立 `spec.md`，模板填充 |
| 迭代模式 | **多 change 并发**，每个 change 独立目录 | **一次一个 feature**，四步串行 |
| TDD | **不提测试** | **不提测试**（constitution 可写原则，非强制） |
| 门禁 | Agent 自觉遵循 SKILL.md checklist | Constitution 合规 + `[NEEDS CLARIFICATION]` 强标 + checklist 硬门 |
| 适用场景 | brownfield 增量变更 | greenfield 新项目 |

**核心差异**：OpenSpec 是"聊着聊着把变更记录下来"，spec-kit 是"先停下来写好宪法和完整规格，再动手"。

### 底层架构

- 35+ Agent 集成靠 OOP 注册表：每个 Agent 一个子类覆写 `setup()`，加新 Agent ~80 行
- `integrations/claude/__init__.py` 中的 `ClaudeIntegration` 负责渲染 `.claude/commands/*.md`
- 模板约束 LLM 的核心机制：`spec-template.md` 内置禁止过早实现细节、强制标注不确定性等规则
- Workflow 引擎支持条件分支、并行 fan-out、while 循环、人工 gate

---

## 三、gstack

**类型：重量级大规模插件包**（与 ECC 同类，但规模和覆盖面不如 ECC）

### 独门武器：无头浏览器守护进程

Bun 编译二进制 + Chromium + Playwright，常驻后台。首次调用 ~3s，后续 ~100ms。70+ 命令。

**其他 harness 全都没有这个能力**——它们最多调用 Playwright MCP，每次启动浏览器。

### 浏览器干什么

| Skill | 浏览器用途 |
|---|---|
| `/qa` | 打开网站 → 走用户流程（点击/填表/导航）→ 截图 → 发现 bug → **切回源码修** → 重开验证 → 原子 commit |
| `/design-review` | 截图 before/after 对比，检查间距/对齐/颜色/动效，每修复带截图证据 commit |
| `/investigate` | 打开 bug 页面 → 复现操作 → 抓 console error / network → 切回源码排查 |
| `/design-shotgun` | 爬全站，抓取所有 UI 组件截图，生成设计系统文档 |
| `/ship` | 部署前浏览器验证 |
| `/scrape` + `/skillify` | `/scrape` 操控页面提取数据 → `/skillify` 编译为确定性 Playwright 脚本，复跑 ~200ms |

**核心闭环**：代码 → 浏览器验证 → 修代码。其他 harness 只能读代码和跑测试，看不到渲染结果。

### 和 ECC 的本质区别

| | ECC | gstack |
|---|---|---|
| 规模 | 67 Agents / 277 Skills / 20+ MCP | 59 Skills / ~80 CLI / 无自定义 Agent 定义 |
| 安装 | 选择性安装（profile/module/component 三级） | `git clone --depth 1 && ./setup` 全量 |
| 记忆 | SessionStart 注入会话摘要 + instinct + learned skills | JSONL 事件溯源（learnings/decisions），每次搜索历史 |
| Agent 定义 | **67 个** | **0 个**，纯 skill 文本指令 |
| 安全 | OWASP 规则 | **6 层 prompt 注入防御** + redact pre-push + device salt |
| 独门技术 | 记忆持久化 + 持续学习 + 16 语言包 | 无头浏览器守护进程 |
| 更新 | 手动 | SessionStart 自动 git fetch + merge --ff-only |

### iOS 验证

有真实验证，但**偏重**：

- 原理：注入 `DebugBridge` SPM 依赖 → app 内跑 StateServer + 触摸合成 + 截屏 → Agent 通过 bridge 读写 UI 状态
- 要求：macOS + Xcode + Swift 5.9+ + **真机连接**
- 不是模拟器，不是 XCTest，只支持 SwiftUI
- 59 个 skill 中仅 5 个 iOS 专用

### 平台验证能力边界

| 平台 | 实际验证 |
|---|---|
| Web（任意技术栈） | 强。无头浏览器打开、截图、交互 |
| iOS SwiftUI | 有条件。需真机 + macOS + DebugBridge 注入 |
| 浏览器扩展 | **无法验证** |
| 桌面端（Electron/Tauri） | **无法验证**（能开 webview 但无法验证原生层） |
| 安卓 | **无** |
| 小程序 | **无** |
| React Native / Flutter | **无** |

### 路由机制

不是"LLM 判断该用哪个 skill"，而是 **bash 先算状态，LLM 再决策**：`/gstack` skill 的 preamble 是一段 60 行的 bash 脚本，检测分支、session 类型、conductor 状态、learnings 历史、升级状态等，结果作为环境变量注入上下文。

---

## 四、agent-skills

**类型：Skill 格式的开发方法论**（与 superpowers 同类，覆盖更广但没有 subagent 编排）

### 独特的 skill 格式

每个 skill = **流程 + 防借口表（anti-rationalization）+ 红牌警告（red flags）+ 验证检查单**。

防借口表列出 Agent 可能想跳过的理由并逐一反驳。例如"你以为改动太小不需要 spec → 但小改动也有隐含假设，spec 把假设亮出来"。

### 编排规则

`AGENTS.md` 明确规定：
- "用户（或 slash command）是编排者。Persona 不调用其他 Persona"
- 5 种 endorse 模式 + 4 种反模式
- 唯一多 persona 模式：`/ship` 并行 fan-out + 合并（code-reviewer + security-auditor + test-engineer）

### 和 superpowers 的本质区别

| | superpowers | agent-skills |
|---|---|---|
| 核心编排 | **SDD leader-worker**：per-task 派 implementer + reviewer 子 agent | **用户编排**：用户决定何时调哪个 skill，单 agent |
| TDD | **铁律强制** | 有 TDD skill，**非强制前置**，按需路由 |
| 执行粒度 | **一次一个 spec/plan**，拆分 task 后逐个派子 agent | 支持 **`/build auto`** 一次性 planning + implement + TDD |
| 行为塑造 | Iron Law / Red Flags | 防借口表 / 红牌 / 验证检查单 |
| 生命周期 | brainstorming → plan → build → review → merge | **Define → Plan → Build → Verify → Review → Ship**（含 observability/deprecation/CI-CD） |
| SessionStart | 注入 using-superpowers 全文 | 注入 using-agent-skills 全文（~192 行含 ASCII 流程图） |
| 自定义 Agent | 无 | **4 个**（code-reviewer / security-auditor / test-engineer / web-perf-auditor） |

### 和 mattpocock_skills 的本质区别

| | mattpocock_skills | agent-skills |
|---|---|---|
| 定位 | 轻量单点技能 | 全生命周期技能集 |
| 路由 | 用户手动选 | meta-skill 自动路由 |
| SessionStart | **无** | **注入全文**（~192 行） |
| 自定义 Agent | 无 | 4 个 |
| 特色 | grill-with-docs（追问+领域建模）、codebase-design | interview-me（结构化访谈）、doubt-driven-development（对抗审查） |

---

## 五、快速定位

| 如果你觉得… | 可以看… |
|---|---|
| OpenSpec 太轻、不够结构化 | spec-kit（重流程、宪法+规格+门禁） |
| ECC 覆盖面广但缺浏览器验证 | gstack（有浏览器，但其他方面不如 ECC 全） |
| superpowers 流程太短、想覆盖全交付管道 | agent-skills（Define→Ship 全生命周期） |
| 想给 AI 加"真正看到页面"的能力 | gstack（独此一家） |
| 需要跨 35+ Agent 工具的 spec 标准 | spec-kit（官方唯一） |

---

## 六、七个 repo 类型总览

### 分类逻辑

按三个维度判断一个 harness 的"类型"：

1. **交付形式**：是 CLI 工具在终端运行？是 SKILL.md 文件靠 Agent 加载？还是大规模插件包含 agents/hooks/commands/skills？
2. **是否拥有你的开发流程**：是你手动调用它，还是它自动注入、自动路由、自动编排？
3. **覆盖范围**：几个技能点？还是全生命周期管道？

| 类型 | 特征 | 实例 |
|---|---|---|
| **CLI 格式的开发方法论** | 终端运行 CLI 生成文件/目录结构，Agent 通过生成的 slash commands 执行工作流。不常驻，不注入 SessionStart | OpenSpec、spec-kit |
| **Skill 格式的开发方法论** | 纯 SKILL.md 文件驱动，靠 SessionStart hook 注入路由/meta-skill。Agent 按 skill 指令执行，无 CLI 脚手架 | superpowers、agent-skills |
| **轻量级 Skill 包** | 多个独立 SKILL.md 文件，用户按需选择。无 SessionStart 注入，无编排，不拥有流程 | mattpocock_skills |
| **重量级大规模插件包** | 含 Agents + Skills + Hooks + Commands + Rules，全栈覆盖。SessionStart 注入记忆/升级/路由。拥有你的开发流程 | ECC、gstack |

```
                轻量 ◄────────────────────────────► 重量
                 │                                      │
mattpocock_skills│  agent-skills    superpowers         │
  (Skill包)      │    (方法论)      (方法论)    gstack   │  ECC
                 │                            (插件包)  │  (插件包)
                 │                                      │
OpenSpec ────────┼──── spec-kit                         │
  (CLI方法论)    │    (CLI方法论)                        │
                 │                                      │
    ◄── 不拥有流程 ──────────────── 拥有流程 ──────────►
```

### 各 repo 归类

| repo | 类型 | 判断依据 |
|---|---|---|
| **OpenSpec** | CLI 格式的开发方法论 | `npx openspec init` 生成目录 + `/opsx:*` slash commands 执行工作流 |
| **spec-kit** | CLI 格式的开发方法论 | `specify init` 脚手架 + 生成的 `/speckit.*` commands |
| **superpowers** | Skill 格式的开发方法论 | SessionStart 注入 using-superpowers，12 个 SKILL.md 拥有 brainstorm→plan→build→review→merge |
| **agent-skills** | Skill 格式的开发方法论 | SessionStart 注入 using-agent-skills，24 个 SKILL.md 拥有 Define→Ship 全管道 |
| **mattpocock_skills** | 轻量级 Skill 包 | 17 个独立 SKILL.md，无 SessionStart，用户自主路由 |
| **ECC** | 重量级大规模插件包 | 67 Agents + 277 Skills + 48 Hooks + 20+ MCP + 16 语言包，全栈 OS 级 |
| **bmad-method** | CLI + Skill 格式的开发方法论 | npm 全局安装 + 按需加载 skills，角色扮演 +4 阶段工作流 |
| **trellis** | Hook 驱动的工程框架 | 3 个 Python hook（SessionStart + PreToolUse + UserPromptSubmit）+ task 状态机 |
| **planning-with-files** | 文件状态机驱动的任务追踪系统 | 3 个 Markdown 文件（task_plan/findings/progress）+ inject-plan.sh |

---

## 七、bmad-method

**类型：CLI + Skill 格式的开发方法论**（最像 superpowers + spec-kit 的合体，但多了一层角色扮演）

### 核心机制

**1. 命名角色 Agent 系统。**

不是"你是一个 code reviewer"，而是"你是 Mary，业务分析师，带特定性格和说话风格"。每个 agent 有固定的名字和 persona：
- Mary — Business Analyst（分析、需求挖掘）
- PM agent（产品管理、PRD）
- UX Designer agent（UX 设计）
- Architect agent（架构设计）
- Dev agent（开发实现）

所有 agent 共享**三层可合并配置系统**：`base → team → user` 的 TOML 文件链。用户不改源码，只在 `_bmad/custom/` 下写 override。`bmad-customize` skill 负责翻译用户意图到正确的配置路径。

**2. 四阶段工作流。**

| 阶段 | 目录 | 核心 skills |
|---|---|---|
| 1-分析 | `bmm-skills/1-analysis` | 分析师 agent、PRD 创建/编辑/验证 |
| 2-规划 | `bmm-skills/2-plan-workflows` | PM agent、UX 设计、Epic/Story 生成 |
| 3-方案设计 | `bmm-skills/3-solutioning` | 架构师 agent、架构文档、实现就绪检查 |
| 4-实施 | `bmm-skills/4-implementation` | Dev agent、Story 开发、代码审查、Sprint 管理 |

不像 superpowers 那样强制按顺序——用户自己决定什么时候推进到下一阶段。

**3. Party Mode。**

把多个 agent persona 拉进同一个会话，像圆桌讨论。Agent 之间可以对话、争论、协作。这不是 subagent 编排——所有 persona 在同一个上下文里轮流发言，由"导演"（orchestrator）控制节奏。类似把 ECC 的多 agent 协作变成了一种叙事体验。支持自定义 party 配置、per-party 记忆持久化。

**4. 不注入 SessionStart。** 所有 skills 按需加载。没有"强制纪律"，用户需要自己知道该调用哪个 step-file。

### 和你用过的对比

| | superpowers | bmad-method |
|---|---|---|
| 流程 | brainstorm→plan→build TDD 强制 | 分析→规划→方案→实施，TDD 非强制 |
| 编排 | leader-worker subagent 执行 | 单 agent 执行 skill，Party Mode 为同上下文对话 |
| 角色 | 无固定 persona | 12+ 命名角色（Mary/Architect/Dev 等） |
| 配置 | 无分层配置 | **三层可合并 TOML**（base→team→user） |
| 状态 | progress ledger | memlog 记忆 + manifest 清单 + sprint 状态 |
| Spec 格式 | 无内置 | SPEC.md 五字段内核（Why/Capabilities/Constraints/Non-goals/Success signal） |
| SessionStart | 注入 using-superpowers 全文 | **不注入** |

---

## 八、trellis

**类型：Hook 驱动的工程框架**（最像 ECC 的简化版 + planning-with-files 的 task 系统）

### 核心机制

三个 Python hook 是灵魂：

**1. SessionStart hook（`session-start.py`，700+ 行）**

动态计算并注入当前状态：活跃 task、git 状态、spec 索引、workflow 阶段。不像 superpowers 注入固定文本，trellis 每次计算。注入约 500-800 tokens。

**2. PreToolUse hook（`inject-subagent-context.py`）**

当 leader 用 Agent tool 派发 implement/check/research 子 agent 时，这个 hook 拦截并自动将任务上下文注入子 agent 的 prompt。子 agent 不需要问"我该做什么"——hook 已经把 prd.md / design.md / implement.md / jsonl 上下文全部塞进去了。

**这是 trellis 和 superpowers SDD 的关键区别**：superpowers 靠 leader 在 prompt 里手动写上下文，trellis 靠 hook 自动注入。

**3. UserPromptSubmit hook（`inject-workflow-state.py`）**

每轮对话注入一条 breadcrumb（`[workflow-state:STATUS]` 标签），提醒 Agent 当前阶段和下一步。文本完全从 `workflow.md` 解析，脚本内不硬编码——workflow.md 是唯一真相源。

**4. task.py — 完整 task 生命周期 CLI**

```
task.py create "<title>" [--assignee] [--priority P0-P3] [--parent <dir>]
task.py start <dir>
task.py finish
task.py archive <task-dir>
task.py list / list-archive
task.py add-subtask / remove-subtask
```

默认 3 种 agent 类型：implement / check / research。task 有状态机（planning → in_progress → archived），支持 parent/child 任务树。

### 和你用过的对比

| | superpowers SDD | trellis |
|---|---|---|
| 子 agent 上下文 | leader 在 prompt 里手动写 | **PreToolUse hook 自动注入** |
| task 管理 | progress ledger（文件标记） | **task.py CLI + 状态机** + parent/child 树 |
| 注入方式 | 固定 skill 全文 | **动态计算**（git 状态 + spec 索引 + workflow 阶段） |
| 路由 | skill 内文本指令 | **每轮 breadcrumb**（从 workflow.md 解析） |
| Agent 定义 | 无 | 3 个（implement/check/research） |
| 跨平台 | 10+ harness | 16 个 AI 编码平台 |
| 协议 | MIT | **AGPL** |
| 规模 | 12 skills / 113 文件 | 15 skills / 3 hooks / Python 运行时 |

---

## 九、planning-with-files

**类型：文件状态机驱动的任务追踪系统**（独此一家，不和其他任何 repo 重叠）

### 核心思想

三个 Markdown 文件对抗 context loss 和任务漂移：

```
task_plan.md    → 阶段、进度、决策
findings.md     → 调研和发现
progress.md     → 会话日志（每次追加，不重复注入）
```

v3.1.3，MIT，17+ IDE 适配，benchmark 96.7% pass rate（Sonnet 4.6）。

### 三种模式

| 模式 | 行为 |
|---|---|
| **legacy** | 向后兼容，单 agent 按 plan 执行，文件只是记录 |
| **autonomous** | 非交互 loop，Agent 自主循环直到完成，适合无人值守 |
| **gated** | **5 层完成门禁**——Agent 不能自己说"做完了"，checklist 验证通过才算数 |

### 注入机制

SessionStart 跑 `inject-plan.sh`，把 task_plan.md 的部分内容注入上下文。同时跑 `session-catchup.py` 从 progress.md 恢复上次会话状态。核心技术：SHA-256 attestation + nonce delimiter + realpath 容器边界检查。

### 编排

默认单 agent。v3 支持 task_plan_autonomous.md 的 phase coordination 字段（DAG 依赖 + flock 保护写入），但多 agent 非核心。

### 和你用过的对比

| | superpowers progress ledger | planning-with-files |
|---|---|---|
| 状态载体 | 上下文内的 Markdown | **文件系统**（对抗 compaction） |
| 完成验证 | skill 内自检 | **gated 模式 5 层门禁** |
| 跨会话 | 无（依赖摘要在上下文内） | **session-catchup.py 恢复完整上下文** |
| 复杂度 | 轻量，嵌入 SDD 流程 | 独立系统，3 种模式可选 |
| 多 agent | leader-worker | 可选 phase coordination（DAG + flock） |

| | trellis task 系统 | planning-with-files |
|---|---|---|
| 状态存储 | JSON 结构化 + Python CLI | **Markdown 文件**（人机可读） |
| 管理方式 | `task.py create/start/finish/archive` | Agent 直接读写文件 |
| 父/子任务 | 支持 parent/child 树 | 不支持 |
| 安装复杂度 | npm + `trellis init` | 复制文件 + 配置 hooks |

---

## 十、三个共同点

这三个都**做 task 管理**（方式不同）：
- bmad：memlog + manifest + sprint 状态
- trellis：task.py CLI + 状态机 + parent/child 树
- planning-with-files：3 个 Markdown 文件 + gated 门禁

三个都**不做 spec 驱动**（和 OpenSpec/spec-kit 无关），三个都**以单 agent 为主**（trellis 有 leader-worker，planning-with-files 可选多 agent）。

---

## 十一、更新后的七项目类型总览

### 分类逻辑（补充）

新增判断维度：**task 管理方式**。有的 harness 只关注"怎么写好代码"（spec/plan/skill 流程），有的还关注"怎么追踪执行进度"（task 状态机/file 追踪）。

| repo | 类型 | task 管理 |
|---|---|---|
| **OpenSpec** | CLI 格式的开发方法论 | 无（文件存在性追踪 change 状态） |
| **spec-kit** | CLI 格式的开发方法论 | 有（tasks.md checkbox + feature 状态文件） |
| **superpowers** | Skill 格式的开发方法论 | 有（SDD progress ledger） |
| **agent-skills** | Skill 格式的开发方法论 | 有（planning-and-task-breakdown skill 生成 tasks） |
| **bmad-method** | CLI + Skill 格式的开发方法论 | 有（memlog + manifest + sprint 状态） |
| **trellis** | Hook 驱动的工程框架 | **强**（task.py CLI + 状态机 + parent/child 树） |
| **planning-with-files** | 文件状态机驱动的任务追踪系统 | **最强**（专为此而生，3 文件 + 3 模式 + gated 门禁） |
| **mattpocock_skills** | 轻量级 Skill 包 | 无 |
| **ECC** | 重量级大规模插件包 | 有（记忆持久化 + checkpoint） |
| **gstack** | 重量级大规模插件包 | 有（learnings.jsonl + checkpoint） |

```
task 管理能力 ◄─── 无 ─────────────── 中 ─────────── 强 ───►

mattpocock   OpenSpec   spec-kit   ECC     bmad    trellis   planning
                            agent-skills  superpowers  gstack    -with-files
                                        ↑
                              你已用过的四个
```
