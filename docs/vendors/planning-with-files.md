# planning-with-files

## 1. 概览

- **一句话定位**：基于文件系统的持久规划 skill，让 AI 编码 agent 的 plan 在 context 清空、会话崩溃后仍然存续，灵感源自 Manus AI 的 context engineering 实践。
- **设计哲学**：将 agent 的"工作记忆"外化到磁盘上的 Markdown 文件中（`task_plan.md` + `findings.md` + `progress.md`），hook 在每个生命周期事件点自动注入/更新这些文件，使得 agent 即使经历 `/clear` 或崩溃也能恢复完整上下文。核心引用 Manus 的 6 条 Context Engineering 原则（围绕 KV-cache 设计、mask 而非 remove、文件系统即外部记忆等）。
- **成熟度**：极高。版本号 v3.1.3（2026-06-16），支持 17+ IDE/平台（Claude Code、Cursor、Copilot、Gemini CLI、Codex、Kiro、CodeBuddy、OpenCode、Continue、Pi Agent、OpenClaw、Antigravity、Kilocode、AdaL、Factory、Hermes、Mastra Code），含 1 个沙箱运行时（BoxLite），CHANGELOG 从 v1.0.0（2026-01-07）至今有 50+ 个版本迭代，350+ 测试用例。

---

## 2. 安装机制

### 2.1 安装方式（4 种）

1. **Claude Code Plugin（推荐）**：`/plugin marketplace add OthmanAdi/planning-with-files` 然后 `/plugin install planning-with-files@planning-with-files`
2. **手动克隆到 `.claude/plugins/`**：`git clone ... .claude/plugins/planning-with-files`
3. **Skills only 模式**：仅复制 `skills/` 目录到 `~/.claude/skills/`
4. **仅当前新项目自动注入**：curl 一键提取 skill 文件

### 2.2 改动的配置文件

安装改动取决于 IDE（不同 IDE 有不同的 hook 机制）：

| IDE | 改动 |
|-----|------|
| **Claude Code** | `.claude-plugin/plugin.json` — metadata + 指向 `skills/planning-with-files/SKILL.md` 作为 skill 入口，`commands/` 作为 slash commands |
| **GitHub Copilot** | `.github/hooks/planning-with-files.json` — 定义了 SessionStart、PreToolUse、PostToolUse、AgentStop、ErrorOccurred 五个 hook，指向 `.github/hooks/scripts/*.sh` |
| **Cursor** | `.cursor/hooks.json` — PreToolUse、PostToolUse、Stop、UserPromptSubmit hooks |
| **Gemini CLI** | `.gemini/settings.json` + `.gemini/hooks/*.sh` — before-model、before-tool、after-tool、session-start、session-end |
| **Codex** | `.codex/hooks.json` + `.codex/hooks/*.sh` + `.codex/hooks/*.py` — 最复杂的 hook 适配层，含 Python 适配器 |
| **Hermes** | `.hermes/plugins/planning-with-files/` — 完整 Python 插件，含 plugin.yaml、hooks.py、planning_files.py、tools.py |
| **Pi Agent** | `.pi/skills/planning-with-files/` — npm 包 `@tomxprime/planning-with-files`，含 TypeScript 扩展（attestation.ts、runtime.ts、plan.ts） |
| **其他** | 各自的 `.xxx/skills/planning-with-files/SKILL.md` + 脚本/templates |

### 2.3 Symlink 策略

无 symlink 策略。每个 IDE 适配目录包含完整的独立副本（scripts、templates、references），由维护者用自研同步工具保持 `skills/planning-with-files/`（canonical）与被适配 IDE 子目录的一致（见 `tests/test_canonical_script_sync.py` 等测试）。

---

## 3. 提供的工具全景

### 3.1 Skills / Slash Commands

| 工具 | 用途 | 说明 |
|------|------|------|
| `/planning-with-files:plan` (`/plan`) | 核心 slash command | 触发计划流程：引导 agent 创建/读取 3 个规划文件 |
| `/planning-with-files:start` (`/start`) | 启动命令 | 等同于 `/plan`，legacy 别名 |
| `/planning-with-files:status` (`/status`) | 状态检查 | 显示当前 phase 完成状态 |
| `/plan-attest` | 计划哈希锁定 | 对 `task_plan.md` 做 SHA-256 哈希，锁定后任何篡改都会被 hook 检测并阻断注入 |
| `/plan-goal` | 循环目标 | 与 Claude Code `/goal` 组合：从 plan 提取完成条件（所有 phase 状态 = complete） |
| `/plan-loop` | 循环监控 | 与 Claude Code `/loop` 组合：定时重读 plan、检查完成、写 progress |
| `/pwf` | `/plan` 的短别名 | v3.0.0 加入 |

另外还有多语言变体：`plan-ar.md`（阿拉伯语）、`plan-de.md`（德语）、`plan-es.md`（西班牙语）、`plan-zh.md`（中文）。

### 3.2 Hooks

按 IDE 不同，hook 类型也不同。最完整的 Claude Code/Copilot/Cursor 支持：

| Hook 事件 | 功能 | 核心脚本 |
|-----------|------|---------|
| **SessionStart** | 新会话启动时：检测已有 plan 则做 catchup，无 plan 则注入 SKILL.md 告诉 agent 如何创建 plan | `session-catchup.py` → `init-session.sh` → `inject-plan.sh` |
| **UserPromptSubmit** | 每次用户输入前：重新注入 plan head 到 context，检查 attestation | `inject-plan.sh --context=userprompt` |
| **PreToolUse** | 工具执行前：注入 plan head 的前 30 行，刷新 agent 目标记忆 | `inject-plan.sh --context=pretool` |
| **PostToolUse** | 工具执行后：提醒 agent 更新 `progress.md` 和 phase 状态 | `inject-plan.sh --context=pretool` + 内联提醒文本 |
| **Stop** | Agent 尝试停止时：检查所有 phase 是否完成，未完成则阻止停止并重新提示 | `check-complete.sh`（无 gate）/ `gate-stop.sh` → `check-complete.sh --gate`（gated 模式） |
| **ErrorOccurred** | Copilot 特有：错误发生时自动记录到 `task_plan.md` 的 Errors Encountered 区 | `error-occurred.sh` |
| **PreCompact** | Claude Code 特有：自动压缩前提醒 agent 先把状态写入磁盘 | `inject-plan.sh --context=precompact` |

### 3.3 自定义 Agents

无独立 agent 定义文件。编排模式通过 SKILL.md 中的规则文本驱动 agent 行为（如"2-Action Rule"、"3-Strike Error Protocol"、"5-Question Reboot Test"）。Pi Agent 适配拥有 TypeScript Extension（可视为轻量 agent 行为驱动层）。

### 3.4 CLI 工具 / 可执行脚本

| 脚本 | 用途 |
|------|------|
| `scripts/init-session.sh` | 初始化规划文件（3 种模板：default / analytics / autonomous），支持 3 种模式（legacy / slug / v3 autonomous/gated） |
| `scripts/inject-plan.sh` | **核心注入引擎**：从 v2.43 inline hook 逻辑提取为独立可测试脚本，根据 `.mode` 文件决定 legacy/autonomous/gated 三种注入策略 |
| `scripts/check-complete.sh` | 检查所有 phase 完成状态，支持 `--gate` 参数做 gated 模式决策（5 层 guard 判断是否应阻止 agent 停止） |
| `scripts/resolve-plan-dir.sh` | 解析活动 plan 目录（PLAN_ID env → `.active_plan` → 最新 mtime → legacy 根路径），含 symlink 容器保护 |
| `scripts/session-catchup.py` | 跨会话上下文恢复：扫描 Claude Code sessions 或 OpenCode SQLite DB，找到上次 plan 更新时间，提取缺失的对话内容 |
| `scripts/attest-plan.sh` | SHA-256 哈希锁定 `task_plan.md`，写入 `.attestation` 文件，之后 hook 每次校验 |
| `scripts/gate-stop.sh` | v3 gated 模式 Stop hook 的薄封装，调 `check-complete.sh --gate` |
| `scripts/phase-status.sh` | **v3 相位状态原子写入器**：flock 保护下用 awk 精确替换 `task_plan.md` 中指定 phase 的 `**Status:**` 行 |
| `scripts/set-active-plan.sh` | 设置/查看 `.planning/.active_plan` 指针 |
| `scripts/check-continue.sh` | 检查 Continue IDE 集成文件完整性 |
| `scripts/ledger-append.sh` / `ledger-summary.sh` | v3 运行账本：记录每次 run 的 action，生成摘要 |

所有 shell 脚本均有对应 `.ps1`（PowerShell）版本。

### 3.5 MCP Servers

无。

### 3.6 模板 / 脚手架

| 模板文件 | 用途 |
|---------|------|
| `templates/task_plan.md` | 标准任务计划：Goal、Current Phase、5 阶段（Requirements/Planning/Implementation/Testing/Delivery）、Decisions Made、Errors Encountered |
| `templates/task_plan_autonomous.md` | v3 自动模式计划：新增 Phase coordination fields（`parallel_workers`、`can_start`、`needs`、`can_parallelize`、`assigned_to`）、Run ledger、Gate metadata |
| `templates/findings.md` | 研究发现：Requirements、Research Findings、Technical Decisions、Issues Encountered、Resources、Visual/Browser Findings |
| `templates/progress.md` | 进度日志：按 session 分段记录、Actions Taken、Test Results、Errors、5-Question Reboot Check |
| `templates/loop.md` | `/plan-loop` 的 tick prompt 模板 |
| `templates/analytics_findings.md` | 分析任务专用 findings 模板 |
| `templates/analytics_task_plan.md` | 分析任务专用 task_plan 模板 |

### 3.7 配置文件 / Rules

- **SKILL.md**（skill 主文件）：含 YAML frontmatter（`name`、`description`、`metadata.version`、`allowed-tools`），body 是完整的 agent 行为规范
- **reference.md**：Manus 6 条 Context Engineering 原则的详细阐述
- **examples.md**：4 个使用示例（Research / Bug Fix / Feature Dev / Error Recovery）
- **各 IDE 的 `SKILL.md`**：从 canonical `skills/planning-with-files/SKILL.md` 同步，可能略有差异（如自发现路径模式不同）
- **`AGENTS.md`**：给本 repo 贡献者的 agent 行为规范（commit rules、release checklist、version bump scope）

---

## 4. 核心工具详解

### 4.1 `inject-plan.sh` — 计划注入引擎

**定位**：整个系统的开关枢纽。v2.43 时这些逻辑内联在每个 hook 的命令标量中（14 个 SKILL.md 变体各自复制），v3 提取为独立脚本，由 hook dispatcher 调用。

**三种 context 模式**：
- `--context=userprompt`：默认，注入完整 plan head + progress/ledger 摘要。每 turn 一次。
- `--context=pretool`：注入 plan head 前 30 行，无 progress。每次 tool call 前调用。
- `--context=precompact`：仅注入压缩提醒，不注入 plan body。与 v2 PreCompact 行为完全一致。

**执行流程**：
1. **自发现脚本路径**：通过 `${BASH_SOURCE[0]}` 或候选扫描找到自身的绝对路径（因为 hook 命令标量可能从任意 CWD 调用）
2. **解析 plan 目录**：内联 `resolve-plan-dir.sh` 逻辑（复用同一算法）→ 找到活动 `task_plan.md`
3. **容器边界检查**（安全 A1.3）：realpath 验证 plan 目录真实路径必须在项目根下，防止 symlink 逃逸读取 `/etc/passwd` 之类的文件
4. **读取 `.mode` 文件**：决定三种模式
   - `legacy`（无 `.mode`）：输出与 v2.43 逐字节等价，保证向后兼容
   - `autonomous`：非交互式 agent loop 模式
   - `gated`：autonomous + completion gate
5. **attestation 检查**：
   - v3 模式下必须有 attestation，否则返回 `[planning-with-files] v3 mode requires attested plan`
   - 检查 SHA-256 缓存（`~/.cache/planning-with-files/` 下，避免每次 rehash）
   - gated 模式强制跳过缓存，每次都 rehash
   - 不匹配时输出 `[PLAN TAMPERED — injection blocked]` 并显示期望/实际 hash
6. **按模式输出**：
   - legacy/userprompt：`===BEGIN PLAN DATA===` ... `head -50 task_plan.md` ... `===END PLAN DATA===` + progress tail
   - autonomous/gated/userprompt：nonce delimiter + full plan head + structured ledger summary（而非 raw progress tail）
   - pretool（legacy）：仅 plan head 前 30 行
   - pretool（v3）：跳过注入（strong model 不需要每次 tool call 前重读）
   - precompact：仅提醒文本

**输入**：`--context=userprompt|pretool|precompact`（通过 hook 命令标量传入）
**输出**：stdout，直接注入到 agent 的 model context
**退出码**：始终 0（永不因注入失败而中断 agent loop）

**关键设计决策**：
- 从内联 hook 提取为可测试脚本，解决了 14 个 SKILL.md 变体中的逻辑复制问题
- v3 模式不再在每次 tool call 前注入 plan（降低注入放大的攻击面）
- v3 模式用 structured ledger summary 替代 raw `progress.md` tail（因为 progress.md 不受 attestation 保护）

### 4.2 `init-session.sh` — 会话初始化器

**定位**：创建新 plan 的入口，支持 3 大模式。

**执行流程**：
1. **检测 CLI 参数**，决定三种模式路径：
   - **Legacy 模式**（无参数）：直接在项目根创建 `task_plan.md`、`findings.md`、`progress.md`
   - **Slug 模式**（有项目名或 `--plan-dir`）：在 `.planning/<date>-<slug>/` 下创建隔离目录
   - **v3 opt-in 模式**（`--autonomous` 或 `--gated`）：额外写入 `.mode` 文件 + nonce + 自动 attest
2. **Slug 模式**：
   - 从参数生成 slug（保留 `[a-zA-Z0-9_-]`，其余替换为 `-`）
   - 创建 `.planning/<YYYY-MM-DD>-<slug>/` 目录
   - 写入 `.planning/.active_plan` 指针
3. **复制模板**：
   - 默认用 `templates/task_plan.md`、`templates/findings.md`、`templates/progress.md`
   - `--template analytics` 用分析专用模板
   - v3 模式用 `templates/task_plan_autonomous.md`
4. **v3 模式副作用**（`apply_v3_mode()`）：
   - 写入 `.mode` 文件（内容为 `autonomous` 或 `autonomous gate`）
   - 写入 `.nonce` 文件（随机 8 字符十六进制）
   - 重置 `.stop_blocks` 计数器为 0
   - 清除旧的 gate ledger（`ledger-*.jsonl`）
   - 自动调用 `attest-plan.sh` 锁定 plan

**输入**：可选的 plan 名称、`--plan-dir`、`--template TYPE`、`--autonomous`、`--gated`
**输出**：创建的文件列表 + 路径信息（stdout）
**退出码**：0 成功，1 错误

### 4.3 `check-complete.sh` — 完成检查 + Gated 决策引擎

**定位**：v2.43 的完成状态报告 + v3 gated 模式的"终止预言机"。

**两种调用模式**：
- 无 `--gate`：v2.43 advisory echo（始终成功，仅报告状态）
- 有 `--gate`：5 层 guard 决定是否阻止 agent 停止

**Gated 模式执行流程（5 层 guard，AND 逻辑，全部满足才 block）**：
1. **Guard 1 — gated 模式启用**：`.mode` 文件必须包含 `gate` token（无则走 advisory）
2. **Guard 2 — 存在 in_progress phase**：仅有 complete < total 不足，必须有明确的 in_progress（issue #178）
3. **Guard 3 — stop_hook_active 检查**：从 stdin 读取 Stop hook JSON，如果是 `stop_hook_active=true` 则放行（防止递归）
4. **Guard 4 — block 计数上限**：`.stop_blocks` 文件计数 vs `PWF_GATE_CAP`（默认 20），超限放行
5. **Guard 5 — stall 检测**：如果此前已 block 但 ledger 行数未增长（agent 停滞），放行

**block 时行为**：输出单行 JSON `{"systemMessage":"[planning-with-files] ..."}` 到 stdout，hook 将此注入为 systemMessage 让 agent 继续工作。

### 4.4 `session-catchup.py` — 跨会话恢复

**定位**：agent 因 `/clear` 或崩溃丢失 context 后，自动恢复上次会话以来的所有对话。

**支持 IDE**：Claude Code（文件系统 JSON 日志）、OpenCode（SQLite DB）

**执行流程（Claude Code 路径）**：
1. 扫描 `~/.claude/projects/<project-hash>/` 下所有 session 目录
2. 按 session UUID 排序，当前 session 排除
3. 找到上次 plan 文件更新的 session 及行号
4. 从该行号开始，提取所有后续 session 中的所有对话消息
5. 格式化输出 catchup 报告：含 plan 更新时间、扫描 session 数、未同步行数、对话摘要

**OpenCode 路径**：SQLite 查询 `opencode.db`，从 `part` 表读取 JSONB 消息，按时间排序提取。

### 4.5 `resolve-plan-dir.sh` — Plan 目录解析

**定位**：所有脚本共享的 plan 目录解析器，解决"当前活动 plan 在哪"的问题。

**解析优先级**：
1. `$PLAN_ID` 环境变量 → `.planning/$PLAN_ID/`
2. `.planning/.active_plan` 文件内容 → 对应目录
3. `.planning/` 下 mtime 最新的目录
4. 空（调用方 fallback 到 legacy 根路径 `./task_plan.md`）

**安全**：每次解析后做 realpath 容器边界检查，symlink 逃逸的目录被视为未解析。

---

## 5. 文件规范

### 5.1 目录结构

```
planning-with-files/
├── skills/planning-with-files/   # canonical skill 定义（所有 IDE 适配的源头）
│   ├── SKILL.md                  #   YAML frontmatter + agent 行为规范
│   ├── examples.md               #   使用示例
│   ├── reference.md              #   Manus 6 条原则
│   ├── scripts/                  #   Shell + PowerShell 可执行脚本
│   └── templates/                #   3 种文件模板
├── commands/                     # Claude Code slash commands
├── templates/                    # 共享模板（与 skills/ 下的同步）
├── scripts/                      # 共享脚本（与 skills/ 下的同步）
├── tests/                        # Python 测试（350+）
├── docs/                         # 文档（17 个 IDE 安装指南 + workflow + evals + troubleshooting）
├── .claude-plugin/               # Claude Code 插件元数据
│   ├── plugin.json
│   └── marketplace.json
├── .{ide}/                       # 各 IDE 适配目录（14 个）
│   ├── hooks.json / hooks/       #   hook 配置 + 脚本
│   └── skills/planning-with-files/#   SKILL.md + scripts + templates
├── .github/                      # GitHub 相关
│   ├── hooks/planning-with-files.json    # Copilot hook 配置
│   ├── hooks/scripts/                    # Copilot hook 脚本
│   └── workflows/                        # CI（skill-review.yml、skill-optimize-apply.yml）
└── .hermes/                      # Hermes Python 插件（最完整的编程语言适配）
    ├── plugins/planning-with-files/
    └── skills/planning-with-files/
```

### 5.2 命名约定

- **Canonical skill**：`skills/planning-with-files/SKILL.md`，版本号在 `metadata.version`
- **IDE 适配**：`.xxx/skills/planning-with-files/SKILL.md`
- **脚本**：`snake_case.sh` / `snake_case.ps1`，对应 PowerShell 脚本同名不同扩展名
- **模板**：`snake_case.md`
- **多语言 skill**：`skills/planning-with-files-{lang}/`（ar、de、es、zh、zht）
- **测试**：`tests/test_{功能}.py`

### 5.3 SKILL.md Frontmatter Schema

```yaml
---
name: planning-with-files
description: "quoted string with colons properly handled"
metadata:
  version: "3.1.3"
allowed-tools: "Bash Read Write Edit Glob Grep WebSearch WebFetch ..."
---
```

- `allowed-tools` 是空格分隔字符串（Agent Skills 规范要求，非 YAML list）
- 无 `hooks` 字段（Claude Code 的 hook 走 plugin 体系，SKILL.md 不定义 hook）
- `description` 必须用引号包裹含冒号的值，否则 YAML 非法

---

## 6. SessionStart 注入

### 6.1 注入内容

每次新会话启动时，注入的内容取决于当前状态：

**情况 A：已有 plan**
- 运行 `session-catchup.py` 扫描上次 session 以来的对话
- 若 catchup 有结果：输出 `SESSION CATCHUP DETECTED ...` + 对话摘要 + "请先读 plan 文件并更新后继续"
- 若 catchup 无结果：注入 `task_plan.md` 前 5 行作为最低上下文

**情况 B：无 plan**
- 注入完整 `SKILL.md`（~450 行），告诉 agent 如何创建和使用 3 文件 plan 系统

### 6.2 Context 消耗量

- **SKILL.md 注入**：~450 行 ≈ 6-8K tokens
- **plan head 注入**（userprompt 模式）：task_plan.md 前 50 行 ≈ 0.5-1K tokens
- **progress tail 注入**（legacy 模式）：progress.md 后 15 行 ≈ 0.2-0.5K tokens
- **pretool 注入**：plan head 前 30 行 ≈ 0.3-0.5K tokens
- **v3 ledger summary 替代 progress tail**：约 0.1-0.3K tokens（比 raw progress 更省）
- **PreCompact 注入**：仅 1 行提醒 ≈ <0.05K tokens
- **PostToolUse 提醒**：1 行 ≈ <0.05K tokens

总计每次 turn 约 0.5-2K tokens（取决于模式），低开销。

---

## 7. 状态管理

### 7.1 文件状态

所有状态持久化在文件系统中：

| 状态 | 文件位置 | 格式 |
|------|---------|------|
| 任务计划 | `task_plan.md` | Markdown + `**Status:** pending\|in_progress\|complete` |
| 研究发现 | `findings.md` | Markdown |
| 进度日志 | `progress.md` | Markdown，按 session 分段 |
| 活动 plan 指针 | `.planning/.active_plan` | 纯文本，plan ID |
| Plan SHA 锁定 | `.planning/<plan>/.attestation` 或 `./.plan-attestation` | SHA-256 hex |
| 运行模式 | `.planning/<plan>/.mode` | `autonomous` 或 `autonomous gate` |
| Nonce | `.planning/<plan>/.nonce` | 8 字符 hex |
| Block 计数 | `.planning/<plan>/.stop_blocks` | 整数 |
| 运行账本 | `.planning/<plan>/ledger-*.jsonl` | JSONL |
| 写入锁 | `.planning/<plan>/.write_lock` | flock sentinel |
| SHA 缓存 | `~/.cache/planning-with-files/<hash>` | transient |

### 7.2 多 Plan 隔离

- **Slug 模式**：每个 plan 在 `.planning/<date>-<slug>/` 下，完全独立
- **环境变量切换**：`PLAN_ID=<plan-id>` 可强制指定当前终端会话的 plan
- **全局默认**：`.planning/.active_plan` 设置跨会话的默认 plan

### 7.3 Session / Checkpoint

无自建 checkpoint 机制。依赖 IDE 原生 session 系统：
- Claude Code：`~/.claude/projects/<hash>/<session-uuid>/` JSONL 日志
- OpenCode：`~/.local/share/opencode/opencode.db` SQLite
- `session-catchup.py` 通过读取这些原生日志做恢复，不做额外持久化

---

## 8. 编排模式

### 8.1 单 Agent（默认模式）

核心使用场景。一个 agent 在 SKILL.md 的规则驱动下自主管理 3 个计划文件，完成从 plan 创建到 phase 完成的整个流程。Hook 系统保证 agent 在每个生命周期点都能获取当前 plan 上下文。

### 8.2 v3 多 Agent 支持（Phase Coordination）

v3 `task_plan_autonomous.md` 模板引入了多 Agent 协调字段：

```
phase_coordination:
  - phase: "Phase N: ..."
    parallel_workers: 2
    can_start: ["Phase 1: Requirements"]
    needs: []
    can_parallelize: true
```

- `can_start`：该 phase 的前置 phase 列表（DAG 依赖）
- `parallel_workers`：该 phase 可并行派出的 agent 数量
- `can_parallelize`：该 phase 内的任务是否可以并行化
- `assigned_to`：已分配 worker 的标识

**状态同步机制**：
- **中心化**：`task_plan.md` 是共享状态文件（orchestrator 独占写入权）
- `phase-status.sh` 是唯一授权写入者（flock 保护 + atomic mv）
- Worker 禁止直接编辑 `task_plan.md`
- SHA attestation 在 phase 切换后需重新执行

### 8.3 派生项目中的多 Agent 编排

社区 fork 展现了不同的编排模式：
- **plan-cascade**：多级任务编排 + 并行执行 + 多 agent 协作
- **CCteam-creator**：多 agent team 编排，使用 file-based planning
- **devis**：面试优先的两阶段工作流（面试 → 实现）

### 8.4 总结

planning-with-files 本质上是**文件即共享内存**的编排思想：
- 不提供 agent 调度器
- 不管理 agent 生命周期
- 不控制 agent 间通信
- **只做一件事**：让 plan 文件成为多个 agent/会话之间的持久化共享状态
- 并行写入冲突通过 `phase-status.sh` 的 flock + atomic mv 解决
- 完整性通过 hash attestation 保证
