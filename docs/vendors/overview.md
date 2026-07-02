# Vendors 横向对比总览

> 分析对象：`vendors/` 下 10 个 Claude Code harness 相关插件/工具集
> 生成时间：2026-07-02
> 每个 repo 的详细分析见同目录下 `{repo_name}.md`

## 一、横向对比表

| repo | 功能定位 | Star | 工具总数（按类型） | 核心能力 | context 成本 | 成熟度 | 适用场景 |
|---|---|---|---|---|---|---|---|
| **everything-claude-code** | Agent Harness 操作系统 | 224.6K | 67 Agents / 277 Skills / 92 Commands / 48 Hooks / 20+ MCP / 16 语言规则 | SessionStart 记忆持久化 + 选择性安装 + Agent 编排 | ~3-4K tokens/session | 极高（230+ 贡献者、997+ 测试、周更） | 想要"全家桶"标准化工作流 + 质量护栏的团队 |
| **superpowers** | skill+hook 开发流程系统 | 243.4K | 12 Skills / Hooks / 自定义 Agents / CLI | bootstrap 强制注入 + SDD leader-worker 执行引擎 | ~注入 using-superpowers 全文 | 中高（v6.1、113 文件、10+ harness） | 想要强纪律（TDD/brainstorm/review）的开发流程 |
| **mattpocock_skills** | 轻量 skills 集合 | 152.9K | 17 Skills（10 user + 7 model）/ Hooks / 脚本 | 路由+分层，可复用纪律/词汇表 | ~105-280 词（固定） | 中（个人维护、无 SessionStart） | 用户主导、按需引入单点技能（TDD/审查/领域建模） |
| **gstack** | 重量级全链路研发 harness | 118.7K | 59 Skills / ~80 CLI / 4 Hooks / Chrome 扩展 / MCP | 无头浏览器守护进程 + Router 分派 + 6 层安全栈 | 中（SessionStart 注入 + router） | 高（v1.58、YC CEO 维护、MIT、活跃） | 产品构思→发布监控的端到端个人/小团队研发 |
| **spec-kit** | 官方 SDD 脚手架 CLI | 117.0K | Python CLI / 10 Commands / 10 脚本 / 4 扩展 / 35+ Agent 适配 | 模板约束 LLM 输出 + Constitution 合规 + Extension hook | 无自动注入（可选扩展） | 高（GitHub 官方、每日多 PR、文档全） | 规格先行（spec→plan→tasks→implement）的标准化 SDD |
| **agent-skills** | 生产级全生命周期工程技能集 | 68.4K | 24 Skills / 8 Commands / 4 Agents / 3 套 Hooks / 7 参考检查单 | 生命周期技能（Define→Ship）+ 防借口表/红牌/验证门禁 | ~注入 using-agent-skills meta | 中（Addy Osmani、20 天 50 commits、MIT） | 想要资深工程师纪律 + 验证门禁的 AI 编码流程 |
| **OpenSpec** | 规约驱动开发方法论 | 58.2K | CLI / 双轨 Skills+Commands（33 工具适配） | Delta spec（ADDED/MODIFIED/REMOVED）差异管理 | 低（skill 按需加载） | 高（近每日提交、19 docs、MIT、30+ 工具） | brownfield 增量变更、需求可审计追溯 |
| **bmad-method** | 全流程方法论框架 | 49.9K | 多 Skills / 命名角色 Agents / CLI / Python 脚本 | 三层可合并配置 + Step-file 工作流 + Party Mode | ~2-5K tokens/激活 | 高（多模块市场、17+ IDE、中英文档） | 需要固定角色 persona + 可定制方法论的团队 |
| **planning-with-files** | 计划文件驱动任务追踪 | 24.3K | Skills / 生命周期 Hooks / ~10 脚本 | 3 文件（plan/findings/progress）+ 注入引擎 + 3 模式 | ~注入 plan 文件 | 中高（v3.1.3、50+ 版本、17+ IDE、MIT） | 长任务规划、跨会话恢复、gated 完成门禁 |
| **trellis** | 多平台工程框架 | 11.5K | 3 Python Hooks / 3 Agents / Skills / Commands / CLI | SessionStart+PreToolUse 上下文注入 + task 生命周期 | 500-800 tokens/session | 中（v0.6.5、AGPL、~50 commits、16 平台） | 跨 AI 编码平台、需要 task 状态机的工程团队 |

## 二、按维度归类

### 编排复杂度（低→高）
1. **单 Agent / 用户主导**：mattpocock_skills、OpenSpec、spec-kit
2. **单 Agent pipeline**：planning-with-files、superpowers（线性 pipeline）
3. **Leader-Worker**：trellis、superpowers（SDD）、bmad-method（Party Mode）
4. **多模式混合（Router+Pipeline+Leader-Worker+DAG）**：everything-claude-code、gstack

### SessionStart 注入策略
- **重注入**（记忆持久化）：everything-claude-code（3-4K）、gstack、trellis（500-800）
- **轻注入 / 无注入**：superpowers（bootstrap 全文）、planning-with-files（plan 文件）
- **完全不注入**（skill 按需加载）：bmad-method、mattpocock_skills、OpenSpec、spec-kit

### 核心差异化技术
- **无头浏览器守护进程**：gstack（唯一，~100ms/命令、70+ 命令）
- **Delta spec 差异管理**：OpenSpec（唯一，不重写整个规约）
- **三层可合并配置**：bmad-method（base→team→user TOML）
- **Agent 集成注册表（OOP）**：spec-kit（35+ Agent，加新 Agent ~80 行）
- **记忆持久化 + 持续学习**：everything-claude-code（JSONL 事件溯源 + instinct）
- **强纪律行为塑造**：superpowers（铁律/红牌表/合理化反驳）

### 状态管理机制
- **JSONL 事件溯源**：everything-claude-code、gstack
- **文件状态机（task 生命周期）**：trellis、bmad-method、planning-with-files
- **Markdown checkbox + 文件存在性**：OpenSpec、spec-kit
- **Progress Ledger**：superpowers（SDD 专用）
- **几乎无状态**：mattpocock_skills

## 三、对 omni_powers 的关键启示

| 能力 | 最佳参考 | 可借鉴点 |
|---|---|---|
| 多 Agent 编排 | everything-claude-code、superpowers | leader-worker + 两阶段 review gate + 文件交接 |
| 记忆持久化 | everything-claude-code、gstack | SessionStart 注入历史 + JSONL 事件溯源 |
| spec/plan 生成 | OpenSpec、spec-kit | Delta spec 差异化 + 模板约束 LLM 输出 |
| task 生命周期 | trellis、planning-with-files | 状态机 + 跨会话恢复 + gated 完成门 |
| 配置可定制 | bmad-method | 三层可合并 TOML |
| 安全护栏 | gstack | 6 层 prompt 注入防御 + redact pre-push |
| 行为纪律 | superpowers、mattpocock_skills | 铁律声明 + 对抗性审查 |
