# everything-claude-code

## 1. 概览

### 一句话定位

Everything Claude Code (ECC) 是一个 **Agent Harness Operating System** -- 面向 AI 编码助手的可复用工具集，为 Claude Code、Codex、Cursor、OpenCode、Gemini、Zed 等多个 agent harness 提供统一的生产级 agent、skill、hook、rule、MCP 配置和工作流编排层。

### 设计哲学 / 解决什么问题

核心设计哲学来自 SOUL.md 和 AGENTS.md:

1. **Agent-First** -- 尽早将工作路由到合适的 specialist agent，而非让通用 agent 做所有事
2. **Test-Driven** -- 写或刷新测试之后再信任实现改动
3. **Security-First** -- 验证输入、保护密钥、保持安全默认
4. **Immutability** -- 优先显式状态转换而非 mutation
5. **Plan Before Execute** -- 复杂改动分解为有意的阶段

解决的核心问题：AI 编码助手缺乏标准化的工作流、质量保证和安全护栏。ECC 将真实世界中经过 10+ 个月高强度日常使用的 agent 配置、skill、hook 打包为可安装的 harness 插件。

### 成熟度

- **Star 数**: 211.9K+
- **Fork 数**: 32.5K+
- **贡献者**: 230+
- **npm 包**: `ecc-universal` v2.0.0, `ecc-agentshield`
- **版本**: 从 v1.2.0 (2026-02) 到 v2.0.0 (2026-06)，迭代约 10 个大版本
- **提交频率**: 极其活跃，每周多次发布
- **文档完整度**: 极高。三个 Guide（Shortform/Longform/Security）、README 88KB、多语言翻译、CHANGELOG、TROUBLESHOOTING
- **测试**: 997+ internal tests, CI validation of agents/commands/rules/skills/hooks schema

规模概览:
| 组件 | 数量 |
|------|------|
| 自定义 Agents | 67 |
| Skills | 277 |
| Commands（slash commands） | 92 |
| Hooks 脚本 | 48 |
| MCP Server 配置 | 20+ |
| 语言规则包 | 16 (common + 15 语言/框架) |
| 支持的 harness 目标 | 12 |

---

## 2. 安装机制

### install.sh / install.ps1 / npx ecc-install

ECC 支持三种安装入口，底层共享同一套 Node.js 安装运行时:

1. `install.sh` -- Unix shell wrapper, 解析 legacy 语言参数后 delegate 到 `scripts/install-apply.js`
2. `install.ps1` -- Windows PowerShell wrapper
3. `npx ecc-install` -- npm 包直接调用

安装脚本本身只是一个 thin wrapper，核心逻辑在 Node.js 中:

```
install.sh -> scripts/install-apply.js
           -> scripts/lib/install/runtime.js  (createInstallPlanFromRequest)
           -> scripts/lib/install-executor.js  (applyInstallPlan)
```

### 安装模式

支持多种安装模式:

1. **Legacy 语言模式** -- `./install.sh typescript python` 按语言安装 rules
2. **Profile 模式** -- `./install.sh --profile developer` 按预设组合安装
3. **Module 模式** -- `./install.sh --modules hooks-runtime,agents-core`
4. **Skill 模式** -- `./install.sh --skills continuous-learning-v2`
5. **Locale 模式** -- `./install.sh --locale zh-CN` 安装翻译文档
6. **Config 模式** -- `./install.sh --config ecc-install.json` 从配置文件驱动

### 安装 Profile

从 `manifests/install-profiles.json` 定义 8 个预设:

| Profile | 模块 | 说明 |
|---------|------|------|
| minimal | rules-core, agents-core, commands-core, platform-configs, workflow-quality | 低 context，无 hooks |
| opencode | commands-core, platform-configs, workflow-quality | OpenCode 默认 |
| core | minimal + hooks-runtime | 基线 |
| developer | core + framework-language, database, orchestration | 默认工程 profile |
| security | core + security | 安全侧重 |
| research | core + research-apis + business-content + social-distribution | 研究/内容 |
| full | 全部模块 | 完整安装 |

### 模块系统

`manifests/install-modules.json` 定义约 25 个模块，每个模块包含:
- `id` -- 唯一标识
- `kind` -- agents / commands / skills / hooks / rules / platform
- `paths` -- 需要复制的文件路径
- `targets` -- 支持的 harness 目标
- `dependencies` -- 依赖的模块
- `cost` -- light/medium/heavy (context 消耗分级)
- `stability` -- stable/experimental

### 改了哪些配置文件

安装到 `~/.claude/` (user-level) 或 `./.claude/` (project-level) 时:

- **CLAUDE.md** -- 不直接修改，但安装的 rules/skills 会注入到 system prompt
- **settings.json** -- hooks 配置注入到 `~/.claude/settings.json` (通过 hooks/hooks.json)
- **rules/** -- 复制到 `~/.claude/rules/ecc/` (使用 ECC 专用命名空间)
- **skills/** -- 复制到 `~/.claude/skills/ecc/`
- **commands/** -- 复制到 `~/.claude/commands/`
- **agents/** -- 复制到 `~/.claude/agents/`
- **.cursor/** -- Cursor 专用配置
- **.codex/** -- Codex CLI 配置
- **.gemini/** -- Gemini CLI 配置

### Symlink 策略

不使用 symlink。所有安装都是**文件复制 (copy)**。安装状态记录在 SQLite state store 或 JSON install-state 文件中，用于跟踪已安装内容和支持增量更新/卸载。

### 插件市场安装

ECC 也可作为 Claude Code plugin 通过 `/plugin marketplace add` + `/plugin install ecc@ecc` 安装:
- 使用 `.claude-plugin/plugin.json` 和 `.claude-plugin/marketplace.json`
- 插件路径下 skills/commands 自动加载
- **但是 rules 不能由 plugin 自动分发**，需要手动复制

---

## 3. 提供的工具全景

### 3.1 Skills / Slash Commands（277 个）

Skills 位于 `skills/` 目录，每个 skill 一个子目录，包含 `SKILL.md` + 可选 `references/` + 可选 `agents/`。

分类概览:

**开发工作流 (15+)**
- `tdd-workflow` -- TDD 强制流程
- `plan` -- 实施规划
- `code-review` -- 代码审查
- `feature-dev` -- 功能开发
- `refactor-clean` -- 重构清理
- `verification-loop` -- 验证循环
- `diagnosing-bugs` -- Bug 诊断

**编程语言 (50+)**
- `python-patterns / python-testing`
- `golang-patterns / golang-testing`
- `react-patterns / react-testing`
- `rust-patterns / rust-testing`
- `kotlin-patterns / kotlin-testing`
- `swiftui-patterns / swift-concurrency-6-2`
- `cpp-coding-standards / cpp-testing`
- `dart-flutter-patterns`
- `laravel-patterns / laravel-security / laravel-tdd`
- `nestjs-patterns`
- 等 15+ 语言/框架

**安全 (8+)**
- `security-review` -- 安全审查
- `security-scan` -- AgentShield 扫描
- `hipaa-compliance`
- `defi-amm-security`
- `llm-trading-agent-security`
- `security-bounty-hunter`

**Agent 工程 (10+)**
- `agent-architecture-audit`
- `agent-harness-construction`
- `agent-introspection-debugging`
- `agent-sort`
- `agentic-engineering`
- `agentic-os`
- `autonomous-loops`
- `continuous-learning / continuous-learning-v2`

**前端/设计 (10+)**
- `frontend-design`
- `frontend-patterns`
- `frontend-a11y`
- `liquid-glass-design` -- iOS 26 Liquid Glass
- `motion-ui / motion-foundations / motion-advanced`
- `ui-demo / ui-to-vue`
- `design-system`

**数据库 (5+)**
- `postgres-patterns`
- `mysql-patterns`
- `redis-patterns`
- `clickhouse-io`
- `database-migrations`

**运维/基础设施 (10+)**
- `kubernetes-patterns`
- `docker-patterns`
- `deployment-patterns`
- `cloudflare:*` -- Workers, Durable Objects, WAF 等
- `homelab-*` -- 家庭网络架设系列
- `pm2`

**商业/内容 (10+)**
- `article-writing`
- `content-engine`
- `market-research`
- `marketing-campaign`
- `brand-voice`
- `investor-materials`
- `social-publisher`
- `seo`

**预测市场 (6+)**
- `ito-market-intelligence`
- `ito-basket-compare`
- `ito-trade-planner`
- `prediction-market-oracle-research`
- `prediction-market-risk-review`

**其他专业领域**
- `healthcare-cdss-patterns / healthcare-emr-patterns`
- `logistics-exception-management`
- `customs-trade-compliance`
- `customer-billing-ops`
- `energy-procurement`
- `carrier-relationship-management`
- `visa-doc-translate`

### 3.2 Hooks（48 个脚本）

所有 hooks 脚本位于 `scripts/hooks/`，主要 hook 类型:

**SessionStart**
- `session-start-bootstrap.js` -- 启动时加载历史 context、检测项目状态、注入 instincts/learned skills
- 非阻塞（不阻止会话启动）

**PreToolUse**
- `pre-bash-dispatcher.js` -- Bash 工具前置检查（commit 质量、tmux 提醒、dev server 阻止、GateGuard）
- `observe-runner.js` -- 记录工具意图用于持续学习
- `block-no-verify.js` -- 阻止 `--no-verify` 标志
- `check-hook-enabled.js` -- 运行时 hook 开关
- `config-protection.js` -- 保护关键配置文件

**PostToolUse**
- `post-bash-dispatcher.js` -- Bash 后置处理（build complete、PR created、command log）
- `post-edit-format.js` -- 编辑后自动格式化
- `post-edit-typecheck.js` -- 编辑后类型检查
- `post-edit-console-warn.js` -- console.log 检查
- `observe-runner.js` -- 记录工具结果用于持续学习
- `session-activity-tracker.js` -- 记录 session 活动到 metrics
- `ecc-context-monitor.js` -- 上下文窗口压力监控
- `ecc-metrics-bridge.js` -- 成本/指标桥接

**PreCompact**
- `pre-compact.js` -- 压缩前持久化 session 状态

**Stop / SessionEnd**
- `session-end.js` -- 会话结束时持久化摘要
- `stop-format-typecheck.js` -- 停止时格式化+类型检查
- `evaluate-session.js` -- 会话评估

**其他**
- `quality-gate.js` -- 质量门控
- `gateguard-fact-force.js` -- GateGuard fact enforcement
- `desktop-notify.js` -- 桌面通知
- `ecc-statusline.js` -- 状态行输出
- `cost-tracker.js` -- 成本跟踪
- `governance-capture.js` -- 治理事件捕获
- `insaits-security-monitor.py` -- InSAITS 安全监控
- `mcp-health-check.js` -- MCP 健康检查
- `suggest-compact.js` -- 建议 compact

### Hook 运行时控制

通过环境变量控制:
- `ECC_HOOK_PROFILE=minimal|standard|strict` -- hook 级别
- `ECC_DISABLED_HOOKS=hook_id1,hook_id2` -- 禁用特定 hook

### 3.3 自定义 Agents（67 个）

位于 `agents/` 目录，每个 agent 一个 `.md` 文件，带 YAML frontmatter:

**开发类**
- `code-reviewer` -- 通用代码审查
- `planner` -- 实施规划
- `architect` -- 软件架构
- `tdd-guide` -- TDD 指导
- `code-explorer` -- 代码库分析
- `code-architect` -- 功能架构设计
- `code-simplifier` -- 代码简化
- `build-error-resolver` -- 构建错误修复
- `doc-updater` -- 文档更新
- `refactor-cleaner` -- 死代码清理

**语言专项审查**
- `typescript-reviewer`, `python-reviewer`, `go-reviewer`, `rust-reviewer`
- `java-reviewer`, `kotlin-reviewer`, `swift-reviewer`, `flutter-reviewer`
- `cpp-reviewer`, `csharp-reviewer`, `fsharp-reviewer`, `php-reviewer`
- `react-reviewer`, `vue-reviewer`, `django-reviewer`, `fastapi-reviewer`
- `laravel-reviewer`, `angular-reviewer`, `harmonyos-app-resolver`

**语言专项构建修复**
- `react-build-resolver`, `java-build-resolver`, `kotlin-build-resolver`
- `rust-build-resolver`, `swift-build-resolver`, `go-build-resolver`
- `cpp-build-resolver`, `dart-build-resolver`, `django-build-resolver`
- `pytorch-build-resolver`

**安全/质量**
- `security-reviewer` -- 安全漏洞检测
- `silent-failure-hunter` -- 静默失败检测
- `comment-analyzer` -- 注释质量分析
- `pr-test-analyzer` -- PR 测试覆盖分析
- `type-design-analyzer` -- 类型设计分析

**运维/编排**
- `e2e-runner` -- E2E 测试
- `harness-optimizer` -- harness 配置优化
- `loop-operator` -- 自治循环监控
- `performance-optimizer` -- 性能优化

**专业领域**
- `database-reviewer` -- PostgreSQL 数据库
- `mle-reviewer` -- 机器学习工程
- `healthcare-reviewer` -- 医疗代码审查
- `network-architect / network-config-reviewer / network-troubleshooter`
- `homelab-architect`
- `seo-specialist`
- `marketing-agent`
- `spec-miner` -- 从代码提取 spec
- `gan-planner / gan-generator / gan-evaluator` -- GAN harness 三角色
- `opensource-forker / opensource-sanitizer / opensource-packager`

### 3.4 CLI 工具 / 可执行脚本

主入口: `scripts/ecc.js` (可通过 `npx ecc` 调用)

```
ecc install          # 选择性安装
ecc plan             # 检查安装计划
ecc catalog          # 查看 profile/component
ecc consult          # 自然语言推荐组件
ecc control-pane     # ECC2 控制面板
ecc list-installed   # 查看已安装内容
ecc doctor           # 诊断缺失/漂移文件
ecc repair           # 修复漂移文件
ecc auto-update      # 自动更新
ecc status           # 查询状态 (SQLite store)
ecc sessions         # 会话管理
ecc session-inspect  # 会话快照
ecc work-items       # 工作项跟踪
ecc loop-status      # 循环状态
ecc uninstall        # 卸载
ecc platform-audit   # GitHub 队列/路线图/安全审计
ecc security-ioc-scan # 供应链 IOC 扫描
```

其他独立脚本:
- `scripts/harness-audit.js` -- harness 审计评分
- `scripts/skills-health.js` -- skill 健康仪表板
- `scripts/orchestrate-worktrees.js` -- git worktree 编排
- `scripts/claw.js` -- NanoClaw 会话管理
- `scripts/control-pane.js` -- Web 控制面板
- `scripts/dashboard-web.js` -- Web 仪表板
- `scripts/sessions-cli.js` -- 会话 CLI
- `scripts/github-coordination.js` -- GitHub 协调
- `scripts/proximity-tick.js` -- agent 邻近度计算
- `scripts/consult.js` -- 自然语言安装顾问

### 3.5 MCP Servers（20+）

配置文件: `mcp-configs/mcp-servers.json`

| MCP Server | 用途 |
|-----------|------|
| nexus | 本地成本/隐私代理，路由到最便宜模型 |
| jira | Jira issue 管理 |
| github | GitHub PR/Issue/Repo 操作 |
| firecrawl | Web 爬取抓取 |
| supabase | Supabase 数据库 |
| memory | 跨会话持久记忆 |
| omega-memory | 语义搜索+知识图谱记忆 |
| longhand | 无损 Claude Code 会话历史 |
| sequential-thinking | 思维链推理 |
| vercel | Vercel 部署 |
| railway | Railway 部署 |
| cloudflare-docs / cloudflare-workers-builds / cloudflare-workers-bindings | Cloudflare 文档/构建/绑定 |
| context7 | 最新框架文档 |
| memxus | 通用跨 harness 持久记忆 |
| filesystem | 文件系统操作 |
| chrome-devtools | Chrome DevTools |
| token-optimizer | Token 优化 (95%+ 压缩) |
| confluence | Confluence 集成 |
| evalview | AI agent 回归测试 |
| squish | 本地持久记忆 |
| laraplugins | Laravel 插件发现 |
| claude-devfleet | 多 agent worktree 编排 |

### 3.6 模板 / 脚手架

- `scaffolds/` -- 脚手架模板
- `contexts/` -- 上下文模式定义 (dev.md, research.md, review.md)
- `examples/` -- 使用示例
- `docs_template/` -- 文档模板

### 3.7 Rules（16 个语言包）

位于 `rules/` 目录，分层架构:

```
rules/
├── common/        # 通用规则（必须安装）
│   ├── agents.md, code-review.md, coding-style.md
│   ├── development-workflow.md, git-workflow.md
│   ├── hooks.md, patterns.md, performance.md
│   ├── security.md, testing.md
├── typescript/    # TS/JS 专项
├── angular/       # Angular 专项
├── vue/           # Vue 3
├── web/           # Web 通用
├── react-native/  # React Native/Expo
├── python/
├── golang/
├── swift/
├── php/
├── ruby/
├── cpp/
├── csharp/
├── dart/
├── fsharp/
├── java/
├── kotlin/
├── rust/
└── arkts/         # HarmonyOS
```

每个语言包包含: coding-style.md, testing.md, patterns.md, hooks.md, security.md

### 3.8 其他

- **ECC2** (`ecc2/`) -- Rust TUI 控制面板，使用 ratatui + rusqlite + git2
- **src/llm/** -- Python LLM 抽象层，支持 Claude/OpenAI/Ollama/Atlas/AstraFlow
- **ecc_dashboard.py** -- Python Tkinter 桌面仪表板
- **integrations/aura/** -- AURA Open Protocol 信任检查适配器
- **config/** -- GitHub 协调和项目栈映射配置
- **legacy-command-shims/** -- 旧版命令兼容 shim
- **.agents/** -- 跨 harness (OpenAI/Codex) 的 agent 和 skill 副本
- **manifests/** -- 安装清单 (profiles, modules, components)

---

## 4. 核心工具详解

### 4.1 SessionStart Hook（记忆持久化系统）

**用途**: 每次新会话启动时自动注入历史上下文，实现跨会话记忆连续。

**执行流程**:

1. Claude Code 触发 SessionStart 事件
2. `hooks/hooks.json` 中配置的 `session:start` hook 启动
3. 调用 `scripts/hooks/session-start-bootstrap.js`:
   a. 从 stdin 读取 Claude Code 传入的原始 JSON event
   b. 解析 ECC plugin root (优先级: `CLAUDE_PLUGIN_ROOT` env → `~/.claude` → plugin 路径 → 版本化缓存)
   c. delegate 到 `scripts/hooks/run-with-flags.js` 检查 hook profile 启用状态
   d. 调用 `scripts/hooks/session-start.js`:
      - 读取上一次 session 的 summary（最多 8000 字符）
      - 加载 learned skills（最多 6 个，每个摘要 220 字符）
      - 加载 instincts（最多 6 个，confidence >= 0.7）
      - 检测项目类型
      - 解析 package manager
      - 通过 stdout 注入 contextual preamble 到 Claude Code 会话
      - 非阻塞，注入失败不影响会话启动

**输入**: Claude Code SessionStart event (JSON via stdin)
**输出**: 通过 stdout 注入的上下文文本（session summary + learned skills + instincts + project info）

**调用能力**: Node.js fs, path, child_process (spawnSync)

**关键设计约束**:
- 非阻塞（`"blocking": false`）
- 注入内容上限 8000 字符，防止 context 爆炸
- Hook profile 运行时控制（`ECC_HOOK_PROFILE`）
- PostToolUse context monitor 在 35% warning / 25% critical 阈值告警

### 4.2 Selective Install System（选择性安装系统）

**用途**: 允许用户按 profile/module/component 粒度选择性安装 ECC 组件，而非全量安装。

**执行流程**:

1. 用户运行 `./install.sh --profile developer --target claude`
2. `install.sh` → `scripts/install-apply.js`
3. `parseInstallArgs()` 解析命令行参数
4. `normalizeInstallRequest()` 标准化安装请求
5. `createInstallPlanFromRequest()`:
   a. 根据 `--profile` 查找 `manifests/install-profiles.json`
   b. 展开 profile 中的所有 modules, 再展开 `manifests/install-components.json` 中的 components
   c. 处理 `--with` / `--without` 组件过滤
   d. 根据 `--target` 选择 target adapter (claude-home / claude-project / cursor-project / codex-home / gemini-project 等 12 个 adapter)
   e. 每个 adapter 定义: install root 路径、文件映射规则、install-state 存储路径
   f. 生成文件操作计划 (源路径 → 目标路径映射)
6. `applyInstallPlan()`:
   a. 遍历所有文件操作
   b. 创建目标目录
   c. 复制文件
   d. 写入 install-state (SQLite 或 JSON)

**输入**: CLI args (`--profile`, `--target`, `--modules`, `--skills`, `--with`, `--without`, `--config`)
**输出**: 文件复制到目标位置 + install-state 记录 + JSON plan (dry-run 模式)

**关键设计决策**:
- 使用 ECC 专用命名空间 (`~/.claude/rules/ecc/`, `~/.claude/skills/ecc/`) 避免污染
- Install-state 支持增量更新和卸载
- 12 个 target adapter 覆盖不同 harness 的不同文件布局

### 4.3 Agent Orchestration（Agent 编排系统）

**用途**: 定义何时自动触发哪个 specialist agent，形成 leader-worker 编排模式。

**执行流程** (以 code-reviewer 为例):

1. Claude Code 检测到代码变更
2. AGENTS.md 中的编排规则指定: "Code just written/modified → **code-reviewer**"
3. code-reviewer agent 被以 Agent tool 调用
4. Agent prompt (agents/code-reviewer.md) 中包含:
   - 角色定义: "Expert code review specialist"
   - 工具权限: Read, Grep, Glob, Bash
   - 审查标准: security, quality, maintainability
   - 输出格式: review_*.md with PASS/FAIL verdict
5. Agent 执行审查流程:
   a. 读取 git diff
   b. 安全 checks 优先
   c. 代码质量 checks
   d. 输出 verdict + findings

**输入**: 代码变更 (自动检测)
**输出**: 审查报告 (verdict + findings)

**编排规则表**:

| 触发条件 | Agent |
|----------|-------|
| 复杂功能需求 | planner |
| 代码刚写/修改 | code-reviewer |
| Bug fix 或新功能 | tdd-guide |
| 架构决策 | architect |
| 安全敏感代码 | security-reviewer |
| 构建失败 | build-error-resolver |
| 性能问题 | performance-optimizer |
| Brownfield 项目 | spec-miner |

**关键设计**:
- 所有 agent 共享 YAML frontmatter: `name`, `description`, `tools`, `model`
- Agent 目录同时包含常规开发 agent + 语言专项 reviewer + 语言专项 build-resolver

### 4.4 Continuous Learning System（持续学习系统）

**用途**: 从会话中自动提取模式，生成可复用的 skill 和 instinct。

**执行流程**:

1. **观测阶段**:
   - PreToolUse hook (`observe-runner.js`) 记录工具调用意图
   - PostToolUse hook (`observe-runner.js`) 记录工具调用结果
   - 数据写入 session events

2. **提取阶段**:
   - PreCompact hook (`pre-compact.js`) 在压缩前持久化 session 状态
   - SessionEnd hook (`session-end.js`) 生成 session 摘要
   - `/learn` 命令从会话历史中提取模式
   - `/skill-create` 从 git history 生成 skill

3. **应用阶段**:
   - SessionStart hook 加载 learned skills (上次学习到的)
   - 加载 instincts (confidence >= 0.7 的行为模式)
   - Instincts 支持 import/export/evolve

**输入**: 会话工具调用记录
**输出**: learned skills, instincts (带 confidence score)

**关键设计**:
- Instinct confidence threshold = 0.7
- 最多注入 6 个 learned skills + 6 个 instincts 到新会话
- Instincts 存储在 `~/.claude/homunculus/instincts/`

### 4.5 ECC 2.0 Control Plane（控制面板）

**用途**: Rust TUI 控制面板，提供 session/worktree 编排的本地操作界面。

**执行流程**:

1. `cd ecc2 && cargo build --release`
2. `ecc control-pane` 启动 TUI
3. TUI 功能:
   - Dashboard: 概览 session 状态
   - Sessions: 列出/管理 session
   - Status: 状态查询 (SQLite store)
   - Worktrees: git worktree 生命周期管理
   - Work items: Linear/GitHub 工作项跟踪
   - Proximity: agent 邻近度可视化

**技术栈**: Rust + ratatui + crossterm + rusqlite + git2 + tokio

**输入**: CLI 命令
**输出**: TUI 界面 + SQLite 状态

**关键设计**:
- 本地优先，不依赖云服务
- SQLite 状态存储
- 与 Python dashboard (`ecc_dashboard.py`) 互补

---

## 5. 文件规范

### 目录结构

```
everything-claude-code/
├── agents/               # 67 个自定义 agent .md
├── skills/               # 277 个 skill 子目录
│   └── <skill-name>/
│       ├── SKILL.md      #   主 skill 定义 (YAML frontmatter)
│       ├── references/   #   参考资料 (可选)
│       └── agents/       #   独占 agent (可选)
├── commands/             # 92 个 slash command .md (legacy, 未来 skill 化)
├── hooks/                # Hook 定义
│   ├── hooks.json        #   生产 hook graph (354 行)
│   └── memory-persistence/
│       └── hooks.json    #   参考 hook 定义
├── rules/                # 16 个语言/框架规则包
│   ├── common/           #   通用规则
│   └── <language>/       #   语言专项规则
│       ├── coding-style.md
│       ├── testing.md
│       ├── patterns.md
│       ├── hooks.md
│       └── security.md
├── scripts/              # 所有运行时逻辑
│   ├── hooks/            #   48 个 hook 实现脚本
│   ├── lib/              #   共享库
│   │   ├── install-targets/  # 12 个 harness target adapter
│   │   ├── agent-proximity/  # Agent 邻近度计算
│   │   ├── control-pane/     # 控制面板后端
│   │   └── github-coordination/ # GitHub 协调
│   ├── ci/               #   CI 验证脚本
│   └── ecc.js            #   主 CLI 入口
├── config/               # 配置文件
├── contexts/             # 上下文模式 (dev/research/review)
├── manifest/             # 安装清单
├── mcp-configs/          # MCP server 配置
├── src/llm/              # Python LLM 抽象层
├── ecc2/                 # Rust TUI 控制面板
├── schemas/              # JSON Schema 定义
├── scaffolds/            # 脚手架模板
├── tests/                # 测试
├── docs/                 # 文档
├── plugins/              # 跨 harness 插件
├── integrations/         # 第三方集成
├── .claude/              # ECC 自身的 Claude 配置
│   ├── rules/
│   ├── skills/
│   ├── commands/
│   └── team/
├── .claude-plugin/       # Claude Code plugin 清单
├── .codex-plugin/        # Codex 插件
├── .cursor/              # Cursor 配置
├── .gemini/              # Gemini 配置
├── .opencode/            # OpenCode 配置
├── .qwen/                # Qwen 配置
├── .zed/                 # Zed 配置
└── .agents/              # 跨 harness agent/skill 副本
```

### 命名约定

- **文件/目录**: `kebab-case` (skills `tdd-workflow/`, agents `code-reviewer.md`)
- **Skill 目录**: `skills/<kebab-case-name>/SKILL.md`
- **Agent 文件**: `agents/<kebab-case-name>.md`
- **Command 文件**: `commands/<kebab-case-name>.md`
- **Rule 文件**: 固定名称 `coding-style.md`, `testing.md`, 等
- **Hook 脚本**: `scripts/hooks/<kebab-case-purpose>.js`
- **变量**: `snake_case` (在 CLAUDE.md 中规定)
- **组件**: `PascalCase`

### Frontmatter / Metadata Schema

**Agent frontmatter** (agents/*.md):
```yaml
---
name: code-reviewer
description: Expert code review specialist...
tools: Read, Grep, Glob, Bash    # 可用工具白名单
model: sonnet                     # 推荐模型 (可选)
---
```

**Command frontmatter** (commands/*.md):
```yaml
---
description: Restate requirements, assess risks...
argument-hint: "[feature description | path/to/*.prd.md]"
---
```

**Skill frontmatter** (skills/*/SKILL.md):
```yaml
---
name: tdd-workflow
description: Use this skill when...
argument-hint: <path/to/*.plan.md>
metadata:
  origin: ECC          # ECC 或 community
---
```

---

## 6. SessionStart 注入

### 注入内容

每次新会话启动时，`session-start.js` 通过 stdout 注入以下内容到 Claude Code 的 system prompt:

1. **上次会话摘要** -- 最近的 session summary（最多 8000 字符）
2. **Learned skills** -- 从之前会话学习的可复用 skill（最多 6 个，每个摘要 <= 220 字符）
3. **Instincts** -- 高置信度行为模式（最多 6 个，confidence >= 0.7）
4. **项目状态检测** -- 项目类型、package manager、Git 状态
5. **Session aliases** -- 会话别名映射

### Context 消耗估算

- Session summary: 最多 8000 字符 (~2000 tokens)
- Learned skills: 最多 6 x 220 = 1320 字符 (~330 tokens)
- Instincts: 最多 6 个 (~500 tokens)
- 项目检测输出: ~200 tokens
- **总计**: 约 3000-4000 tokens per session

### 注入方式

通过 hook stdout 输出，Claude Code 将 stdout 内容注入到 system prompt 的 preamble 部分（在 CLAUDE.md 之前）。非阻塞 -- 注入失败不影响会话启动。

### 内容示例

```
[Previous session summary]
Project: todo-app (TypeScript + React)
Last activity: 2026-07-01 14:30 UTC
Summary: Implemented user authentication with JWT, wrote tests for login/logout...

[Learned skills]
- react-form-patterns: Use React Hook Form with zod validation...
- api-error-handling: Return consistent error envelope with...

[Active instincts]
- prefer-early-return: confidence 0.85
- extract-utility-function: confidence 0.78
```

---

## 7. 状态管理

### 记忆系统层次

```
Layer 1: Session Memory (内存)
  └── 单次会话内的上下文，Claude Code 原生管理

Layer 2: Session Persistence (SQLite + JSON)
  └── 跨会话持久化
      ├── Session summaries (session-end.js)
      ├── Session events (session-activity-tracker.js)
      ├── ECC2 state store (SQLite, via ecc2 Rust binary)
      └── Install-state (JSON, via install-state.js)

Layer 3: Learned Skills (文件)
  └── 从会话中提取的可复用 skill
      ├── 存储在 ~/.claude/learned-skills/
      └── 通过 /learn 命令或连续学习系统生成

Layer 4: Instincts (YAML)
  └── 行为模式，带 confidence score
      ├── 存储在 ~/.claude/homunculus/instincts/
      ├── 支持 import/export/evolve
      └── 继承自 ECC 的 instincts 注入

Layer 5: External Memory MCPs
  └── 可选的外部持久记忆
      ├── memory (MCP: @modelcontextprotocol/server-memory)
      ├── omega-memory (语义搜索 + 知识图谱)
      ├── longhand (无损会话历史)
      ├── squish (本地 SQLite, 1-20ms recall)
      └── memxus (跨 harness 通用记忆)
```

### 会话数据

- **Session 文件**: `*-session.tmp` 存储在 `~/.claude/sessions/` 或项目 sessions 目录
- **Session lease**: `writeSessionLease()` 确保同一项目不被多个会话同时修改
- **Session retention**: 默认 30 天 (`ECC_SESSION_RETENTION_DAYS`)

### Checkpoint 机制

- `/checkpoint` 命令创建检查点
- `pre-compact.js` hook 在上下文压缩前持久化

### ECC2 State Store

`ecc2/` Rust 项目使用 SQLite 存储:
- sessions 记录
- skill-run health
- install health
- work items (LinkedIn/GitHub/handoff)
- governance events

通过 `ecc status --markdown --write status.md` 导出可移植状态报告。

---

## 8. 编排模式

### 单 Agent 模式

基本模式: 用户 → Claude Code → 执行任务

ECC 增强: 用户 → Claude Code + ECC rules/skills/hooks 注入 → 执行任务
- Rules 提供强制性约束
- Skills 提供领域知识
- Hooks 提供自动化护栏

### Leader-Worker 模式

ECC 的核心编排模式:

```
Leader (Claude Code + ECC system prompt)
    │
    ├─→ worker: planner          (计划阶段)
    ├─→ worker: tdd-guide        (TDD 阶段)
    ├─→ worker: code-reviewer    (审查阶段)
    ├─→ worker: security-reviewer (安全审查)
    └─→ worker: build-error-resolver (构建修复)
```

**自动触发** (无需用户显式请求):
- 代码修改 → code-reviewer
- Bug fix → tdd-guide
- 架构决策 → architect
- 安全代码 → security-reviewer

### Pipeline 模式

完整的功能开发流水线:

```
/plan → /tdd → /code-review → /security-review → /build-fix → /e2e
```

每步有明确的输入/输出契约:
- `/plan` 输出 `.claude/plans/{name}.plan.md`
- `/tdd` 读取 plan → 写测试(RED) → 实现(GREEN) → 重构 → 输出证据报告
- `/code-review` 输出 `review_code.md` (PASS/FAIL verdict)
- `/build-fix` 修复构建错误

### DAG / 并行模式

多 Agent 并行执行，通过 `/multi-*` 命令:

- `/multi-plan` -- 多 agent 并行规划
- `/multi-execute` -- 多 agent 并行执行
- `/multi-backend` / `/multi-frontend` -- 前后端并行
- `/multi-workflow` -- 自定义多 agent 工作流

底层依赖 git worktree 隔离（每个 agent 独立 worktree）。

### GAN Harness 三角色模式

用于自我改进的 harness:
```
GAN Planner → GAN Generator → GAN Evaluator
      ↑                          │
      └──────────────────────────┘
         (feedback loop)
```

### Orchestration 命令系列

专门的工作流编排命令:

- `/orch-add-feature` -- 添加功能编排
- `/orch-build-mvp` -- 构建 MVP 编排
- `/orch-change-feature` -- 修改功能编排
- `/orch-fix-defect` -- 修复缺陷编排
- `/orch-refine-code` -- 优化代码编排

每个 `orch-*` 命令是一个预定义的 multi-step 工作流。

### Session 编排 (tmux + worktree)

`scripts/orchestrate-worktrees.js` 提供基于 tmux + git worktree 的 agent 编排:
- 每个 worker agent 运行在独立的 worktree + tmux pane
- 支持 multi-select agent control
- 支持 lifecycle hooks (create, resume, pause, stop)
- Session adapter 契约 (`docs/SESSION-ADAPTER-CONTRACT.md`) 定义标准化 session snapshot 格式

### 跨 Harness 编排

ECC 不限于单个 harness:

```
                    ┌──────────────────┐
                    │   ECC CLI/TUI    │
                    │  (ecc / ecc2)    │
                    └────────┬─────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
   ┌────▼─────┐      ┌──────▼──────┐      ┌─────▼────┐
   │ Claude   │      │   Codex     │      │  Cursor  │
   │  Code    │      │    CLI      │      │   IDE    │
   └──────────┘      └─────────────┘      └──────────┘
        │                    │                    │
   ┌────▼─────┐      ┌──────▼──────┐      ┌─────▼────┐
   │ .claude  │      │   .codex    │      │ .cursor  │
   │ (config) │      │  (config)   │      │ (config) │
   └──────────┘      └─────────────┘      └──────────┘
```

通过 12 个 install target adapter，相同的 agent/skill/rule 可以部署到不同的 harness 目录结构中。
