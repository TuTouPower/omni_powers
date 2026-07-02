# Vendors 横向对比总览

> 分析对象：`vendors/` 下 10 个 Claude Code harness 相关插件/工具集
> 生成时间：2026-07-02
> 每个 repo 的详细分析见同目录下 `{repo_name}.md`
> 深度讨论补充来源：`deep-discussion-notes.md`

## 一、横向对比表

| repo | 功能定位 | Star | 工具总数（按类型） | 核心能力 | context 成本 | 成熟度 | 适用场景 |
|---|---|---|---|---|---|---|---|
| **everything-claude-code** | Agent Harness 操作系统 | 224.6K | 67 Agents / 277 Skills / 92 Commands / 48 Hooks / 20+ MCP / 16 语言规则 | SessionStart 记忆持久化 + 选择性安装 + Agent 编排 | ~3-4K tokens/session | 极高（230+ 贡献者、997+ 测试、周更） | 想要“全家桶”标准化工作流 + 质量护栏的团队 |
| **superpowers** | skill+hook 开发流程系统 | 243.4K | 12 Skills / Hooks / 自定义 Agents / CLI | bootstrap 强制注入 + SDD leader-worker 执行引擎 | 注入 using-superpowers 全文 | 中高（v6.1、113 文件、10+ harness） | 想要强纪律（TDD/brainstorm/review）的开发流程 |
| **mattpocock_skills** | 轻量 skills 集合 | 152.9K | 17 Skills（10 user + 7 model）/ Hooks / 脚本 | 路由+分层，可复用纪律/词汇表 | ~105-280 词（固定） | 中（个人维护、无 SessionStart） | 用户主导、按需引入单点技能（TDD/审查/领域建模） |
| **gstack** | 重量级全链路研发 harness | 118.7K | 59 Skills / ~80 CLI / 4 Hooks / Chrome 扩展 / MCP | 无头浏览器守护进程 + Router 分派 + 6 层安全栈 | 中（SessionStart 注入 + router） | 高（v1.58、YC CEO 维护、MIT、活跃） | 产品构思→发布监控的端到端个人/小团队研发 |
| **spec-kit** | 官方 SDD 脚手架 CLI | 117.0K | Python CLI / 10 Commands / 10 脚本 / 4 扩展 / 35+ Agent 适配 | 模板约束 LLM 输出 + Constitution 合规 + Extension hook | 无自动注入（可选扩展） | 高（GitHub 官方、每日多 PR、文档全） | 规格先行（spec→plan→tasks→implement）的标准化 SDD |
| **agent-skills** | 生产级全生命周期工程技能集 | 68.4K | 24 Skills / 8 Commands / 4 Agents / 3 套 Hooks / 7 参考检查单 | 生命周期技能（Define→Ship）+ 防借口表/红牌/验证门禁 | 注入 using-agent-skills meta | 中（Addy Osmani、20 天 50 commits、MIT） | 想要资深工程师纪律 + 验证门禁的 AI 编码流程 |
| **OpenSpec** | 规约驱动开发方法论 | 58.2K | CLI / 双轨 Skills+Commands（33 工具适配） | Delta spec（ADDED/MODIFIED/REMOVED）差异管理 | 低（skill 按需加载） | 高（近每日提交、19 docs、MIT、30+ 工具） | brownfield 增量变更、需求可审计追溯 |
| **bmad-method** | 全流程方法论框架 | 49.9K | 多 Skills / 命名角色 Agents / CLI / Python 脚本 | 三层可合并配置 + Step-file 工作流 + Party Mode | ~2-5K tokens/激活 | 高（多模块市场、17+ IDE、中英文档） | 需要固定角色 persona + 可定制方法论的团队 |
| **planning-with-files** | 计划文件驱动任务追踪 | 24.3K | Skills / 生命周期 Hooks / ~10 脚本 | 3 文件（plan/findings/progress）+ 注入引擎 + 3 模式 | 注入 plan 文件 | 中高（v3.1.3、50+ 版本、17+ IDE、MIT） | 长任务规划、跨会话恢复、gated 完成门禁 |
| **trellis** | 多平台工程框架 | 11.5K | 3 Python Hooks / 3 Agents / Skills / Commands / CLI | SessionStart+PreToolUse 上下文注入 + task 生命周期 | 500-800 tokens/session | 中（v0.6.5、AGPL、~50 commits、16 平台） | 跨 AI 编码平台、需要 task 状态机的工程团队 |

## 二、类型总览

| 类型 | 特征 | 实例 |
|---|---|---|
| **CLI 格式的开发方法论** | 终端 CLI 生成文件/目录结构，Agent 通过生成的 slash commands 执行；不常驻，不强注入 | OpenSpec、spec-kit |
| **Skill 格式的开发方法论** | 纯 `SKILL.md` 驱动，靠 SessionStart hook 注入路由/meta-skill；流程纪律强 | superpowers、agent-skills |
| **轻量级 Skill 包** | 多个独立 skill，用户按需选择；无 SessionStart 注入，无编排，不拥有流程 | mattpocock_skills |
| **重量级大规模插件包** | Agents + Skills + Hooks + Commands + Rules 全栈覆盖；SessionStart 注入记忆/升级/路由；拥有开发流程 | everything-claude-code、gstack |
| **CLI + Skill 方法论** | CLI 安装/生成 + skill 工作流；强调角色、配置、阶段推进 | bmad-method |
| **Hook 驱动工程框架** | hook 动态注入状态、上下文和阶段 breadcrumb；task 状态机是核心 | trellis |
| **文件状态机任务追踪** | 以少量 Markdown 文件作为计划、发现、进度的唯一真相源 | planning-with-files |

## 三、按维度归类

### 编排复杂度（低→高）

1. **单 Agent / 用户主导**：mattpocock_skills、OpenSpec、spec-kit、agent-skills、bmad-method
2. **单 Agent pipeline**：planning-with-files、superpowers（线性 pipeline）
3. **Leader-Worker**：trellis、superpowers（SDD）、bmad-method（Party Mode 更像同上下文圆桌）
4. **多模式混合（Router+Pipeline+Leader-Worker+DAG）**：everything-claude-code、gstack

### SessionStart 注入策略

- **重注入**：everything-claude-code（3-4K）、gstack、superpowers（using-superpowers 全文）、agent-skills（using-agent-skills meta）
- **动态轻注入**：trellis（500-800，按当前 task/git/spec/workflow 计算）
- **计划文件注入**：planning-with-files（注入 plan/progress）
- **完全不注入 / 按需加载**：bmad-method、mattpocock_skills、OpenSpec、spec-kit

### 状态管理机制

| 机制 | repo |
|---|---|
| **JSONL 事件溯源** | everything-claude-code、gstack |
| **文件状态机 / task 生命周期** | trellis、bmad-method、planning-with-files |
| **Markdown checkbox + 文件存在性** | OpenSpec、spec-kit |
| **Progress Ledger** | superpowers（SDD 专用） |
| **弱状态 / 几乎无状态** | mattpocock_skills |

### task 管理强度

| repo | task 管理 |
|---|---|
| **trellis** | 强：`task.py` CLI + 状态机 + parent/child 树 |
| **planning-with-files** | 强：`task_plan.md` / `findings.md` / `progress.md` + gated 完成 |
| **bmad-method** | 中强：memlog + manifest + sprint 状态 |
| **spec-kit** | 中：`tasks.md` checkbox + feature 状态文件 |
| **superpowers** | 中：SDD progress ledger |
| **agent-skills** | 中：planning-and-task-breakdown skill 生成 tasks |
| **OpenSpec** | 弱：change 目录和文件存在性追踪 |
| **mattpocock_skills** | 弱：不内置任务系统 |

## 四、核心差异化技术

| 能力 | repo | 说明 |
|---|---|---|
| **无头浏览器守护进程** | gstack | Bun 二进制 + Chromium + Playwright 常驻；首次 ~3s，后续 ~100ms；形成“代码→浏览器验证→修代码”闭环 |
| **Delta spec 差异管理** | OpenSpec | 只写 ADDED/MODIFIED/REMOVED，archive 时 merge 进主 spec，适合 brownfield |
| **Constitution + 模板约束** | spec-kit | `spec-template.md` 约束 LLM，不确定性强制 `[NEEDS CLARIFICATION]`，适合 greenfield 标准化 SDD |
| **三层可合并配置** | bmad-method | `base → team → user` TOML 链，用户在 `_bmad/custom/` override，不改源码 |
| **Agent 集成注册表（OOP）** | spec-kit | 每个 Agent 一个 integration 子类，扩展新 Agent 成本低 |
| **记忆持久化 + 持续学习** | everything-claude-code | JSONL 事件溯源 + instinct + SessionStart 历史注入 |
| **强纪律行为塑造** | superpowers、agent-skills | Iron Law / red flags / anti-rationalization / 验证检查单 |
| **Hook 自动注入子 agent 上下文** | trellis | PreToolUse 拦截 Agent tool，把 PRD / design / task ctx 自动塞进 prompt |
| **计划文件驱动跨会话恢复** | planning-with-files | 3 个 Markdown 文件作为长期任务锚点 |

## 五、深度讨论结论

### spec-kit vs OpenSpec

| | OpenSpec | spec-kit |
|---|---|---|
| 入口 | 聊天中 `/opsx:propose` | 终端 `specify init` 后生成 `/speckit.*` |
| 规格格式 | **Delta spec**：只写变更差异 | **完整 feature spec**：每次独立 `spec.md` |
| 迭代模式 | 多 change 并发 | 一次一个 feature，四步串行 |
| TDD | 不涉及 | 不强制，constitution 可写原则 |
| 门禁 | Agent 自觉遵循 checklist | Constitution 合规 + clarification 标记 + checklist 硬门 |
| 最适合 | brownfield 增量变更 | greenfield 新项目 / 标准化 SDD |

核心差异：OpenSpec 是“聊着聊着把变更记录下来”；spec-kit 是“先停下来写宪法和完整规格，再动手”。

### gstack vs everything-claude-code

| | everything-claude-code | gstack |
|---|---|---|
| 规模 | 67 Agents / 277 Skills / 20+ MCP | 59 Skills / ~80 CLI / 无自定义 Agent 定义 |
| 安装 | 选择性安装 | 全量安装 |
| 记忆 | SessionStart 注入摘要 + instinct + learned skills | JSONL 事件溯源，搜索 learnings/decisions |
| Agent 定义 | 67 个 | 0 个，主要靠 skill 文本和 CLI |
| 独门能力 | 大规模 agent/skill/rule 生态 | 浏览器守护进程 + UI/QA 闭环 |

核心差异：ECC 是“全栈 Agent OS”；gstack 是“带真实浏览器眼睛的研发 harness”。

gstack 浏览器能力覆盖：

| skill | 浏览器用途 |
|---|---|
| `/qa` | 打开网站、走流程、截图、发现 bug、修源码、重开验证、原子 commit |
| `/design-review` | before/after 截图对比，检查间距/对齐/颜色/动效 |
| `/investigate` | 复现 bug，抓 console / network，再回源码排查 |
| `/design-shotgun` | 爬全站 UI 组件截图，生成设计系统文档 |
| `/ship` | 部署前浏览器验证 |
| `/scrape` + `/skillify` | 页面提取数据，再编译为确定性 Playwright 脚本快速复跑 |

平台边界：强 Web；弱 iOS；无 Android / 小程序 / Flutter / React Native 原生验证。

### agent-skills vs superpowers / mattpocock_skills

| | superpowers | agent-skills | mattpocock_skills |
|---|---|---|---|
| 核心定位 | 强制纪律 + SDD leader-worker | 全生命周期工程纪律 | 轻量单点技能库 |
| 编排 | per-task 派 implementer/reviewer 子 agent | 用户编排，persona 不互调 | 用户手动选 skill |
| 流程范围 | brainstorm→plan→TDD→review→merge | Define→Plan→Build→Verify→Ship | TDD / code review / domain modeling 等单点 |
| 强制性 | 很强 | 中强 | 弱 |
| 独特结构 | Iron Law / Red Flags | 防借口表 + 红牌 + 验证检查单 | grill-with-docs / codebase-design 词汇表 |

核心差异：superpowers 更像“强制执行引擎”；agent-skills 更像“资深工程师流程手册”；mattpocock_skills 是“可插拔技能词典”。

### bmad-method

核心机制：

1. **命名角色 persona**：Mary / PM / UX Designer / Architect / Dev 等固定角色，不只是通用 reviewer。
2. **四阶段工作流**：分析 → 规划 → 方案设计 → 实施。
3. **三层可合并配置**：`base → team → user`，用户通过 `_bmad/custom/` override。
4. **Party Mode**：多个 persona 在同一上下文圆桌讨论，由 orchestrator 控节奏；不是独立 subagent 并发。
5. **不注入 SessionStart**：按需加载，用户要知道该用哪个 step-file。

与 superpowers 对比：bmad 更重角色和方法论定制；superpowers 更重纪律和自动执行。

### trellis

核心机制：

1. **SessionStart 动态注入**：活跃 task、git 状态、spec 索引、workflow 阶段，约 500-800 tokens。
2. **PreToolUse 子 agent ctx 注入**：leader 派 Agent 时，hook 自动塞入 task/prd/design ctx。
3. **UserPromptSubmit breadcrumb**：每轮注入 `[workflow-state:STATUS]`，下一步来自 `workflow.md`。
4. **task.py 生命周期 CLI**：create / start / complete / block / tree，支持 parent/child task。

关键价值：比 superpowers 少依赖 leader 手写 prompt，更多靠 hook 保证上下文一致。

### planning-with-files

核心机制：

1. **三文件状态机**：`task_plan.md`、`findings.md`、`progress.md`。
2. **三种模式**：计划模式、执行模式、恢复模式。
3. **inject-plan.sh**：把当前计划/进度注入会话，减少跨会话断裂。
4. **gated completion**：进度文件没闭环就不能宣称完成。

关键价值：极简、透明、低技术栈；适合长任务和恢复，不适合复杂多 agent 编排。

## 六、对 omni_powers 的关键启示

| 能力 | 最佳参考 | 可借鉴点 | 对 omni_powers 的建议 |
|---|---|---|---|
| 多 Agent 编排 | everything-claude-code、superpowers | leader-worker + 两阶段 review gate + 文件交接 | 保持 leader 编排，review/evaluator 分权，不让 implementer 自证完成 |
| 记忆持久化 | everything-claude-code、gstack | SessionStart 注入历史 + JSONL 事件溯源 | 只注入最小状态；重历史放文件/搜索，不要每轮全塞 |
| spec/plan 生成 | OpenSpec、spec-kit | Delta spec 差异化 + 模板约束 LLM 输出 | 采用 spec 作为唯一契约；变更用 delta/decision 记录，避免重写真相源 |
| task 生命周期 | trellis、planning-with-files | 状态机 + 跨会话恢复 + gated 完成门 | `tasks_list.json` 应继续作为执行唯一真相，并配 checkpoint 恢复 |
| 配置可定制 | bmad-method | 三层可合并配置 | 后续可引入默认/项目/用户三层模型配置，但别先做复杂化 |
| 安全护栏 | gstack | prompt 注入防御 + redact pre-push | hooks 保持最小强约束：锁区、路径、敏感操作、防误删 |
| 行为纪律 | superpowers、agent-skills | 铁律声明 + 对抗性审查 | 把纪律写进 agent prompt 和 gate，而不是靠 leader 记忆 |
| 浏览器验证 | gstack | 常驻浏览器 + QA/design-review 闭环 | Web 项目可借鉴；omni_powers 本体暂不需要内置浏览器守护进程 |
| 子 agent ctx 注入 | trellis | hook 自动补齐任务上下文 | 可用于减少 leader 派发 prompt 冗余，但要防注入过重 |
| 文件计划恢复 | planning-with-files | plan/findings/progress 三态 | omni_powers 的 `op_blueprint/op_execution/op_record` 已是更结构化版本，应继续沿用 |

## 七、快速定位

| 如果你觉得… | 可以看… |
|---|---|
| OpenSpec 太轻、不够结构化 | spec-kit |
| ECC 覆盖面广但缺浏览器验证 | gstack |
| superpowers 流程太短、想覆盖全交付管道 | agent-skills |
| 想给 AI 加“真正看到页面”的能力 | gstack |
| 需要跨 35+ Agent 工具的 spec 标准 | spec-kit |
| 想要角色化方法论和可合并配置 | bmad-method |
| 想要 hook 自动给子 agent 塞上下文 | trellis |
| 想要最小成本跨会话计划恢复 | planning-with-files |

## 八、补充整理映射

### 已有背景：四个已用 repo

| repo | 核心特征 |
|---|---|
| **ECC** | 重量级大规模插件包；leader-worker + pipeline + DAG；记忆持久化 + 持续学习 + 语言规则包 |
| **superpowers** | Skill 格式开发方法论；强制 TDD / brainstorm / review；SDD 一次一个 spec/plan |
| **OpenSpec** | CLI 格式规约方法论；Delta spec；可并发多个 change 目录 |
| **mattpocock_skills** | 轻量 skill 包；用户路由；grill-with-docs + codebase-design 词汇表 |

### 七个 repo 类型总览

原讨论中的“七个 repo 类型总览”已合并进本文 **二、类型总览** 和 **三、按维度归类**：按交付形式、是否拥有开发流程、覆盖范围、task 管理方式四个维度归类。

### 三个共同点

bmad-method、trellis、planning-with-files 的共同点：

1. 都做 task 管理，只是载体不同：memlog/manifest/sprint、`task.py` 状态机、三 Markdown 文件。
2. 都不以 spec 驱动为核心，和 OpenSpec/spec-kit 的规约线不同。
3. 都以单 agent 为主；trellis 有 leader-worker，planning-with-files 可选多 agent。

### 更新后的七项目类型总览

已扩展为 10 个 repo 的总览。新增判断维度是 **task 管理方式**，对应本文 **三、task 管理强度**。

## 九、总判断

- **最值得借鉴的底层结构**：OpenSpec 的 delta spec、spec-kit 的模板门禁、trellis 的 hook 注入、planning-with-files 的恢复锚点。
- **最值得警惕的复杂度来源**：ECC/gstack 的全家桶膨胀、bmad 的 persona 负担、superpowers 的强制技能注入 token 成本。
- **omni_powers 当前方向**：更接近“OpenSpec/spec-kit 的规格契约 + superpowers 的 leader-worker + trellis/planning-with-files 的状态恢复”。
- **不建议照搬**：gstack 浏览器守护进程、bmad Party Mode、ECC 大规模 agent 市场。它们强，但会放大安装、维护和上下文成本。
