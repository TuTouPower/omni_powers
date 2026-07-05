# gstack

## 1. 概览

**一句话定位：** gstack 是一套 Claude Code 的 "AI 工程团队" 插件 —— 将 23+ 个专项角色（以 slash command skill 表达，无独立 custom Agent 定义）、一个持久化无头浏览器守护进程、80+ CLI 工具、以及自动化安全/审查/发布流水线，打包成单一 `git clone && ./setup` 安装。

**设计哲学：**
- **"Boil the Ocean"：** AI 辅助下边际成本趋零，做完整的事而非捷径。
- **"Search Before Building"：** 先搜索再建造 —— Layer 1(老牌成熟)、Layer 2(新热门)、Layer 3(第一性原理)。最值钱的是 Layer 3。
- **"User Sovereignty"：** 多模型共识只是推荐，不是决策。用户拥有否决权。
- **"Iron Man Suit"：** AI 增强用户而非替代，生成-验证循环。

**成熟度：**
- 总 commit 数 > 2000（仅 2026 年就 ~50 次）
- 版本号 v1.58.5.0（四段版本号：MAJOR.MINOR.PATCH.MICRO）
- 文档：CHANGELOG 8171 行、TODOS 2458 行、ARCHITECTURE 435 行、BROWSER 1402 行、CLAUDE.md 1023 行
- 56 个 `SKILL.md.tmpl` 模板 + 59 个生成的 `SKILL.md` 文件
- E2E 测试套件（free + paid LLM-judge + E2E via claude -p）
- 作者 Garry Tan（Y Combinator CEO），MIT 开源
- 极高活跃度，基础设施完整，生产可用

## 2. 安装机制

### 2.1 安装步骤

```bash
git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack
cd ~/.claude/skills/gstack && ./setup
```

`setup` 是一个 1531 行的 Bash 脚本，包含以下阶段：

1. **编译 browse 二进制：** 智能重建（源码 mtime 检查），`bun install && bun run build`，生成 compiled binary 到 `browse/dist/browse`
2. **macOS Apple Silicon codesign：** remove-signature + re-sign 修复 Bun compile 签名损坏问题
3. **安装 Playwright Chromium：** 确保 `playwright install chromium` 完成
4. **安装 emoji 字体（Linux）：** 自动检测包管理器，安装 Noto Color Emoji
5. **安装 coreutils（macOS）：** 为 Codex hang 保护提供 `gtimeout`
6. **生成 .agents/ 技能文档：** `gen:skill-docs --host codex`
7. **技能 symlink 注册：** 为每个 `*/SKILL.md` 创建真实目录，内部 SKILL.md symlink
8. **Team mode 注册：** 可选 SessionStart hook（每小时自动 git pull）
9. **GBrain 检测：** 如果 gbrain 可用，重新生成带脑感知块的 SKILL.md
10. **Plan-tune hooks 安装：** 可选的 PreToolUse/PostToolUse hooks（AskUserQuestion 捕获和偏好执行）

### 2.2 改动的配置文件

- `~/.claude/settings.json` -> SessionStart hook（auto-update；只触发后台更新脚本，不直接注入大段上下文）
- `~/.claude/settings.json` -> PostToolUse/PreToolUse hooks（plan-tune cathedral）
- `~/.gstack/config.yaml` -> 项目级配置（skill_prefix, telemetry, auto_upgrade 等）
- 项目 CLAUDE.md -> 追加 "## Skill routing" 章节（路由规则主要在技能/项目文档加载时进入上下文，不等同于 SessionStart token 开销）

### 2.3 Symlink 策略

核心模式：`~/.claude/skills/<skill-name>/SKILL.md -> ../../gstack/<skill-dir>/SKILL.md`

```
~/.claude/skills/
  ├── gstack/                  # git clone 的 repo 目录（真实目录，非 symlink）
  ├── ship/                    # 真实目录
  │   └── SKILL.md -> ../gstack/ship/SKILL.md
  ├── qa/                      # 真实目录
  │   └── SKILL.md -> ../gstack/qa/SKILL.md
  └── _gstack-command/         # router 别名
      └── SKILL.md -> ../gstack/SKILL.md
```

- 技能目录是**真实目录**（含 symlinked SKILL.md），不是目录 symlink。这确保 Claude Code 发现它们为顶级 skill
- 支持 `gstack-` 前缀模式（`/gstack-qa` vs `/qa`）
- Windows 上使用 `cp -R` 代替 `ln -snf`（Developer Mode 不可用时的后备）
- `_link_or_copy()` helper 是所有 link 操作的唯一入口

### 2.4 多宿主支持

setup 通过 `--host` 标志支持多 AI 宿主平台：

| 宿主 | 安装路径 |
|------|---------|
| claude | `~/.claude/skills/` |
| codex | `~/.codex/skills/` |
| factory | `~/.factory/skills/` |
| opencode | `~/.config/opencode/skills/` |
| openclaw | 方法论 artifacts（不安装 skills） |
| hermes | 同 openclaw |
| gbrain | `bun run gen:skill-docs --host gbrain` 生成脑增强变体 |
| auto | 自动检测所有已安装宿主 |

## 3. 提供的工具全景

### 3.1 Skills / Slash Commands（59 个 SKILL.md 文件）

#### 计划阶段评审（Plan-mode reviews）

| 名称 | 用途 |
|------|------|
| `/office-hours` | YC Office Hours 风格 —— 创业诊断 + 产品头脑风暴，6 个强制问题 |
| `/plan-ceo-review` | CEO 级别评审：寻找产品中的"10 星"机会 |
| `/plan-eng-review` | 工程经理评审：锁定架构、数据流、边界情况、测试 |
| `/plan-design-review` | 设计评审：10 维度评分(0-10)，解释满分长什么样 |
| `/plan-devex-review` | 开发者体验评审：TTHW、魔法时刻、摩擦点 |
| `/plan-tune` | 自我调优 AskUserQuestion 敏感度 |
| `/autoplan` | 一键串行 CEO -> design -> eng -> DX review |
| `/design-consultation` | 从零构建设计系统 |
| `/spec` | 五阶段生成 backlog-ready 的 spec + GitHub issue |

#### 实现 + 评审（Implementation + review）

| 名称 | 用途 |
|------|------|
| `/review` | Pre-landing PR 审查 |
| `/codex` | 通过 OpenAI Codex CLI 获取第二意见 |
| `/investigate` | 系统化根因调试，不修复不停止 |
| `/design-review` | 实时站点视觉审计 + 修复循环 |
| `/design-shotgun` | 多 AI 设计变体生成 + 对比板 |
| `/design-html` | 生成生产级 HTML/CSS |
| `/devex-review` | 实时开发者体验审计 |
| `/qa` | 打开真浏览器，找 bug，修，复验 |
| `/qa-only` | 同上但仅报告，不修改代码 |
| `/scrape` | 从网页提取数据，第二次调用 ~200ms |
| `/skillify` | 将最近成功的 `/scrape` 流程固化到永久浏览器技能 |

#### 发布 + 部署（Release + deploy）

| 名称 | 用途 |
|------|------|
| `/ship` | 跑测试、审查、push、开 PR |
| `/land-and-deploy` | merge PR → 等 CI → deploy → 验证生产 |
| `/canary` | 发布后监控循环（使用 browse daemon） |
| `/landing-report` | 工作区感知的 ship queue 只读面板 |
| `/document-release` | 发布后更新所有文档 |
| `/document-generate` | 从代码生成 Diataxis 文档 |
| `/setup-deploy` | 一次性 deploy 配置检测 |
| `/gstack-upgrade` | 升级到 gstack 最新版本 |

#### 运维 + 记忆（Operational + memory）

| 名称 | 用途 |
|------|------|
| `/context-save` | 保存工作上下文（git 状态、决策、剩余工作） |
| `/context-restore` | 恢复保存的上下文，跨 Conductor 工作区 |
| `/learn` | 管理跨 session 学到的东西 |
| `/retro` | 周度回顾，按人细分 + shipping streak |
| `/health` | 代码质量仪表盘 |
| `/benchmark` | 性能回归检测 |
| `/benchmark-models` | 跨模型基准测试（Claude、GPT、Gemini 并排） |
| `/cso` | OWASP Top 10 + STRIDE 安全审计 |
| `/setup-gbrain` | 设置 gbrain 跨机器 session 记忆同步 |
| `/sync-gbrain` | 保持 gbrain 与 repo 代码同步 |

#### 浏览器 + Agent 集成（Browser + agent integration）

| 名称 | 用途 |
|------|------|
| `/browse` | 无头浏览器 —— 真 Chromium，~100ms/命令 |
| `/open-gstack-browser` | 启动可见 GStack Browser（带侧边栏 + 隐身） |
| `/setup-browser-cookies` | 从真实浏览器导入 cookie（认证测试用） |
| `/pair-agent` | 将远程 AI agent 与本地浏览器配对 |

#### iOS QA（v1.43.0.0+）

| 名称 | 用途 |
|------|------|
| `/ios-qa` | USB CoreDevice 隧道 + StateServer 真机 QA |
| `/ios-fix` | 自主 iOS bug 修复 + 回归快照捕获 |
| `/ios-design-review` | 10 维度 Apple HIG 评分 |
| `/ios-clean` | 移除 DebugBridge + #if DEBUG |
| `/ios-sync` | 重新生成 iOS 调试桥接 |

#### 安全 + 范围控制（Safety + scoping）

| 名称 | 用途 |
|------|------|
| `/careful` | 危险命令前警告（rm -rf、DROP TABLE、force-push） |
| `/freeze` | 锁定编辑到单目录，硬阻止 |
| `/guard` | 同时激活 careful + freeze |
| `/unfreeze` | 移除目录编辑限制 |
| `/make-pdf` | Markdown -> 出版物质量 PDF |
| `/diagram` | 自然语言 -> mermaid + .excalidraw + SVG/PNG |

#### 基础路由（Router）

| 名称 | 用途 |
|------|------|
| `/gstack` | 路由器 skill：按请求意图分派到正确的 skill |

### 3.2 Hooks

#### SessionStart Hook（Team Mode）

- **触发：** 每次 Claude Code session 启动
- **执行：** `bin/gstack-session-update`
- **行为：** fork 到后台，检查 throttle（1 小时），`git fetch && git merge --ff-only` 自动升级
- **非阻塞：** 立即返回，错误永不阻塞 session 启动

#### PostToolUse Hook（Plan-tune Cathedral）

- **触发：** 每次 `AskUserQuestion` 工具调用后
- **执行：** `hosts/claude/hooks/question-log-hook` — 捕获并记录每次 AUQ 触发
- **执行：** `hosts/claude/hooks/auq-error-fallback-hook` — 检测 AUQ 运行时失败

#### PreToolUse Hook（Plan-tune Cathedral）

- **触发：** 每次 `AskUserQuestion` 工具调用前
- **执行：** `hosts/claude/hooks/question-preference-hook` — 按 `never-ask` 偏好执行 permissionDecision

#### Redact Pre-push Hook

- **按仓库安装：** `/ship` 在每次 push 前自动安装
- **执行：** `bin/gstack-redact-prepush` — 扫描凭据/密钥/PII

### 3.3 自定义 Agents

- `agents/openai.yaml` — OpenAI Codex 的 agent 定义
- 非 Claude 宿主（Codex、Gemini、Cursor 等）使用 `.agents/skills/` 下生成的 Codex 格式 SKILL.md

### 3.4 CLI 工具 / 可执行脚本（~80 个 bin/ 文件）

主要类别：

| 类别 | 代表工具 | 用途 |
|------|---------|------|
| **配置管理** | `gstack-config` | 读写 `~/.gstack/config.yaml` |
| **会话管理** | `gstack-session-update`, `gstack-session-kind` | SessionStart hook、检测 spawned/headless/interactive |
| **版本控制** | `gstack-next-version`, `gstack-version-bump` | 四段版本号队列推进 |
| **仓库检测** | `gstack-repo-mode`, `gstack-slug`, `gstack-first-task-detect` | 检测项目类型、生成 slug |
| **遥测** | `gstack-telemetry-log`, `gstack-telemetry-sync`, `gstack-analytics` | 本地+远程 telemetry（opt-in） |
| **安全** | `gstack-redact`, `gstack-redact-prepush`, `gstack-security-dashboard` | 凭据扫描、安全面板 |
| **记忆/学习** | `gstack-learnings-log`, `gstack-learnings-search`, `gstack-decision-log`, `gstack-decision-search` | JSONL 学习记录、决策记录（事件溯源） |
| **脑同步** | `gstack-brain-sync`, `gstack-brain-restore`, `gstack-brain-cache`, `gstack-brain-consumer`, `gstack-memory-ingest.ts` | 跨机器 artifacts 同步、gbrain 集成 |
| **构建/开发** | `dev-setup`, `dev-teardown`, `gstack-detach`, `gstack-relink`, `gstack-paths` | 开发者工具链 |
| **团队** | `gstack-team-init`, `gstack-settings-hook` | Team mode 初始化、settings.json hook 管理 |
| **评估** | `gstack-model-benchmark`, `gstack-diff-scope` | 模型基准测试、diff 范围检测 |
| **其他** | `gstack-open-url`, `gstack-platform-detect`, `gstack-pr-title-rewrite.sh` 等 | 工具类 |

### 3.5 MCP Servers

gstack **不提供** MCP server。相反，它**主动绕过** MCP 协议，使用朴素 Bash 工具：
- 浏览器是通过 `$B <command>` 调用编译二进制（stdin/stdout），不是 MCP
- 设计意图明确：HTTP + plain text 比 JSON-schema + persistent WebSocket 更轻、更易调试

### 3.6 Chrome Extension

`extension/` 目录包含一个完整的 Chrome 扩展（GStack Browser）：
- `sidepanel.js` (54KB) + `sidepanel-terminal.js` (38KB) — 侧边栏，内含交互式 claude PTY
- `sidepanel.html/css` — 侧边栏 UI
- `background.js` — Service Worker
- `content.js` — 内容脚本，注入页面
- `inspector.js` — CSS 检查器
- `manifest.json` — Chrome 扩展清单
- `popup.html/js` — 弹出窗口

### 3.7 模板 / 脚手架

- `SKILL.md.tmpl` 系统：56 个模板文件，通过 `gen-skill-docs.ts` 生成 SKILL.md
- `contrib/add-host/SKILL.md` — 添加新宿主平台的技能指南
- `design/prototype.ts` — 设计原型

### 3.8 配置文件 / Rules

- `hosts/claude.ts` 等 — 类型化宿主配置（frontmatter 过滤、路径重写、resolver 抑制）
- `ETHOS.md` — 建设者哲学，会注入到每个 skill preamble
- `DESIGN.md` — 设计系统（颜色、排版、间距、动效）
- `.env.example` — 环境变量模板
- `slop-scan.config.json` — AI 代码质量扫描
- `conductor.json` — Conductor 工作区配置

### 3.9 基础设施

- **E2E 测试框架：** `test/helpers/session-runner.ts`、`eval-store.ts`、`llm-judge.ts`、`touchfiles.ts`
- **CI/CD：** `.github/workflows/`、`.gitlab-ci.yml`、Docker CI 镜像
- **Supabase 集成：** `supabase/functions/`、`supabase/migrations/` — 社区脉搏遥测和存储
- **gbrain 集成：** `lib/gbrain-exec.ts`、`lib/gbrain-sources.ts` — 跨 session 记忆

## 4. 核心工具详解

### 4.1 Browse Daemon（无头浏览器守护进程）

**gstack 最核心的技术组件，也是所有 QA/测试/设计审查技能的基础。**

**完整执行流程：**

```
[用户/Skill 调用: $B goto https://example.com]
    |
    v
1. CLI 读状态文件 ~/.gstack/browse.json
    |
    ├─ 状态文件存在 + server 健康 -> 跳到步骤 5
    └─ 不存在/不健康 -> 步骤 2
    |
    v
2. 启动新守护进程
   - 从 10000-60000 随机选端口（最多重试 5 次）
   - spawn Chromium（Playwright, headless）
   - 启动 Bun.serve() HTTP server（127.0.0.1 绑定）
   - 生成 UUID bearer token
   - 原子写入 .gstack/browse.json（tmp + rename, mode 0o600）
    |
    v
3. 初始化 Chromium
   - 创建 persistent context（cookies/localStorage 持久化）
   - 启动日志缓冲（3 个环形缓冲，各 50000 条）
   - 启动 idle timer（30 分钟自动关闭）
    |
    v
4. 首次调用 ~3s，后续调用 ~100-200ms
    |
    v
5. CLI 发 HTTP POST /command（Authorization: Bearer <token>）
    |
    v
6. Server 分派命令
   - 按类别路由：READ / WRITE / META
   - 通过 CDP (Chrome DevTools Protocol) 与 Chromium 通信
   - 使用 Playwright Locators（不是 DOM 注入）做 ref-based 元素选择
    |
    v
7. 响应返回纯文本到 stdout
   - 错误消息针对 AI agent 设计（可操作，而非堆栈追踪）
   - 输出自动 sanitize（lone UTF-16 surrogate 清理）
    |
    v
8. 空闲 30 分钟 -> server 自动退出
   - 下次调用时 auto-restart
```

**输入：** `$B <command> [args]`（如 `$B goto url`, `$B snapshot -i`, `$B click @e3`）
**输出：** 纯文本 stdout（snapshot 标注树、页面文本、HTML、JSON 等）
**底层能力：** Bash（调用 CLI）、HTTP（CLI->Server）、CDP（Server->Chromium）、Playwright（Locator API）
**70+ 命令：** goto, click, fill, press, snapshot, screenshot, text, html, links, js, eval, console, network, cookies, frame, tabs, chain, batch, connect, pair-agent, stop 等

**关键设计决策：**
- **不用 MCP 协议**：朴素 HTTP + stdout，比 JSON-schema 框架轻，token 开销更低
- **Ref 系统**：`@e1`、`@e2`（ARIA 树）/ `@c1`、`@c2`（cursor-interactive），不修改 DOM（绕过 CSP/React hydration/Shadow DOM 问题）
- **守护进程模型而非每次冷启动**：持久化状态，次秒级命令
- **版本自重启**：二进制 vs 运行中 server 的 git hash 不匹配时自动 kill 重启
- **双监听器隧道架构**：本地端口（全命令表面）+ 隧道端口（26 命令 allowlist + scoped token），ngrok 只转发隧道端口
- **Cookie 安全**：Chromium SQLite DB 复制到 tmp（只读）、内存解密、永不写盘、Keychain 每次需要用户批准

### 4.2 SKILL.md 模板生成系统

**gstack 的文档基础设施，保证 59 个 SKILL.md 文件与代码不漂移。**

**完整执行流程：**

```
[开发者编辑 SKILL.md.tmpl]
    |
    v
1. 运行 bun run gen:skill-docs（或 bun run build）
    |
    v
2. gen-skill-docs.ts 读取源数据
   - browse/src/commands.ts -> 命令注册表
   - browse/src/snapshot.ts -> snapshot flag 元数据
   - scripts/resolvers/*.ts -> 各 resolver 模块
   - scripts/jargon-list.json -> 术语表
    |
    v
3. 占位符替换
   {{PREAMBLE}}           -> 启动块（更新检查、会话跟踪、AUQ 格式、搜索引导）
   {{COMMAND_REFERENCE}}  -> 分类命令表
   {{SNAPSHOT_FLAGS}}     -> snapshot flag 参考
   {{BROWSE_SETUP}}       -> 二进制发现 + 设置说明
   {{DESIGN_SETUP}}       -> $D 设计二进制发现
   {{GBRAIN_CONTEXT_LOAD}} -> 脑感知上下文加载（可选）
   {{GBRAIN_SAVE_RESULTS}} -> 脑感知结果保存（可选）
   {{REDACT_TAXONOMY_TABLE}} -> 凭据分类表
   ... 等 ~20 个占位符
    |
    v
4. 多宿主生成
   --host claude   -> ~/.claude/skills/gstack/<skill>/SKILL.md
   --host codex    -> .agents/skills/gstack-<skill>/SKILL.md
   --host factory  -> .factory/skills/
   --host opencode -> .opencode/skills/
   --host gbrain   -> 脑增强变体（额外 ~250 tokens/skill）
   --host openclaw -> 方法论 artifacts
   --host hermes   -> 同 openclaw
    |
    v
5. CI 校验
   gen:skill-docs --dry-run + git diff --exit-code = 捕获陈旧文档
```

**输入：** `SKILL.md.tmpl`（人类写 prose + `{{PLACEHOLDER}}`）
**输出：** 生成的 `SKILL.md`（提交到 git，CI 可验证）
**底层能力：** Bun（TypeScript 运行时）、Read（读源码元数据）、Write（生成文档）

**关键设计决策：**
- **提交生成文件而非运行时生成：** Claude 读 SKILL.md 时没有构建步骤
- **Git blame 可用：** 可追踪何时添加命令
- **Token 天花板：** 160KB (~40K tokens) 警告阈值，防止 preamble/resolver 膨胀
- **Resolver 模块化：** 按功能拆分为 `preamble.ts`、`gbrain.ts`、`design.ts`、`redact-doc.ts` 等

### 4.3 Router Skill（/gstack）

**会话入口。每次 gstack skill 加载时自动执行，是 gstack 的"操作系统引导"。**

**完整执行流程：**

```
[Claude Code session 开始，加载 gstack skill]
    |
    v
1. Preamble 运行（一个 bash 块，~100 行）
    ├─ 更新检查: gstack-update-check -> 报告是否有新版本
    ├─ 会话跟踪: touch ~/.gstack/sessions/$PPID
    ├─ 会话计数: find mmin -120 -> 超过 3 个进入 "ELI16 mode"
    ├─ repo 模式: gstack-repo-mode -> greenfield/code_node/branch_ahead/dirty/clean
    ├─ Session kind: gstack-session-kind -> spawned|headless|interactive
    ├─ Conductor 检测: 有 CONDUCTOR_WORKSPACE_PATH 则标记
    ├─ 首次运行检测: gstack-first-task-detect -> 项目类型建议
    ├─ GBrain 检测: 有 .gbrain-source 则提示可用 gbrain search
    ├─ Artifacts sync: brain-sync --once（如果配置了跨机器同步）
    ├─ 遥测写入: skill-usage.jsonl（如 telemetry != off）
    └─ 学习记录加载: learnings.jsonl -> 显示最近 3 条
    |
    v
2. 首次运行引导（按序检查多个状态标记）
    ├─ ACTIVATED=no? -> 显示项目类型提示（greenfield→/spec, 有代码→/qa）
    ├─ LAKE_INTRO=no? -> 显示 "Boil the Ocean" 理念
    ├─ TEL_PROMPTED=no? -> 询问 telemetry 偏好（community/anonymous/off）
    ├─ PROACTIVE_PROMPTED=no? -> 询问是否允许主动 skill 建议
    ├─ WRITING_STYLE_PENDING? -> 询问 V0(terse) vs V1(default) 写作风格
    └─ HAS_ROUTING=no? -> 询问是否注入 skill routing 到 CLAUDE.md
    |
    v
3. 路由决策
    ├─ 浏览器/QA/截图/检查页面 -> invoke /browse
    ├─ 新产品创意 -> /office-hours
    ├─ 写 spec/issue -> /spec
    ├─ 策略/范围 -> /plan-ceo-review
    ├─ 架构 -> /plan-eng-review
    ├─ 设计系统 -> /design-consultation
    ├─ bug/错误 -> /investigate
    ├─ QA/测试 -> /qa
    ├─ 代码审查 -> /review
    ├─ ship -> /ship
    └─ ... 共 30+ 条路由规则
    |
    v
4. 遥测上报: gstack-telemetry-log route <outcome>
```

**输入：** 用户自然语言请求
**输出：** 调用 Skill tool 分派到对应 skill
**底层能力：** Bash（preamble shell 脚本）、bin/ CLI 工具集、Skill tool（分派）
**上下文消耗：** preamble 的 bash 块输出 ~60 行 stdout + 后续 prose 引导（总体估计 ~4-6K tokens）

### 4.4 Security Stack（安全栈 L1-L6）

**六层防御系统，专门保护 Sidebar Agent（有 Bash/Read 工具、读敌对网页的 agent）。**

**完整执行流程：**

```
[Web 页面内容进入系统]
    |
    v
L1-L3: content-security.ts（服务器 + Agent 两侧运行）
    ├─ 数据标记（标记来源是用户还是页面）
    ├─ 隐藏元素剥离
    ├─ ARIA 正则过滤
    ├─ URL 阻止列表
    └─ 信任边界信封包装
    |
    v
L4: TestSavantAI ONNX 分类器（仅 Agent 侧，不进入编译二进制）
    ├─ 22MB BERT-small (int8 量化), 本地运行无网络
    ├─ 扫描每一条用户消息和工具输出
    └─ 分数 >= 0.85 BLOCK, >= 0.75 WARN
    |
    v
L4b: Claude Haiku 转录分类器（可选，付费调用）
    ├─ 查看完整对话形状（用户消息 + 工具调用 + 输出）
    ├─ 门控: 所有层 < 0.40 则跳过（省钱）
    └─ 分数 >= 0.75 WARN
    |
    v
L4c: DeBERTa-v3 ensemble（可选，opt-in）
    ├─ 721MB, 首次下载
    ├─ 启用后需 2-of-3 分类器同意
    └─ GSTACK_SECURITY_ENSEMBLE=deberta
    |
    v
L5: Canary Token（安全提示词金丝雀）
    ├─ 随机 token 注入系统提示词
    ├─ 滚动缓冲检测 text_delta 和 input_json_delta
    └─ 泄露 = 确定 BLOCK（攻击者读取了系统提示词）
    |
    v
L6: combineVerdict 集成判决
    ├─ 单层高置信度 = WARN（Stack Overflow 误报缓解）
    ├─ 双 ML 分类器 >= WARN = BLOCK
    └─ Canary 泄露 = 始终 BLOCK
```

**输入：** 页面内容、用户消息、工具输出
**输出：** PASS / WARN / BLOCK 判决 + 各层分数
**底层能力：** ONNX Runtime（本地分类器）、Anthropic API（Haiku 转录）、Playwright（DOM 操作）
**安全属性：**
- `GSTACK_SECURITY_OFF=1` 紧急关闭开关（canary 仍注入）
- 攻击日志: `~/.gstack/security/attempts.jsonl`（salted sha256 + domain, 10MB 轮转）
- 每设备 salt: `~/.gstack/security/device-salt` (0600)
- 关键约束: `security-classifier.ts` 不能 import 到编译 browse 二进制

### 4.5 E2E Test Infrastructure（E2E 测试基础设施）

**确保 56 个 skill 在实际 Claude Code 会话中运行不出错。**

**完整执行流程：**

```
[bun test test/skill-e2e-*.test.ts]
    |
    v
1. 基于 diff 的测试选择
   - touchfiles.ts 声明每个测试的文件依赖
   - git diff vs base branch 决定运行哪些测试
   - 全局 touchfiles 变更 -> 运行全部
    |
    v
2. 测试分层
   ├─ Tier 1 — 静态验证（免费，<5s）
   │   解析 $B 命令，验证注册表
   ├─ Tier 2 — E2E via claude -p（~$3.85，~20min）
   │   spawn claude -p --output-format stream-json --verbose
   │   解析 NDJSON 转录
   └─ Tier 3 — LLM-as-judge（~$0.15，~30s）
       Sonnet 评分文档质量
    |
    v
3. session-runner.ts
   ├─ 写 prompt 到临时文件
   ├─ spawn sh -c 'cat prompt | claude -p ...'
   ├─ 实时流 NDJSON stdout（逐工具进度）
   └─ parseNDJSON() 纯函数解析
    |
    v
4. eval-store.ts（观察性数据流）
   ├─ savePartial() -> _partial-e2e.json（逐测试保存，原子写入）
   ├─ EvalCollector 累积结果
   └─ finalize() -> timestamped eval file
    |
    v
5. eval:compare / eval:summary
   ├─ 两次 eval 运行对比
   └─ 所有运行聚合统计
    |
    v
6. 两级分类
   ├─ gate: 安全守卫 + 确定性功能测试
   ├─ periodic: 质量基准 + Opus 模型测试 + 非确定性 + 外部服务
   └─ CI 只跑 gate tier；periodic 每周 cron
```

**输入：** 测试依赖声明、git diff
**输出：** 结构化测试结果（exit_reason、timeout_at_turn、last_tool_call）
**底层能力：** Bun test runner、child process spawn、NDJSON 流解析、文件系统观察（heartbeat/partial 拼合）

**Hermetic Local E2E（默认）：**
- 每个子进程通过 `test/helpers/hermetic-env.ts` 启动
- allowlist 清理的 env（不含 CONDUCTOR_*、CLAUDE_CONFIG_DIR 等）
- 新鲜种子的 `CLAUDE_CONFIG_DIR`
- temp `GSTACK_HOME`
- `--strict-mcp-config`
- `EVALS_HERMETIC=0` 回退到 operator 真实状态调试

## 5. 文件规范

### 5.1 目录结构

```
gstack/
├── SKILL.md / SKILL.md.tmpl       # Router skill
├── CLAUDE.md                      # 开发者文档（项目级，非分发）
├── AGENTS.md                      # Agent 技能索引
├── ARCHITECTURE.md                # 架构文档
├── BROWSER.md                     # 浏览器 API 完整参考
├── ETHOS.md                       # 建设者哲学
├── DESIGN.md                      # 设计系统
├── CHANGELOG.md                   # 用户产品发布说明
├── TODOS.md                       # 待办和路线图
├── CONTRIBUTING.md                # 贡献指南
├── README.md                      # 项目介绍 + 快速开始
├── package.json                   # Bun 项目配置
├── VERSION                        # 单调递增发布标识
├── conductor.json                 # Conductor 工作区配置
├── setup                          # 安装脚本（1531 行 Bash）
│
├── <skill-name>/                  # 每个 skill 一个目录
│   ├── SKILL.md                   # 生成的文件（不手动编辑）
│   ├── SKILL.md.tmpl              # 人类编辑的模板
│   └── sections/                  # 刀刻派生的按需加载章节（carving）
│
├── browse/                        # 无头浏览器（重资产组件）
│   ├── src/                       # CLI + server + 命令
│   │   ├── cli.ts
│   │   ├── server.ts
│   │   ├── commands.ts            # 命令注册表（单一真相源）
│   │   ├── snapshot.ts            # snapshot flag 元数据
│   │   ├── cdp-bridge.ts          # CDP 会话管理
│   │   ├── content-security.ts    # L1-L3 安全
│   │   ├── security.ts            # L5-L6 安全
│   │   ├── security-classifier.ts # L4 安全（不在编译二进制中）
│   │   ├── error-handling.ts      # safeUnlink 等工具
│   │   ├── terminal-agent-control.ts
│   │   └── sse-helpers.ts
│   ├── test/                      # 浏览器集成测试
│   └── dist/                      # 编译二进制（不提交）
│
├── design/                        # 设计工具 CLI（GPT Image API）
│   └── src/ prototype.ts 等
│
├── extension/                     # Chrome 扩展
│   ├── sidepanel.{js,html,css}    # 侧边栏 + claude PTY
│   ├── background.js              # Service Worker
│   ├── content.{js,css}           # 内容脚本
│   ├── inspector.{js,css}         # CSS 检查器
│   ├── popup.{js,html}            # 弹出窗口
│   └── manifest.json
│
├── hosts/                         # 类型化宿主配置
│   ├── index.ts                   # Registry
│   ├── claude.ts / codex.ts / factory.ts / ...
│   └── claude/hooks/              # Plan-tune hooks
│
├── bin/                           # ~80 CLI 工具（Bash + TS）
│
├── scripts/                       # 构建 + 代码生成 + 工具
│   ├── gen-skill-docs.ts          # 模板到 SKILL.md 生成器
│   ├── resolvers/                 # 解析器模块(preamble, gbrain, design, redact)
│   ├── skill-check.ts             # Skill 健康仪表盘
│   ├── dev-skill.ts               # 监控模式
│   └── discover-skills.ts, capture-baseline.ts, ...
│
├── lib/                           # 共享库
│   ├── worktree.ts                # git worktree 工具
│   ├── redact-engine.ts           # 凭据扫描引擎
│   ├── redact-patterns.ts         # 凭据模式库
│   ├── gbrain-exec.ts             # gbrain 集成
│   ├── gstack-decision.ts         # 决策记录
│   └── diagram-render/            # 图表渲染
│
├── test/                          # E2E + 技能验证测试
│   ├── helpers/                   # session-runner, eval-store, llm-judge, hermetic-env
│   ├── fixtures/                  # 测试 fixture
│   └── skill-e2e-*.test.ts        # E2E 测试
│
├── model-overlays/                # 模型特定行为补丁
│   ├── claude.md / opus-4-7.md / gpt.md / gemini.md / o-series.md
│
├── docs/                          # 项目文档
├── supabase/                      # 后端集成
│   ├── functions/                 # Edge Functions
│   └── migrations/
│
├── contrib/                       # 贡献者工具（不安装给用户）
│   └── add-host/
│
├── .github/                       # CI workflows + Docker 镜像
│   └── workflows/ evals.yml, skill-docs.yml
│
└── openclaw/skills/               # 原生 OpenClaw 技能（ClawHub 发布）
```

### 5.2 Frontmatter / Metadata Schema

每个 `SKILL.md` 必须包含 YAML frontmatter：

```yaml
---
name: skill-name            # 技能名（用于 /<name> 调用）
preamble-tier: 1|2|3|4      # 1=轻量摘要, 4=完整 preamble + 所有 resolver
version: X.Y.Z              # 语义版本
description: "..."           # 技能描述（在括号内包含 (gstack) 标记）
allowed-tools:               # 工具权限
  - Bash
  - Read
  - Write
  - Edit
# 可选字段:
triggers: [...]              # 触发词
sensitive: true              # 敏感内容（会被某些宿主 strip）
voice-triggers: [...]        # 语音触发词
---
```

**模板文件命名：** `SKILL.md.tmpl`（人类编辑） -> `SKILL.md`（生成，提交）

### 5.3 命名约定

- Skill 目录：`kebab-case`（如 `plan-ceo-review`、`context-save`）
- bin/ CLI 工具：`gstack-<function>` 前缀（如 `gstack-config`、`gstack-session-update`）
- hosts/ 宿主配置文件：宿主名 `.ts`（如 `claude.ts`、`codex.ts`）
- 测试文件：`skill-e2e-<category>.test.ts`
- Resolver 模块：`<category>.ts`（如 `preamble.ts`、`design.ts`）

## 6. SessionStart 注入

### 6.1 注入机制

Team mode 下，setup 通过 `bin/gstack-settings-hook` 将以下内容注册到 `~/.claude/settings.json`：

```json
{
  "hooks": {
    "SessionStart": [
      {
        "command": "~/.claude/skills/gstack/bin/gstack-session-update",
        "source": "_gstack"
      }
    ]
  }
}
```

### 6.2 注入内容

`gstack-session-update` 脚本做了什么：
1. 检查 `GSTACK_DIR/.git` 是否有效
2. 检查 `auto_upgrade` 配置是否为 true
3. throttle 检查：距上次更新 < 1 小时则跳过
4. fork 到后台：`git fetch origin && git merge --ff-only`
5. 永不阻塞 session 启动（`exit 0` 始终）

### 6.3 上下文消耗量

- SessionStart hook 本身：**0 token**（只运行 auto-update 脚本，不把 stdout 注入 Claude Code 上下文）
- Router skill preamble 输出：~60 行 bash stdout 输出（在 router/skill 被加载或执行时出现，不是 SessionStart 固定开销）-> 估算 **~2-3K tokens**
- Router skill prose（首次引导 + 路由规则）：~200 行 markdown -> 估算 **~3-4K tokens**
- 其他加载的 skill（按需）：每个 skill 的 SKILL.md 200-1500 行
- **总体估计（router + 一个典型 skill）：~8-12K tokens**
- 带 prompt caching 的边际成本更低

## 7. 状态管理

### 7.1 文件和目录布局

```
~/.gstack/
├── config.yaml                    # gstack-config 读写的主配置
├── sessions/                      # 活跃 session 标记（$PPID 文件名）
├── projects/<slug>/               # 按项目分
│   ├── learnings.jsonl           #   操作学习记录（append-only）
│   └── decisions.jsonl           #   持久化决策（事件溯源，append-only）
├── analytics/                     # 本地遥测
│   ├── skill-usage.jsonl         #   技能使用记录
│   └── session-update.log        #   自动更新日志
├── security/                      # 安全
│   ├── attempts.jsonl            #   攻击尝试日志（10MB 轮转，5 代）
│   ├── device-salt               #   每设备 salt（0600）
│   └── session-state.json        #   跨进程 session 状态
├── models/                        # ML 模型缓存
│   ├── testsavant-small/         #   112MB（提示词注入分类器）
│   └── deberta-v3-injection/     #   721MB（opt-in ensemble）
├── browser-skills/                # 固化的 browser-skill 脚本
├── .activated                     # 首次运行标记
├── .telemetry-prompted            # 遥测已询问标记
├── .proactive-prompted            # 主动建议已询问标记
├── .completeness-intro-seen       # Boil the Ocean 已显示标记
├── .last-session-update           # 自动更新 throttle 时间戳
├── .plan-tune-hooks-prompted      # Plan-tune hooks 已询问标记
├── .vendoring-warned-<slug>       # 按项目的 vendoring 警告标记
└── gbrain-detection.json          # GBrain 检测结果
```

### 7.2 记忆机制

**操作学习记录（Learnings）：**
- 文件：`~/.gstack/projects/<slug>/learnings.jsonl`
- 格式：JSONL，每行 `{"skill":"...","type":"operational","key":"...","insight":"...","confidence":N,"source":"observed"}`
- 查询：`gstack-learnings-search --limit 3`（每次 session 开始自动运行）
- 写入：skill 结束前调用 `gstack-learnings-log`（仅记录跨 session 价值的信息）

**持久化决策（Decisions）：**
- 文件：`~/.gstack/projects/<slug>/decisions.jsonl`
- 格式：事件溯源 append-only JSONL
- 捕获：`gstack-decision-log '{"decision":"...","rationale":"...","scope":"repo|branch|issue",...}'`
- 查询：`gstack-decision-search --recent N --scope repo|branch|issue`（session 开始时自动列入上下文）
- 语义搜索：`--semantic` flag 调用 gbrain 的额外语义匹配
- 操作：`--supersede <id>` 推翻，`--redact <id>` 移除密钥，`--compact` 重写到活跃集
- 非交互式，注入消毒，写入 HIGH 密钥阻止

**跨 Session 上下文保存/恢复：**
- `/context-save`：保存工作上下文到 `~/.gstack/projects/<slug>/contexts/`
- `/context-restore`：跨 Conductor 工作区恢复

**GBrain 集成（可选）：**
- `/sync-gbrain`：索引代码到语义搜索引擎
- GBrain 自动代理（autopilot）：增量刷新
- 跨机器 artifacts 同步：`gstack-brain-sync` + private GitHub repo
- 工作区固定：`.gbrain-source` 文件（kubectl 风格的上下文）

### 7.3 会话跟踪

- `~/.gstack/sessions/$PPID`：touch 文件标记活跃 session
- 超过 3 个活跃 session -> "ELI16 mode"（每问都重新建立上下文）
- 超过 2 小时未修改 -> 自动清理

## 8. 编排模式

### 8.1 Router 模式（单 entry，多分派）

```
用户请求 -> /gstack (Router)
              |
              ├─ 浏览器相关       -> /browse
              ├─ 产品想法         -> /office-hours
              ├─ 架构             -> /plan-eng-review
              ├─ bug              -> /investigate
              ├─ QA               -> /qa
              ├─ ship             -> /ship
              └─ ... 30+ 条规则
```

### 8.2 Pipeline 模式（串行阶段）

```
/autoplan: /plan-ceo-review -> /plan-design-review -> /plan-eng-review -> /plan-devex-review
           (每个阶段输出流入下一个阶段)

/ship:     merge base -> test -> review -> bump version -> changelog -> commit -> push -> PR

/land-and-deploy: merge -> wait CI -> deploy -> /canary verify
```

### 8.3 Multi-Agent / Outside Voice 模式

```
用户想法
  ├─ Claude (主 agent, 执行者)
  └─ Codex (outside voice, 挑战者)
       └─ /codex review -> 独立审查报告 -> 用户决策 -> Claude 执行
```

### 8.4 Agent Spawn 模式（/spec + /ship 闭环）

```
/spec
  ├─ Phase 1-4: 生成 spec
  └─ Phase 5: 创建 GitHub issue + 可选 spawn Claude Code agent(Conductor worktree)
       └─ agent 实现 spec
            └─ /ship -> 自动关闭源 issue
```

### 8.5 Leader-Worker 模式（Conductor 工作区）

- Conductor 是 gstack 的"指挥家" —— 管理多个 git worktree
- 每个 worktree 有独立的 browse daemon、独立的 `.gbrain-source` 固定
- `conductor.json` 定义 setup/archive 脚本
- Conductor 环境下 AskUserQuestion 降级为 prose brief（MCP 变体不稳定）

### 8.6 OpenClaw 集成（Orchestrator -> Claude Code）

```
OpenClaw agent (UI 层)
  ├─ 简单任务 -> 直接处理
  ├─ coding 任务 -> spawn Claude Code session (with gstack skills)
  │     └─ "Load gstack. Run /cso" 等
  └─ 方法论 skill -> 直接运行 gstack-openclaw-* 技能
```

### 8.7 总结

gstack 主要编排模式是 **Router（一对多分派）+ Pipeline（串行阶段）**，没有复杂的 DAG 或多 agent 并行编排。它的价值在于每个独立 skill 的质量 —— 结构化工作流、检查清单、质量门 —— 而非新颖的编排原语。

但是通过与 Conductor、OpenClaw、Codex 的集成，gstack 支持 **leader-worker 模式**（Conductor 管理多个 worktree 的并行 gstack 会话）和 **outside-voice 模式**（多模型共识推荐、用户决策）。
