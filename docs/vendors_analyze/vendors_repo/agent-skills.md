# agent-skills

## 1. 概览

- **一句话定位**：面向 AI 编程 Agent 的生产级工程技能集合，覆盖完整的软件开发生命周期（Define → Plan → Build → Verify → Review → Ship）。
- **设计哲学/解决什么问题**：AI 编程 Agent 默认走最短路径——跳过 spec、跳过测试、跳过安全审查、跳过重构。agent-skills 提供结构化的、带验证门禁的工作流，强制执行资深工程师在交付生产代码时的纪律。每个技能不仅是指令，更是"流程 + 防借口表（anti-rationalization）+ 红牌警告（red flags）+ 验证检查单"的组合。
- **成熟度**：
  - 作者：Addy Osmani（Google Chrome 团队，Software Engineering at Google 合著者）
  - 首次提交：2026-06-09，最新提交：2026-06-28，共约 50 个 commit，开发仅 20 天，仍在快速迭代
  - 文档完整度：高。README 详尽（20KB），skill-anatomy.md 定义格式规范，agents.md 定义编排规则，orchestration-patterns.md（18KB）定义完整模式目录，多数平台有独立 setup 指南
  - Star 数：Trendshift 趋势榜上有名（具体数字未包含在仓库内）
  - License：MIT
  - CI：GitHub Actions 运行 skill 验证、command 一致性校验、marketplace 验证、安装测试

## 2. 安装机制

### Claude Code（推荐方式）

两种安装路径：

**A. Marketplace 安装（一步到位）：**
```bash
/plugin marketplace add addyosmani/agent-skills
/plugin install agent-skills@addy-agent-skills
```
- Claude Code 自动克隆仓库，读取 `.claude-plugin/plugin.json` 和 `.claude-plugin/marketplace.json`
- 自动注册 skills、commands、agents、hooks
- 无需手动改配置

**B. 本地开发安装：**
```bash
git clone https://github.com/addyosmani/agent-skills.git
claude --plugin-dir /path/to/agent-skills
```

### 改了哪些配置文件

安装后，以下内容自动生效（通过 `.claude-plugin/plugin.json` 声明）：

1. **skills/** → 24 个技能被注册为 `agent-skills:<name>` 格式，可通过 Skill tool 调用
2. **.claude/commands/** → 8 个 slash commands 注册到 Claude Code
3. **agents/** → 4 个自定义 subagent 类型（code-reviewer、security-auditor、test-engineer、web-performance-auditor）
4. **hooks/hooks.json** → SessionStart hook 自动注入

用户手动可选配置（需要用户自行添加到 settings.json）：
- **sdd-cache** PreToolUse/PostToolUse hooks（WebFetch 缓存，对应 `hooks/sdd-cache-pre.sh` 和 `hooks/sdd-cache-post.sh`）
- **simplify-ignore** PreToolUse/PostToolUse/Stop hooks（代码块保护，对应 `hooks/simplify-ignore.sh`）

### Symlink 策略

不使用 symlink。整个仓库作为 plugin 目录被 Claude Code 直接读取。所有路径通过 `${CLAUDE_PLUGIN_ROOT}` 环境变量解析。

### 多工具支持

同一套文件通过不同目录的平行副本支持多种工具：
- `.claude/commands/*.md` → Claude Code
- `.gemini/commands/*.toml` → Gemini CLI
- `commands/*.toml` → Antigravity CLI
- `skills/` 目录中纯 Markdown 可用于任意 Agent

`scripts/validate-commands.js` 在 CI 中验证三个目录的命令名称和 description 保持一致。

## 3. 提供的工具全景

### 3.1 Skills（24 个）

全部位于 `skills/<kebab-case-name>/SKILL.md`，按生命周期阶段分组：

| 阶段 | 技能名称 | 一句话说明 |
|------|---------|-----------|
| **Meta** | using-agent-skills | 任务→技能路由发现（流程图 + 核心运行规则） |
| **Define** | interview-me | 单问题逐一访谈，挖掘用户真正想要的东西 |
| **Define** | idea-refine | 发散/收敛思维，将模糊想法精炼为具体提案 |
| **Define** | spec-driven-development | 先写 PRD（目标/命令/结构/风格/测试/边界），再写代码 |
| **Plan** | planning-and-task-breakdown | 将 spec 分解为小的可验证任务，含依赖排序 |
| **Build** | incremental-implementation | 薄垂直切片：实现→测试→验证→提交→下一个 |
| **Build** | test-driven-development | Red-Green-Refactor，测试金字塔 80/15/5，Beyonce 规则 |
| **Build** | context-engineering | 在正确时间向 Agent 提供正确上下文 |
| **Build** | source-driven-development | 以官方文档为基础的验证驱动开发 |
| **Build** | doubt-driven-development | 对抗性全新上下文审查每个非平凡决策 |
| **Build** | frontend-ui-engineering | 组件架构、设计系统、状态管理、WCAG 2.1 AA |
| **Build** | api-and-interface-design | 契约优先设计、Hyrum 定律、单版本规则 |
| **Verify** | browser-testing-with-devtools | 使用 Chrome DevTools MCP 进行运行时验证 |
| **Verify** | debugging-and-error-recovery | 五步分类：复现→定位→缩减→修复→防护 |
| **Review** | code-review-and-quality | 五轴审查（正确性/可读性/架构/安全/性能） |
| **Review** | code-simplification | Chesterton 围栏、500 行规则、保行为降复杂度 |
| **Review** | security-and-hardening | OWASP Top 10、三层边界系统、密钥管理 |
| **Review** | performance-optimization | 先测量再优化、Core Web Vitals、反模式检测 |
| **Ship** | git-workflow-and-versioning | 主干开发、原子提交、~100 行变更大小 |
| **Ship** | ci-cd-and-automation | Shift Left、特性开关、质量门禁流水线 |
| **Ship** | deprecation-and-migration | 代码即负债、弃用策略、迁移模式 |
| **Ship** | documentation-and-adrs | ADR、API 文档、内联文档标准 |
| **Ship** | observability-and-instrumentation | 结构化日志、RED 指标、OpenTelemetry 追踪 |
| **Ship** | shipping-and-launch | 上线前检查单、特性开关生命周期、回滚计划 |

**总计：23 个生命周期技能 + 1 个 meta 技能 = 24 个 Skills**

### 3.2 Slash Commands（8 个）

| 命令 | 触发技能 | 用途 |
|------|---------|------|
| `/spec` | spec-driven-development | 编写结构化 spec |
| `/plan` | planning-and-task-breakdown | 分解为可验证任务 |
| `/build` | incremental-implementation + TDD | 单任务增量实现 |
| `/build auto` | planning + incremental + TDD | 全计划自主实现（一次审批） |
| `/test` | test-driven-development | TDD 工作流 |
| `/review` | code-review-and-quality | 五轴代码审查 |
| `/code-simplify` | code-simplification | 简化代码不改变行为 |
| `/ship` | shipping-and-launch + 并行 fan-out | 上线前审查（3 个 subagent 并行） |
| `/webperf` | web-performance-auditor | Web 性能专项审计 |

### 3.3 自定义 Agents（4 个）

| Agent | 角色 | 审查维度 |
|-------|------|---------|
| code-reviewer | 高级 Staff Engineer | 正确性/可读性/架构/安全/性能，输出结构化报告 |
| security-auditor | 安全工程师 | 输入处理/认证授权/数据保护/依赖审计/OWASP |
| test-engineer | QA 工程师 | 测试策略/覆盖率分析/Prove-It 模式 |
| web-performance-auditor | Web 性能工程师 | CWV 审计，Quick/Deep 双模式 |

### 3.4 Hooks（3 套）

| Hook | 类型 | 用途 |
|------|------|------|
| session-start.sh | SessionStart（自动） | 每次会话注入 using-agent-skills meta-skill |
| sdd-cache-pre.sh + sdd-cache-post.sh | PreToolUse + PostToolUse（手动启用） | source-driven-development 的 HTTP 缓存，304 验证 |
| simplify-ignore.sh | PreToolUse + PostToolUse + Stop（手动启用） | /code-simplify 的代码块保护 |

### 3.5 参考检查单（7 个）

| 文件 | 覆盖内容 |
|------|---------|
| definition-of-done.md | 项目级完工定义（5 个维度 checklist） |
| testing-patterns.md | 测试结构/命名/mock/反模式 |
| security-checklist.md | OWASP/认证/输入验证/CORS/header |
| performance-checklist.md | CWV 目标/前后端 checklist/测量命令 |
| accessibility-checklist.md | 键盘导航/屏幕阅读器/ARIA/测试工具 |
| observability-checklist.md | 结构化日志/RED/USE 指标/追踪/告警 |
| orchestration-patterns.md | 5 种编排模式 + 4 种反模式 + 决策流 |

### 3.6 验证脚本（2 个）

| 脚本 | 用途 |
|------|------|
| validate-skills.js | CI：校验所有 SKILL.md 的 frontmatter、命名、section 完整性、跨引用 |
| validate-commands.js | CI：校验三个平台命令的 parity 和 description 一致性 |

### 3.7 其他

| 类型 | 内容 |
|------|------|
| Claude Code rules | `.claude/rules/skills-contributing.md`：skills/** 路径触发的防重复 guard |
| CI workflow | `.github/workflows/test-plugin-install.yml`：skill 验证 → command 验证 → marketplace 验证 → 安装测试 |

**总数统计：24 Skills + 8 Commands + 4 Agents + 3 Hooks + 7 References + 2 Scripts + 1 Rule + 1 CI = 50 个工具/组件**

## 4. 核心工具详解

### 4.1 `using-agent-skills`（Meta-Skill / 路由器）

**完整执行流程：**

1. **SessionStart hook 触发** → `hooks/session-start.sh` 读取 `skills/using-agent-skills/SKILL.md` 全文，通过 jq 构造 JSON payload，以 priority: "IMPORTANT" 注入当前会话
2. **任务到达** → Agent 查看流程图（ASCII 决策树），按开发阶段匹配对应 skill
3. **流程图路由**（19 个分支节点）：
   - 不知道要什么？→ interview-me
   - 有模糊概念？→ idea-refine
   - 新项目/功能？→ spec-driven-development
   - 有 spec 需任务？→ planning-and-task-breakdown
   - 实现代码？→ incremental-implementation（子路由：UI→frontend-ui-engineering, API→api-and-interface-design, 需要上下文→context-engineering, 需验证文档→source-driven-development, 高风险→doubt-driven-development）
   - 写测试？→ test-driven-development（浏览器→browser-testing-with-devtools）
   - 出问题了？→ debugging-and-error-recovery
   - 审查代码？→ code-review-and-quality（太复杂→code-simplification, 安全→security-and-hardening, 性能→performance-optimization）
   - 提交？→ git-workflow-and-versioning
   - CI/CD？→ ci-cd-and-automation
   - 弃用/迁移？→ deprecation-and-migration
   - 文档？→ documentation-and-adrs
   - 日志/指标/告警？→ observability-and-instrumentation
   - 部署？→ shipping-and-launch
4. **Agent 调用 Skill tool**，加载匹配的 `SKILL.md` 全文
5. **Agent 遵循 skill 的 Process 步骤**，完成后执行 Verification checklist
6. **全程遵守 6 条核心运行规则**：暴露假设、管理困惑、必要反驳、强制简洁、范围纪律、验证不假设

**输入/输出：**
- 输入：用户自然语言任务描述
- 输出：匹配的 skill 名称（Agent 自行判断并调用 Skill tool）

**底层能力：** Skill tool（Agent 调用）、SessionStart hook（注入）

**关键设计决策：**
- 使用流程图而非自然语言匹配，减少路由歧义
- 注入优先级为 IMPORTANT（非 CRITICAL），让 Agent 自行判断
- 依赖 jq 做 JSON 转义，jq 不可用时降级为 INFO 级别提示

### 4.2 `/spec` → `spec-driven-development`

**完整执行流程：**

1. **用户输入 `/spec`** → Claude Code 加载 `.claude/commands/spec.md`（12 行轻量 prompt）
2. **Agent 调用** `agent-skills:spec-driven-development` skill
3. **Phase 1: Specify**
   - Agent 首先列出所有假设（ASSUMPTIONS I'M MAKING: 1...2...3...）
   - 提出澄清问题，等待用户确认或修正
   - 编写 spec 文档，覆盖 6 个核心领域：
     a. Objective — 构建什么、为谁、成功标准
     b. Commands — 完整可执行命令（含 flags）
     c. Project Structure — 目录布局及说明
     d. Code Style — 真实代码片段 + 命名/格式约定
     e. Testing Strategy — 框架、位置、覆盖率、测试级别
     f. Boundaries — 三层边界（Always/Ask First/Never）
   - 将模糊需求重构为可测量成功标准（如 "让 dashboard 更快" → "LCP < 2.5s"）
4. **Human review gate** → 用户审阅并批准 spec
5. **Phase 2: Plan** → 识别组件依赖、实现顺序、风险缓解、并行/串行识别、验证检查点（委托给 planning-and-task-breakdown）
6. **Phase 3: Tasks** → 分解为离散任务，每任务有验收标准 + 验证步骤 + 涉及文件（委托给 planning-and-task-breakdown）
7. **Phase 4: Implement** → 逐一执行任务（委托给 incremental-implementation + TDD + context-engineering）
8. **Spec 生命周期管理** → 决策变化时更新 spec、范围变化时更新、提交到版本控制、在 PR 中引用
9. **Verification** → 检查 spec 覆盖全部 6 个领域、用户已批准、成功标准可测量、边界已定义、已保存到仓库

**输入/输出：**
- 输入：用户需求描述（可能模糊）
- 输出：`SPEC.md`（仓库根目录）、后续计划入口

**底层能力：** Read（读现有代码）、Write（写 SPEC.md）、Skill tool（触发子 skill）、用户交互（澄清问题）

**关键设计决策：**
- 强制先暴露假设再写 spec，防止 Agent 自行填补模糊需求
- spec 是"活文档"而非一次性产物
- Spec→Plan→Tasks→Implement 四相位，每相位有人门禁
- 将 Plan/Tasks 阶段委托给 planning-and-task-breakdown（单一真相源），skill 内只保留轻量摘要

### 4.3 `/build auto`（自主实现模式）

**完整执行流程：**

1. **用户输入 `/build auto`** → 加载 `.claude/commands/build.md`
2. **Step 1: Require a spec** → 在 `SPEC.md` / `docs/SPEC.md` / `spec/` 中查找 spec。不存在则停止，要求先 `/spec`
3. **Step 2: Establish a clean baseline** → `git status --porcelain`，如果有不在预期产物中的未提交变更，停止并要求用户处理
4. **Step 3: Plan if needed** → 若无 `tasks/plan.md`，调用 planning-and-task-breakdown 生成。生成后作为预备提交单独 commit
5. **Step 4: Single checkpoint** → 展示完整计划，等待明确肯定（"approve"/"go"/"yes"），模糊回应视为未批准
6. **Step 5: Execute every task in dependency order** → 对每个任务：
   a. 读取任务验收标准
   b. 加载相关上下文
   c. RED：写失败测试
   d. GREEN：最小实现
   e. 运行全量测试套件
   f. 运行构建验证
   g. 只 stage 该任务涉及的文件 + 状态更新（不用 `git add -A`）
   h. 一次 commit per task
   i. 标记任务完成
7. **Step 6: Stop and ask** → 当出现以下情况时暂停：
   - 测试无法通过或构建无法修复 → debugging-and-error-recovery
   - spec 模糊需决策 → 请求用户
   - 高风险操作（认证/权限/数据迁移/支付/删除/密钥）→ doubt-driven-development + 明确签字
8. **完成后总结**：完成任务数、测试数、commit 数、跳过/标记项

**输入/输出：**
- 输入：`SPEC.md` + `tasks/plan.md`（或由 agent 生成）
- 输出：每个任务一个 commit、全部测试通过、构建成功

**底层能力：** Bash（git 操作、测试运行、构建）、Read（读代码）、Write/Edit（写代码）、Skill tool（触发子 skill）

**关键设计决策：**
- "不跳过验证，只跳过人工步进"——每个任务仍走完整 RED→GREEN→REGRESSION→BUILD→COMMIT 循环
- 每任务一个 commit，保证任一点可干净回滚
- 6 类高风险操作必须有显式人工签字
- 使用 git 作为 checkpoint 机制而非额外持久化层

### 4.4 `/ship`（并行 Fan-Out 上线门禁）

**完整执行流程：**

1. **用户输入 `/ship`** → 加载 `.claude/commands/ship.md`
2. **Phase A: Parallel fan-out** → 在单个 assistant turn 中同时发出 3 个 Agent tool 调用：
   - Agent 1: `subagent_type: code-reviewer` → 五轴审查报告
   - Agent 2: `subagent_type: security-auditor` → 安全审计报告
   - Agent 3: `subagent_type: test-engineer` → 测试覆盖率分析
   - 每个 subagent 有独立 context window，只返回报告
3. **Phase B: Merge in main context** → 主 Agent 合并三份报告：
   - Code Quality：汇总 Critical/Important 发现，去重
   - Security：提升 Critical/High 到上线阻断
   - Performance：交叉验证
   - Accessibility：直接验证（subagent 不覆盖）
   - Infrastructure：环境变量/迁移/监控/特性开关
   - Documentation：README/ADR/changelog
4. **Phase C: Decision and rollback** → 输出统一决策：
   ```
   ## Ship Decision: GO | NO-GO
   ### Blockers（来源 persona + file:line）
   ### Recommended fixes（来源 persona + file:line）
   ### Acknowledged risks（风险 + 缓解）
   ### Rollback plan（触发条件 + 回滚步骤 + RTO）
   ### Specialist reports（三份完整报告）
   ```
5. **规则**：
   - 三个 Phase A persona 并行运行，禁止串行
   - Persona 不可调用其他 persona
   - 回滚计划在 GO 决策前强制
   - 任意 persona 返回 Critical → 默认 NO-GO（除非用户显式接受风险）
   - 仅当变更 ≤ 2 文件、diff ≤ 50 行、不涉及 auth/payments/data/config 时才可跳过 fan-out

**输入/输出：**
- 输入：当前 staged/unstaged 变更
- 输出：`## Ship Decision: GO | NO-GO` 结构化报告（含 Blockers + Rollback plan + 三份完整子报告）

**底层能力：** Agent tool（并行 subagent spawn）、Read（读变更）、Bash（验证操作）

**关键设计决策：**
- Personas 不调用 Personas——编排是 slash command 的工作；这是 agent-skills 的流程规则，不泛化为 omni_powers 的永久平台契约
- 合并阶段留在主 Agent 上下文中（不在 subagent 中），保证全量上下文可见
- 与 Agent Teams 区分：subagent 只报告结果；当 subagent 需要互相挑战时用 Agent Teams

### 4.5 `/webperf`（Web 性能专项审计）

**完整执行流程：**

1. **确定模式**：
   - **Deep mode**：有 Lighthouse JSON / PSI JSON / CrUX API / DevTools trace / chrome-devtools MCP → 基于真实数据审计，scorecard 用实测值填充
   - **Quick mode**（默认）：无测量数据 → 扫描源码找结构化反模式，所有发现标记 `potential impact`
2. **Spawn `web-performance-auditor` subagent**，传入：
   - 审查范围（文件/组件/diff）
   - 数据来源路径或粘贴内容
   - 目标 URL
   - 预期模式（Quick 或 Deep）
3. **Subagent 返回**：scorecard（仅实测值填充）、排名发现列表、正面观察、前瞻建议
4. **主 Agent 直接返回报告**，无合并步骤（单 persona 命令）

**输入/输出：**
- 输入：可选测量数据（Lighthouse/PSI/CrUX/trace JSON）+ 代码范围
- 输出：结构化性能审计报告（scorecard + 排名发现 + 建议）

**关键设计决策：**
- 双模式设计：有数据时精度优先，无数据时不假装测量
- scorecard 标记 `not measured` 而非留空，防止误读

## 5. 文件规范

### 目录结构

```
agent-skills/
├── skills/                              # 核心：24 个技能（每目录一个 SKILL.md）
│   └── <skill-name>/
│       ├── SKILL.md                     #   必需：技能定义
│       ├── scripts/                     #   可选：可运行辅助脚本
│       └── <supporting-file>.md         #   可选：按需加载参考材料（>100 行才拆出）
├── agents/                              # 4 个专业 persona
│   └── <role>.md
├── .claude/commands/                    # 8 个 Claude Code slash commands (.md)
├── .gemini/commands/                    # 8 个 Gemini CLI slash commands (.toml)
├── commands/                            # 8 个 Antigravity CLI slash commands (.toml)
├── hooks/                               # Session 生命周期 hooks
│   ├── hooks.json                       #   SessionStart hook 声明
│   ├── session-start.sh                 #   meta-skill 注入脚本
│   ├── sdd-cache-pre.sh                 #   WebFetch 缓存预检
│   ├── sdd-cache-post.sh                #   WebFetch 缓存存储
│   ├── SDD-CACHE.md                     #   sdd-cache 说明
│   ├── simplify-ignore.sh               #   代码块保护（Pre/Post/Stop 三合一）
│   ├── SIMPLIFY-IGNORE.md               #   simplify-ignore 说明
│   ├── session-start-test.sh            #   hook 回归测试
│   └── simplify-ignore-test.sh          #   hook 回归测试
├── references/                          # 7 个补充检查单（技能按需引用）
│   └── <checklist-name>.md
├── scripts/                             # CI 验证脚本
│   ├── validate-skills.js               #   技能 frontmatter/命名/section 校验
│   └── validate-commands.js             #   三平台命令 parity/description 一致性校验
├── docs/                                # 面向人类的文档（不加载到 agent context）
│   ├── skill-anatomy.md                 #   技能格式规范（单一真相源）
│   ├── agents.md                        #   Persona 编排规则
│   ├── comparison.md                    #   与 Superpowers/MattPocock 对比
│   ├── getting-started.md               #   通用入门指南
│   └── <tool>-setup.md                  #   各工具独立安装指南
├── .claude-plugin/
│   ├── plugin.json                      #   Claude Code plugin manifest
│   └── marketplace.json                 #   Marketplace 注册信息
├── .claude/rules/
│   └── skills-contributing.md           #   skills/** 路径触发规则（防重复）
├── plugin.json                          #   Antigravity CLI plugin manifest
├── .github/workflows/                   #   CI：skill 验证 + command 验证 + 安装测试
├── CLAUDE.md                            #   本 repo 自身的 Claude Code 指令
├── AGENTS.md                            #   多 Agent 平台通用指令
├── CONTRIBUTING.md                      #   贡献指南
├── README.md                            #   20KB 完整文档
└── .gitignore
```

### 命名约定

- **技能目录**：`lowercase-hyphen-separated`（如 `spec-driven-development`）
- **技能文件**：`SKILL.md`（始终大写）
- **辅助文件**：`lowercase-hyphen-separated.md`
- **参考材料**：存放在 `references/`（项目根），不在 skill 目录内
- **脚本**：`#!/bin/bash`、`set -e`、状态消息写 stderr、机器可读输出写 stdout、含 cleanup trap
- **Agent 文件**：`agents/<role>.md`，kebab-case 角色名
- **命令文件**：`.claude/commands/<name>.md`、`.gemini/commands/<name>.toml`、`commands/<name>.toml`；三平台名称必须一致（例外：`plan.md` ↔ `planning.toml`，在 validate-commands.js 中硬编码映射）

### Frontmatter / Metadata Schema

**Skill SKILL.md frontmatter（必需）：**
```yaml
---
name: skill-name-with-hyphens    # 必须匹配目录名，全小写连字符
description: <what it does, third person>. Use when <trigger conditions>.
# 最大 1024 字符，必须同时说明"做什么"和"何时用"
---
```

**Agent .md frontmatter（必需）：**
```yaml
---
name: role-name                  # subagent_type 引用时的标识符
description: <role + perspective>. Use for <trigger conditions>.
---
```

**Agent 额外字段（Claude Code plugin 支持）：**
- `model`：Haiku/Sonnet/Opus（按 persona 优化成本）
- `tools` / `disallowedTools`：工具白名单/黑名单
- `skills`：自动加载的技能列表
- `maxTurns`、`effort`、`isolation`、`color`、`background`、`initialPrompt`
- **不支持**（会被静默忽略）：`hooks`、`mcpServers`、`permissionMode`

**Command .md frontmatter：**
```yaml
---
description: <one-line description>
---
```

**SKILL.md 标准 Section（推荐模式，非强制模板）：**
1. `## Overview` — 一句话定位
2. `## When to Use` — 触发条件 + 排除条件
3. `## [Core Process / The Workflow / Steps]` — 分步工作流
4. `## [Specific Techniques / Patterns]` — 详细指导
5. `## Common Rationalizations` — 表格：借口 vs 现实
6. `## Red Flags` — 违规信号
7. `## Verification` — 退出检查单（每项需可验证证据）

## 6. SessionStart 注入

### 注入了什么内容

`hooks/session-start.sh` 在每次 Claude Code 会话启动时：

1. 读取 `skills/using-agent-skills/SKILL.md` 全文
2. 通过 `jq -cn` 构造 JSON：
   ```json
   {
     "priority": "IMPORTANT",
     "message": "agent-skills loaded. Use the skill discovery flowchart to find the right skill for your task.\n\n<SKILL.md 全文>"
   }
   ```
3. 如果 jq 不可用 → 降级为 `priority: "INFO"` + 安装 jq 的提示
4. 如果 meta-skill 文件不存在 → `priority: "INFO"` + 错误提示

### 注入内容大小

`skills/using-agent-skills/SKILL.md` 全文约 192 行（含流程图 + 6 条核心运行规则 + 10 条失败模式 + 生命周期排序 + 快速参考表）。

### Context 消耗量预估

约 3,500-4,000 tokens（192 行 Markdown 含 ASCII 流程图和表格）。该 skill 被标记为 IMPORTANT 优先级，Agent 在每轮对话中都会看到，但不会被强制遵守（不同于 CRITICAL）。实际的 23 个技能按需加载（skill 名称和 description 在启动时注册，全文仅在 Agent 调用 Skill tool 时加载）。

## 7. 状态管理

### 核心理念：无状态

agent-skills **不提供内置状态管理机制**。Skills 是纯工作流描述（Markdown 文件），自身不维护任何运行时状态。

### 间接状态机制

| 机制 | 存储位置 | 生命周期 | 用途 |
|------|---------|---------|------|
| Spec/Plan 产物 | `SPEC.md`、`tasks/plan.md`、`tasks/todo.md` | 项目级，版本控制 | 工作流之间的上下文传递（spec → plan → build） |
| Git commits | `.git/` | 项目级 | `/build auto` 的 checkpoint 机制（每任务一个 commit） |
| sdd-cache | `.claude/sdd-cache/<sha>.json` | 项目级，本地磁盘 | HTTP 文档缓存（含 ETag/Last-Modified revalidation） |
| simplify-ignore cache | `.claude/.simplify-ignore-cache/` | 项目级，本地磁盘 | 受保护代码块的备份和恢复 |
| Session 内存 | Agent context window | Session 级 | skill 加载后的上下文（无持久化） |

### 设计意图

- 不重复造轮子——状态由文件系统 + Git + 项目原有机制提供
- 技能调用结果通过文件产物（SPEC.md、测试文件）在 skill 之间传递
- sdd-cache 和 simplify-ignore 是纯优化/保护 hook，不是通用状态层

## 8. 编排模式

agent-skills 定义了 5 种明确 endorse 的编排模式和 4 种明确反对的反模式。核心原则：**用户（或 slash command）是编排者，Persona 不调用其他 Persona**。

### 8.1 模式 1：直接调用（无编排）

```
user → code-reviewer → report → user
```

- 单 persona、单视角、单产物
- 成本：一个 round trip
- 示例："Review this PR" → code-reviewer

### 8.2 模式 2：单 Persona Slash Command

```
/review → code-reviewer (with code-review-and-quality skill) → report
```

- slash command 封装一个 persona + 项目 skill
- 成本：与直接调用相同
- 示例：`/review`、`/test`、`/code-simplify`、`/webperf`

### 8.3 模式 3：并行 Fan-Out + 合并

```
                    ┌─→ code-reviewer    ─┐
/ship → fan out  ───┼─→ security-auditor ─┤→ merge → go/no-go + rollback
                    └─→ test-engineer    ─┘
```

- 多个 persona 对同一输入并行操作，各自独立报告
- 合并步骤留在主 Agent 上下文中
- 使用前提：子任务真正独立、各 persona 产出不同类型发现、合并步骤足够小、延迟敏感
- 示例：`/ship`

### 8.4 模式 4：用户驱动的串行流水线

```
user runs:  /spec  →  /plan  →  /build  →  /test  →  /review  →  /ship
```

- 用户按定义顺序执行 slash commands，context（或 commit history）在步骤间传递
- 无编排 Agent——用户就是编排者
- 成本：每步一个 subagent context；编排层无成本（因为无编排 Agent）
- 覆盖：完整的 DEFINE → PLAN → BUILD → VERIFY → REVIEW → SHIP 生命周期

### 8.5 模式 5：研究隔离

```
main agent → research sub-agent (reads 50 files) → digest → main agent continues
```

- 当任务需要读取大量材料但不污染主 context 时使用
- Claude Code 上优先使用内置 `Explore` subagent
- 示例："找到整个 monorepo 中所有调用废弃 API 的位置"

### 8.6 反模式

| 反模式 | 描述 | 为什么失败 |
|--------|------|-----------|
| A. 路由 Persona | 一个 persona 决定调用哪个 persona | 纯路由层无价值、两次转述级联信息损失、多余 token 成本 |
| B. Persona 调用 Persona | code-reviewer 内部调用 security-auditor | 破坏单视角设计、上下文丢失、失败模式指数增长 |
| C. 串行编排器转述 | 一个 Agent 自动调用 /spec → /plan → /build | 丢失人工检查点、累积漂移、数据加倍 |
| D. 深层 Persona 树 | /ship → pre-ship-coordinator → quality-coordinator → code-reviewer | 每层增加延迟和 token、无决策价值、叶 persona 丢失 context |

### 8.7 Claude Code / agent-skills 编排边界

- agent-skills 明确把 persona 互调列为反模式；不要把这一点泛化为 omni_powers 的永久平台契约
- 深层 persona 树会放大上下文丢失、延迟和失败面，agent-skills 选择用用户/命令层编排规避
- Plugin agent 不支持 `hooks`/`mcpServers`/`permissionMode`
- 并行 fan-out 需在单 assistant turn 中发出多个 Agent tool 调用

### 8.8 与 Superpowers / omni_powers 的差异

agent-skills 的编排模式特点是：
- 人工 checkpoint 密集（每个阶段有人门禁）
- 单个 slash command 轻量（prompt 仅 10-20 行，委托给 skill）
- 重度依赖 skill 内的 rationalizations 表格和 red flags 做质量控制
- 无 worktree 隔离、无 subagent-driven development pattern（对比 Superpowers）
- 无 task 生命周期状态机；omni_powers 也不是独立 DAG 引擎，只是 `tasks_list.json.depends_on` + jq 拓扑检查
