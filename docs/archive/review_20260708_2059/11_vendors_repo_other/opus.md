## 当前模型判断依据
- 主会话 powered by `default_opus`，继承主会话模型。

## 审阅范围
- `docs/vendors_analyze/vendors_repo/everything-claude-code.md` (ECC)
- `docs/vendors_analyze/vendors_repo/mattpocock_skills.md` (mattpocock_skills)
- `docs/vendors_analyze/vendors_repo/superpowers.md` (superpowers)
对比基准：`docs/omni_powers_design.md`。

## 高优先级问题（CRITICAL / HIGH）

### 1. 领域模型与决策记录文件重叠冲突
- **位置**：`mattpocock_skills.md` §3.1, §4.1 (`CONTEXT.md`, `ADR-FORMAT.md`)
- **现象**：Matt 技能强依赖 `CONTEXT.md` 记录领域术语，依赖 ADR 记录架构决策。这与 omni_powers 三区制中 `op_blueprint/domain.md` (术语) 及 `op_record/decisions.md` (决策) 存在命名、结构与功能重叠。
- **影响**：若同时运行或参考，会导致项目根目录产生同义不同名的冗余文档，导致 agent 读入冲突的真相源，破坏 omni_powers 生效规格与工单分离的契约。
- **建议**：在参考或继承 Matt 技能时，必须在配置层将 `CONTEXT.md` 输出重定向至 `op_blueprint/domain.md`，将 ADR 转换为 `op_record/decisions.md` 格式，删除根目录冗余文件。
- **置信度**：High
- **优先级**：HIGH

### 2. SessionStart 全文注入机制导致 Token 浪费与 subagent 失效
- **位置**：`superpowers.md` §4.1 (`using-superpowers`), `everything-claude-code.md` §4.1 (`session-start-bootstrap.js`)
- **现象**：superpowers 在每次 `startup|clear|compact` 时强行注入 `using-superpowers` 全文 (约 600-800 tokens)。ECC 注入 session 历史与 instincts (约 3000-4000 tokens)。
- **影响**：违反 omni_powers “护栏按需付费”原则。且 omni_powers 设计已明确 "hook 对 subagent 全量失效"，在子代理执行中此类 runtime 注入无法生效，存在安全与可靠性漏洞。
- **建议**：淘汰 runtime大段 context 强灌模式。将规程与铁律静态化写入 `agents/*.md` 的 System Prompt 约束。subagent 的输入完全由 leader 调度并通过文件/指针显式传递，不依赖全局 session hook 注入。
- **置信度**：High
- **优先级**：HIGH

## 中低优先级问题（MEDIUM / LOW）

### 3. ECC 技能库过于庞大导致上下文污染与违反 YAGNI
- **位置**：`everything-claude-code.md` §3.1 (277个 Skills)
- **现象**：ECC 包含大量特定行业或非通用开发的技能 (如 `defi-amm-security`, `homelab-network`, `energy-procurement` 等)。
- **影响**：如果无差别引入或扫描，会严重污染 agent 的 runtime 技能发现列表，增加不需要的 context 开销，违反 omni_powers 简洁优先与 YAGNI 原则。
- **建议**：建立 explicit ignore 清单，或在 `install.sh` 中通过 `--profile minimal` / `--modules core` 强制限制，只允许加载核心开发工作流 skill。
- **置信度**：High
- **优先级**：MEDIUM

### 4. 临时工作区与 progress 记录路径冲突
- **位置**：`superpowers.md` §4.2, §7 (`.superpowers/sdd/`, `progress.md`)
- **现象**：superpowers 将 task-brief、report、diff 及 progress ledger 存放在独立的 `.superpowers/sdd/` 临时工作区。
- **影响**：与 omni_powers 三区制中 `op_execution/tasks/` 及 `op_execution/acceptance/` 规划的统一流动工作区冲突，造成多套元数据并存。
- **建议**：在重构或集成 SDD 时，必须废除 `.superpowers/sdd/` 物理目录，将 brief/report 交接逻辑完全映射到 `docs/omni_powers/op_execution/` 相应路径下。
- **置信度**：High
- **优先级**：MEDIUM

### 5. Review 阶段并行 sub-agent 带来的并发与写入冲突
- **位置**：`mattpocock_skills.md` §4.4 (`code-review`)
- **现象**：Matt 的 review 机制启动并行两个 sub-agent (Standards + Spec) 进行双轴审查。
- **影响**：虽然实现了上下文隔离，但多次并行派发在 Claude Code 中 token 开销翻倍，且与 omni_powers 目前“单线程串行执行、主会话唯一 review.md 写入”的物理结构冲突。
- **建议**：omni_powers 维持单 reviewer subagent 串行双裁决，仅在提示词 (system prompt) 中隔离“规格合规”与“测试可信”两个维度的判断逻辑，不引入物理并行派发。
- **置信度**：Medium
- **优先级**：LOW

## 改进建议
1. **归档非核心资料**：将 `mattpocock_skills.md` 和 `superpowers.md` 中的具体调试 (如 `diagnosing-bugs` 6阶段)、TDD 铁律、Socratic 设计对话等优秀方法论提炼进 omni_powers 的 `agents/` 或 `docs/omni_powers_design.md` 后，将这三个 vendor 描述文件移入 `docs/archive/` 归档。
2. **规范化基线工具与脚本**：学习 `superpowers.md` 提取 `task-brief` 与 `review-package` 脚本的做法，在 `scripts/` 中实现确定性的 diff 提取与 brief 生成，避免 LLM 在主会话中自行执行复杂的 git 命令。

## 不确定项 / 可能误报
- **关于 ECC2 Rust TUI 与 SQLite 状态库的定位**：ECC2 (`everything-claude-code.md` §4.5) 使用 Rust + SQLite 进行本地状态持久化。omni_powers 目前仅依靠轻量级的 `tasks_list.json` 进行机读状态管理。若未来 omni_powers 引入更复杂的依赖拓扑，可能需要参考其 SQLite 架构，但当前阶段认为其过重，列为低度参考。
