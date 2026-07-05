# superpowers

## 1. 概览

- **一句话定位：** 为 coding agent 提供完整软件开发方法论的多平台插件/技能包。通过 12 个自动触发的 skill 覆盖 brainstorming -> plan -> TDD -> subagent 执行 -> review -> merge 的全流程。
- **设计哲学/解决什么问题：**
  - 让 AI coding agent 遵循与人类优秀工程师一致的开发规程：先设计再编码、TDD、分步 review、不跳过验证。
  - 所有 skill 自动触发，无需用户手动调用。核心机制是在 SessionStart 时将 `using-superpowers` 技能全文注入 system context，使 agent 在任何操作前都先检查是否有 matching skill。
  - 强调铁律（Iron Law）、红牌（Red Flags）、合理化陷阱（Rationalizations）——通过反复的心理暗示/行为纠正来解决 LLM "想跳过流程直接写代码"的倾向。
  - 零外部依赖。所有功能纯用 shell / JS / SKILL.md 实现，不依赖 npm 包、MCP server 或外部服务。
- **成熟度：**
  - 版本 6.1.0，commit 数 ~50（仅 2026 年至今），释出公告 1317 行。
  - 活跃维护。支持 10+ 个 harness（Claude Code、Codex、Cursor、Kimi Code、OpenCode、Pi、Copilot CLI、Antigravity、Factory Droid 等）。
  - 有专门 eval 套件（superpowers-evals），含 tmux 驱动的实际 session 测试。

## 2. 安装机制

superpowers 本身无 `install.sh`。它依赖各 harness 的 plugin 机制安装：

- **Claude Code:** `/plugin install superpowers@claude-plugins-official`（从官方 marketplace 安装）
- **Codex:** marketplace 搜索 "superpowers" 安装
- **Cursor:** `/add-plugin superpowers` 或 marketplace 搜索
- **Kimi Code:** `/plugins install https://github.com/obra/superpowers`
- **OpenCode:** 按 `.opencode/INSTALL.md` 指引操作
- **Pi:** `pi install git:github.com/obra/superpowers`
- **Antigravity:** `agy plugin install https://github.com/obra/superpowers`

各级 harness plugin 配置做的事：
1. 注册 skills 目录（`skills/`）供 agent 发现
2. 注册 SessionStart hook，将其指向 `hooks/session-start` 脚本
3. 可以注入额外的 platform adapter（如 Pi 的 `extension.ts`、OpenCode 的 `plugin.js`）

**改了什么配置文件？**

以 Claude Code 为例（`.claude-plugin/plugin.json`）：
```json
{
  "name": "superpowers",
  "version": "6.1.0",
  ...
}
```

- 不修改用户自己的 `settings.json` / `CLAUDE.md`
- SessionStart hook 通过 `hooks/hooks.json` 声明：在 `startup|clear|compact` 事件中触发 `hooks/run-hook.cmd session-start`
- hook 输出 JSON，含 `hookSpecificOutput.additionalContext` 字段，内容即为 `using-superpowers/SKILL.md` 全文（转义后）

**symlink 策略：** 不使用 symlink。skills 目录由 plugin 的 manifest 中的 `"skills": "./skills/"` 字段指向实际路径，各个 harness 原生发现。

## 3. 提供的工具全景

### Skills (12 个)

| 名称 | 用途 | 触发场景 |
|------|------|---------|
| `using-superpowers` | 核心引导 skill——规定 agent 在**任何响应前**必须先检查是否有 matching skill | 每次 SessionStart 注入，不做工具调用 |
| `brainstorming` | Socratic 式设计对话：探索上下文->问问题->提方案->展示设计->写 spec->自审->用户审批->转 planning | 用户说"我要做 X"前 |
| `writing-plans` | 将 spec 转化为极细粒度的实现计划（每个步骤 2-5 分钟，含完整代码、精确文件路径、验证命令） | spec 审批后 |
| `subagent-driven-development` | Plan 执行引擎：逐 task 分派 implementer subagent，每 task 后 dispatch reviewer subagent，两阶段 review（spec 合规 + 代码质量），全部 task 后 dispatch 最终全分支 review | 有 plan 且 task 独立时 |
| `executing-plans` | 替代方案：在同 session 内顺序执行 plan（无 subagent），有 checkpoint | 有 plan 但无 subagent 能力时 |
| `test-driven-development` | 铁律：RED(写失败测试)->GREEN(最小代码)->REFACTOR。含常见反模式、合理化陷阱 | 任何实现、修 bug、重构前 |
| `systematic-debugging` | 四阶段：Root Cause -> Pattern Analysis -> Hypothesis -> Implementation。铁律：无根因调查不得提修复 | 任何 bug、测试失败、异常行为 |
| `verification-before-completion` | 铁律：无新鲜验证证据不得声称完成。必须在当前消息内实际跑命令、看输出 | 声称完成/修好/通过前 |
| `requesting-code-review` | 分派 code-reviewer subagent 检查工作是否符合 plan 和质量标准 | 每 task 后、feature 完成、合并前 |
| `receiving-code-review` | 如何接收 review 反馈：验证而非盲从；禁止表演性同意；YAGNI 检查；技术推理 push back | 收到 review 反馈时 |
| `using-git-worktrees` | 确保在隔离 workspace 中工作：检测现有隔离->优先原生 worktree 工具->fallback git worktree->项目 setup->基线验证 | brainstorming 审批后、执行 plan 前 |
| `finishing-a-development-branch` | 验证测试->检测环境->展示 4 选项（本地 merge/PR/保留/丢弃）->执行选择->清理 worktree | 所有 task 完成、测试通过后 |
| `dispatching-parallel-agents` | 将独立任务并行派给多个 subagent，每个 agent 有精确的 scope/context/expected_output | 2+ 独立问题域 |
| `writing-skills` | 用 TDD 方法创建/修改 skill：写 pressure scenario -> 跑基线（无 skill）-> 写 skill -> 验证合规 -> 堵漏洞 | 创建/修改 skill 时 |

### Hooks

| 类型 | 文件 | 说明 |
|------|------|------|
| SessionStart | `hooks/session-start` | 注入 `using-superpowers` 全文到 additionalContext。在 startup/clear/compact 事件触发 |
| SessionStart | `hooks/session-start-codex` | Codex 专用版本 |
| 通用 | `hooks/run-hook.cmd` | 跨平台 polyglot wrapper（Windows cmd + Unix bash），找到 bash 并执行对应脚本 |
| 配置 | `hooks/hooks.json` | Claude Code hook 声明 |
| 配置 | `hooks/hooks-cursor.json` | Cursor hook 声明 |

### 自定义 Agents

superpowers **不定义** custom agent（无 `agents/` 目录下的 agent 定义文件）。但它在其 skill 中大量使用 **subagent dispatch pattern**——通过 prompt template + `Agent` tool 调用 `general-purpose` agent。

核心 subagent prompt template：
- `implementer-prompt.md`：实施者 subagent 的调度模板（含 self-review、4 状态返回、report 格式）
- `task-reviewer-prompt.md`：task reviewer subagent 的调度模板（spec 合规 + 代码质量双裁决）
- `code-reviewer.md`：最终全分支 reviewer subagent 的调度模板

### CLI 工具/可执行脚本

| 脚本 | 用途 |
|------|------|
| `skills/subagent-driven-development/scripts/task-brief` | 从 plan 文件中按 Task 编号提取单个 task 的完整文本到文件 |
| `skills/subagent-driven-development/scripts/review-package` | 生成 review package（commit list + stat + full diff with context）为单个文件 |
| `skills/subagent-driven-development/scripts/sdd-workspace` | 解析并确保 `.superpowers/sdd/` workspace 目录存在 |
| `scripts/lint-shell.sh` | Shell 代码 lint |
| `scripts/bump-version.sh` | 版本号 bump |
| `scripts/sync-to-codex-plugin.sh` | 同步到 Codex plugin |
| `skills/brainstorming/scripts/server.cjs` | Visual Companion 的零依赖 WebSocket 服务器 |
| `skills/brainstorming/scripts/start-server.sh` | 启动 visual companion |
| `skills/brainstorming/scripts/stop-server.sh` | 停止 visual companion |
| `skills/brainstorming/scripts/helper.js` | 浏览器辅助脚本 |
| `skills/systematic-debugging/find-polluter.sh` | 查找污染 commit 的辅助脚本 |

### MCP Servers

**无。** superpowers 有意不引入 MCP server 或其他外部依赖。

### 模板/脚手架

- `docs_template/` — 无（无此目录）
- `skills/writing-skills/examples/CLAUDE_MD_TESTING.md` — 仅有一个测试示例

### 配置文件/Rules

| 文件 | 说明 |
|------|------|
| `.claude-plugin/plugin.json` | Claude Code plugin 声明 |
| `.claude-plugin/marketplace.json` | Claude Code marketplace 注册信息 |
| `.codex-plugin/plugin.json` | Codex plugin 声明 |
| `.cursor-plugin/plugin.json` | Cursor plugin 声明 |
| `.kimi-plugin/plugin.json` | Kimi Code plugin 声明 |
| `.opencode/plugins/superpowers.js` | OpenCode plugin（JS，含 message transform、config 注入） |
| `.pi/extensions/superpowers.ts` | Pi extension（TS，含 session_start/compact 事件、context 事件注入） |
| `.agents/plugins/marketplace.json` | 开发用 marketplace |
| `hooks/hooks.json` | Claude Code hook 声明 |
| `hooks/hooks-cursor.json` | Cursor hook 声明 |
| `AGENTS.md` -> `CLAUDE.md` | 贡献指南（symlink） |

### 其他

- `skills/brainstorming/visual-companion.md`：Visual Companion 使用指南（浏览器端零依赖服务器，用于展示 mockup/diagram）
- `skills/test-driven-development/testing-anti-patterns.md`：测试反模式参考
- `skills/systematic-debugging/root-cause-tracing.md`：根因追踪技术
- `skills/systematic-debugging/defense-in-depth.md`：多层防御技术
- `skills/systematic-debugging/condition-based-waiting.md`：条件等待替代任意 timeout
- `skills/writing-plans/plan-document-reviewer-prompt.md`：plan 文档审查者 prompt
- `skills/writing-skills/anthropic-best-practices.md`：Anthropic 官方 skill 写作最佳实践
- `skills/writing-skills/persuasion-principles.md`：说服原则（用于 skill 内容设计）
- `skills/writing-skills/graphviz-conventions.dot`：Graphviz 图约定
- `skills/writing-skills/render-graphs.js`：渲染图脚本
- `skills/writing-skills/testing-skills-with-subagents.md`：用 subagent 测试 skills
- `skills/using-superpowers/references/`：各 harness 工具映射参考（codex-tools.md、pi-tools.md、antigravity-tools.md）

## 4. 核心工具详解

### 4.1 using-superpowers（bootstrap 注入）

这是整个 superpowers 系统的**基石**——没有它，其他所有 skill 都无法自动触发。

**完整执行流程：**

1. Harness 启动 session，触发 SessionStart hook
2. `hooks/run-hook.cmd` 找到 bash，执行 `hooks/session-start`
3. session-start 脚本读取 `skills/using-superpowers/SKILL.md` 全文（去 frontmatter 后约 40 行）
4. 将内容用 `\n` 转义后嵌入 JSON additionalContext
5. 平台判断（`CLAUDE_PLUGIN_ROOT` / `CURSOR_PLUGIN_ROOT` / 其他）选择正确的 JSON 字段格式
6. Agent 在 session start 时收到包含以下内容的消息：

```
<EXTREMELY_IMPORTANT>
You have superpowers.
**Below is the full content of your 'superpowers:using-superpowers' skill...**
[using-superpowers 全文]
</EXTREMELY_IMPORTANT>
```

**输入：** `skills/using-superpowers/SKILL.md`
**输出：** JSON with `additionalContext`（约 2KB-3KB 纯文本）
**底层能力：** Bash（cat、printf、参数替换转义）
**关键设计约束：**
- 不通过 `Skill` tool 加载（直接注入 context，避免 agent 还需"主动调用 skill"）
- 对 subagent 有 `<SUBAGENT-STOP>` 标记——subagent 不会重复执行 bootstrap
- 在 `startup|clear|compact` 三个事件都触发（resume/压缩后确保引导不丢失）

### 4.2 sun_agent-driven-development（SDD，核心执行引擎）

superpowers 最复杂、最能代表其"Subagent 驱动"设计哲学的核心 skill。

**完整执行流程：**

1. 读 plan 文件一次，提取全局约束，创建 todo 列表
2. **Pre-Flight Plan Review：** 扫描整个 plan 找冲突——task 间矛盾、plan 要求但 review rubric 视为缺陷的东西——一次性 batch 问用户
3. **Per-task loop：**
   a. 运行 `scripts/task-brief PLAN_FILE N` -> 将 task N 的完整文本写入 `.superpowers/sdd/task-N-brief.md`
   b. 填充 `implementer-prompt.md` 模板，dispatch general-purpose subagent（必须指定 model），传入 brief 路径 + report 路径 + context
   c. Implementer subagent 工作->自审->写 report 文件->返回 status（DONE/DONE_WITH_CONCERNS/BLOCKED/NEEDS_CONTEXT；superpowers vendor 状态，不适用于 omni_powers 当前 implementer 状态集）
   d. Controller 处理 status：
      - DONE：运行 `scripts/review-package BASE HEAD` -> 生成 diff 文件
      - DONE_WITH_CONCERNS：读 concerns->判断是否阻断
      - NEEDS_CONTEXT：提供缺失上下文->重新分派
      - BLOCKED：分析原因->改善后重分派或升级给用户
   e. 填充 `task-reviewer-prompt.md` 模板，dispatch reviewer subagent，传入 brief + report + diff 文件路径 + global constraints
   f. Reviewer 返回 spec 合规 verdict + code quality verdict + issues 列表
   g. 如有 Critical/Important findings -> dispatch fix subagent -> fixer 追加 fix report 到 report 文件 -> 重新 review
   h. Review 通过 -> 在 progress ledger 追加一行 `Task N: complete (commits <base7>..<head7>, review clean)` -> mark todo complete
4. **所有 task 完成后：** 运行 `scripts/review-package MERGE_BASE HEAD` -> dispatch 最终全分支 code-reviewer
5. 最终 reviewer 通过 -> 调用 `superpowers:finishing-a-development-branch`

**输入：** plan 文件路径
**输出：** 每 task 完成的 commits + 最终通过测试的分支
**底层能力：** Agent tool（subagent dispatch）、Bash（task-brief / review-package / git）、Read/Write（report 文件读写）、TodoWrite
**关键设计约束：**
- **文件交接而非上下文粘贴：** brief/report/diff 全部走文件，不进 controller context
- **Progress Ledger：** `.superpowers/sdd/progress.md` 记录每 task 完成状态，防止 compaction 后 controller 丢失状态重复分派
- **Model 选择策略：** 机械实现用 cheap model；集成/判断用 standard model；架构/设计用 most capable model；每 dispatch 必须显式指定 model（superpowers vendor 行为，不适用于 omni_powers；omni_powers 未配置 `OP_*_MODEL` 时不传 `model`，继承主会话模型）
- **不允许并行 dispatch：** 同一 task 的 implementer/reviewer 必须串行（避免冲突）
- **Fix 批量处理：** 最终 review 的 fix 在**一个** fix subagent 中完成（而非每个 finding 一个 fixer）

### 4.3 brainstorming（设计对话驱动）

防止 agent 直接跳入写代码的关键 gate skill。

**完整执行流程：**

1. **Explore project context：** 检查文件、docs、recent commits
2. **Offer visual companion（JIT）：** 第一个真正适合视觉展示的问题出现时才 offer，独立的一条消息
3. **Ask clarifying questions：** 一次一个，prefer 多选，理解目的/约束/成功标准
4. **Propose 2-3 approaches：** 含 trade-offs 和推荐
5. **Present design：** 分 section 展示（架构/组件/数据流/错误处理/测试），每 section 后确认
6. **Write design doc：** 保存到 `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`，git commit
7. **Spec self-review：** placeholder 扫描、内部一致性、scope 检查、歧义检查
8. **User reviews written spec：** 等用户审阅 spec 文件
9. **Transition：** 调用 `writing-plans` skill（不调用其他实现 skill）

**输入：** 用户的想法描述
**输出：** committed spec 文件
**关键设计约束：**
- `<HARD-GATE>`：在任何设计未被批准前，不得调用实现 skill、不得写代码
- 一次只问一个问题，防止用户 overwhelm
- 只转到 `writing-plans`，不转到任何其他 skill
- Visual Companion 是"工具"而非"模式"——按问题决定用浏览器还是终端

### 4.4 test-driven-development（TDD 铁律）

superpowers 的品质之门——也是出现频率最高的 skill。

**完整执行流程：**

1. **RED：** 写一个最小测试展示预期行为
2. **Verify RED（MANDATORY）：** 跑测试确认失败、失败原因正确（不是拼写错误）
3. **GREEN：** 写最少代码让测试通过
4. **Verify GREEN（MANDATORY）：** 跑测试确认通过、其他测试仍通过、输出 pristine
5. **REFACTOR：** 仅 green 后清理，保持 green，不加行为
6. **Repeat**

**关键设计约束（Iron Laws）：**
- `NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST`
- 写 code 前写测试？删掉。重来。
- 12 条 Red Flags + 11 条合理化反驳表
- 测试必须用真实代码（mock 只在不可避免时使用）

**底层能力：** Bash（跑测试）、Write（写测试 + 实现代码）

### 4.5 systematic-debugging（系统化调试）

**完整执行流程（四阶段）：**

1. **Phase 1 - Root Cause Investigation：**
   - 读错误信息仔细（不要跳过 stack trace）
   - 稳定复现（如果不可复现 -> 收集更多数据）
   - 检查近期变更（git diff、commits、配置变更）
   - 在多组件系统中收集证据：用诊断插桩在每个组件边界记录数据进出
   - 向后追踪数据流（见 `root-cause-tracing.md`）
2. **Phase 2 - Pattern Analysis：** 找到类似工作的代码，逐一比较差异
3. **Phase 3 - Hypothesis & Testing：** 形成单一假设，一次改一个变量，验证后继续
4. **Phase 4 - Implementation：** 创建失败测试用例 -> 单一 fix -> 验证 -> 如果 3+ fix 都失败 -> **质疑架构而非继续修**

**关键设计约束：**
- Iron Law: `NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST`
- 3+ fix 失败 = 架构问题信号，不是继续修的信号
- 包含三个配套技术文档：root-cause-tracing、defense-in-depth、condition-based-waiting

## 5. 文件规范

### 目录结构

```
superpowers/
├── .claude-plugin/plugin.json       # Claude Code plugin 声明
├── .codex-plugin/plugin.json       # Codex plugin 声明
├── .cursor-plugin/plugin.json      # Cursor plugin 声明
├── .kimi-plugin/plugin.json        # Kimi Code plugin 声明
├── .opencode/
│   ├── INSTALL.md                  # OpenCode 安装指引
│   └── plugins/superpowers.js      # OpenCode plugin
├── .pi/extensions/superpowers.ts   # Pi extension
├── .agents/plugins/marketplace.json # 开发用 marketplace
├── hooks/
│   ├── hooks.json                  # Claude Code hook 声明
│   ├── hooks-cursor.json           # Cursor hook 声明
│   ├── session-start               # SessionStart hook 脚本
│   ├── session-start-codex          # Codex version
│   └── run-hook.cmd                # 跨平台 wrapper
├── skills/
│   ├── using-superpowers/          # Bootstrap skill
│   ├── brainstorming/              # 设计对话 + visual companion
│   ├── writing-plans/              # 计划编写
│   ├── subagent-driven-development/ # SDD 执行引擎 + scripts/
│   ├── executing-plans/            # 同 session 执行
│   ├── test-driven-development/    # TDD 铁律
│   ├── systematic-debugging/       # 系统化调试 + 三个技术文档
│   ├── verification-before-completion/
│   ├── requesting-code-review/     # + code-reviewer.md 模板
│   ├── receiving-code-review/
│   ├── using-git-worktrees/
│   ├── finishing-a-development-branch/
│   ├── dispatching-parallel-agents/
│   └── writing-skills/             # 创建/修改 skill + 多个参考文档
├── scripts/                        # 项目级 shell 脚本
├── tests/                          # 测试（按 harness 分目录）
├── docs/                           # 文档 + specs + plans
├── assets/                         # 图标
├── CLAUDE.md                       # 贡献者指南（AGENTS.md symlink）
├── README.md                       # 用户文档
├── RELEASE-NOTES.md                # 发布日志
├── package.json                    # npm 元数据 + Pi 配置
└── LICENSE                         # MIT
```

### 命名约定

- **Skill 目录名：** kebab-case（如 `subagent-driven-development`、`writing-plans`）
- **Skill 文件名：** 一致为 `SKILL.md`（大写）
- **Skill frontmatter name：** 与目录名相同
- **Skill 在代码中的引用：** `superpowers:<skill-name>` 格式（空格变连字符）
- **脚本文件：** 无扩展名（Unix），`.cmd` 为 Windows wrapper，`.sh` 为 shell 脚本
- **文档文件：** `YYYY-MM-DD-<topic>-<type>.md`（如 `2026-06-10-strict-cost-sdd-design.md`）
- **doc 目录：** specs 放 `docs/superpowers/specs/`，plans 放 `docs/superpowers/plans/`

### frontmatter / metadata schema

SKILL.md 文件使用 YAML frontmatter：

```yaml
---
name: skill-name
description: "触发条件描述——用于 agent 判断是否匹配"
---
```

只有两个字段：`name` 和 `description`。`description` 中的文字是 agent 做 match 判断的核心依据——它不是一个"说明"，而是**触发条件**。

plugin.json 使用标准 JSON：

```json
{
  "name": "superpowers",
  "version": "6.1.0",
  "description": "...",
  "author": { "name": "...", "email": "..." },
  "homepage": "...",
  "repository": "...",
  "license": "MIT",
  "keywords": [...],
  "skills": "./skills/"
}
```

## 6. SessionStart 注入

### 注入了什么内容

SessionStart hook 在 `startup|clear|compact` 事件时将 `/skills/using-superpowers/SKILL.md` 去掉 frontmatter 后的**全部内容**注入到 session context。内容包括：

1. `<SUBAGENT-STOP>` 标记（告知 subagent 忽略此 skill）
2. `<EXTREMELY-IMPORTANT>` 块：强制 agent 在任何 1% 概率 skill 适用的场景都 **必须** invoke skill
3. The Rule：**在响应或动作之前先 invoke 相关 skill**，包括澄清问题、探索代码、查看文件
4. Skill Priority：process skills 优先于 implementation skills
5. Red Flags 表：12 条自欺欺人的思维模式及对应真相
6. Platform Adaptation：各 harness 的参考文件路径

### 预估 context 消耗量

`using-superpowers/SKILL.md` 全文约 **62 行 / ~2KB**。加上 JSON wrapping 和转义开销，实际注入到 agent context 的量约为 **2.5KB ~ 3KB**（约 600-800 tokens）。

由于在每次 `startup|clear|compact` 都注入，对于一个经过多次 compaction 的长时间 session，这部分 context 会重复出现，但内容完全相同，不影响 agent 推理能力。

## 7. 状态管理

### Progress Ledger（SDD 专用）

- **位置：** `<repo-root>/.superpowers/sdd/progress.md`
- **格式：** 每 task 完成时追加一行 `Task N: complete (commits <base7>..<head7>, review clean)`
- **目的：** 解决 conversation compaction 后 controller 丢失状态的问题。Ledger 中的 task 标记为 complete 时不重新分派
- **恢复：** `cat "$(git rev-parse --show-toplevel)/.superpowers/sdd/progress.md"`；如被 `git clean -fdx` 破坏，从 `git log` 恢复
- **gitignore：** `.superpowers/sdd/.gitignore` 含 `*`，整个目录不被追踪

### SDD Workspace

- **位置：** `.superpowers/sdd/`（worktree 级别，每个 worktree 独立）
- **内容：** task-brief 文件、implementer report 文件、review-package diff 文件、progress ledger
- **生命周期：** 临时 artifact，worktree 删除时一并消失

### Memory / Checkpoint / 持久化

- **无持久化 database：** 不写 SQLite、不写 JSON state file
- **无 checkpoint 机制：** 无保存/恢复会话状态的系统
- **依赖 git：** commits 本身就是持久化——ledger 中的 commit SHA 是"发生了什么"的最终真相
- **Compaction 容忍：** 仅 SDD 的 progress ledger 提供 compaction 恢复能力；其他 skill 依赖 agent 的当前 context（或 skill 自己说"先读 plan"）

## 8. 编排模式

### Leader-Worker（核心模式）

- **Leader（controller）：** 用户会话中的 agent，读 plan、创建 task brief、分派 subagent、处理 reviewer 结果、维护 ledger
- **Worker（implementer）：** 被 dispatch 的 `general-purpose` subagent，收到一个 task brief 文件 + report 文件路径 + context，独立工作
- **Reviewer（gate）：** 被 dispatch 的 `general-purpose` subagent，收到 brief + report + diff package，只读检查，返回双 verdict

### Pipeline（skills 链）

```
brainstorming -> writing-plans -> using-git-worktrees -> subagent-driven-development -> finishing-a-development-branch
                    ^                                                                       |
                    |_________________________ requesting-code-review <_____________________|
```

### 多 Agent 并行（特殊情况）

`dispatching-parallel-agents` skill 在满足条件时可并行 dispatch 多个 agent：
- 前提：2+ 独立问题域（不同测试文件、不同子系统）
- 方式：同一 message 中 dispatch 多个 `Agent` tool call

### 无 DAG/复杂编排

superpowers 的编排是**线性的 pipeline + leader-worker**，不涉及 DAG、event-driven、或持久化 workflow engine。复杂度来源于 skill 指令的详尽程度（红牌表、合理化反驳表、铁律声明）而非技术架构。

---

> 分析完成时间: 2026-07-02。source: `/home/karon/github_repo/superpowers` v6.1.0。文件数 113 个，12 个 skills，10+ harness 支持。
