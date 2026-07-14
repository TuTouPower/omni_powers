# 审阅报告：vendors_repo 其他参考资料（haiku 视角）

> **审阅目标**：`docs/vendors_analyze/vendors_repo/everything-claude-code.md`、`mattpocock_skills.md`、`superpowers.md`
> **核心参考**：`docs/omni_powers_design.md`
> **审阅维度**：是否仍服务 design、是否与现行设计冲突、是否需要归档/索引/去重
> **模型**：haiku（用户授权多模型审阅）
> **源文件**：只读，仅写本报告

---

## 总体判断

三份文件属于 `vendors_analyze/vendors_repo/` 横向参考资料库，按统一模板（概览/安装/工具全景/核心工具详解/文件规范/SessionStart 注入/状态管理/编排模式 8 节）生成，服务于 design 的"借鉴来源与决策背景"角色，不进运行时上下文。

design 正文**零引用**这三个 vendor（已自洽）。`docs/op_decisions.md` D16 明确记录 mattpocock 的 `grill-me` 曾被借鉴、后由 `opinit blueprint-generator` 替换——证明这三份文件具有**决策溯源档案价值**，不宜简单归档废弃，但需维持其作为"历史背景"而非"现行参考"的清晰边界。

三份文件内容质量整体高、信息密度足、术语边界标注基本到位。发现 6 类问题，无阻断性冲突。

---

## 问题清单

### 问题 1：everything-claude-code.md 缺失术语边界标注

- **位置**：`docs/vendors_analyze/vendors_repo/everything-claude-code.md` 全文
- **现象**：mattpocock_skills.md（§1 末）与 superpowers.md（§4.2/§4.3 多处）均带 vendor 术语边界标注（如"superpowers vendor 状态，不适用于 omni_powers 当前 implementer 状态集"、"vendor 分发机制，不是 omni_powers 当前安装模式"），共 4 处。everything-claude-code.md 标注数为 0（grep 统计），全文未声明 ECC 的 SessionStart/instinct/continuous-learning 等概念与 omni_powers 的关系。
- **影响**：读者（含未来 leader/agent）可能误以为 omni_powers 提供 ECC 的 SessionStart 注入或 instinct 机制，或误把 ECC 的 67 agent / 277 skill 当作 omni_powers 推荐方案。omni_powers design 明确不走"全家桶"路线（design §0 原则12"护栏按需付费，定期做减法"），但文件未点明这一立场分歧。
- **建议**：在 §1 概览末或 §8 编排模式末加一段术语边界声明，参照 mattpocock_skills.md:12 的写法，点明：(1) ECC 的 SessionStart 重注入/instinct/continuous-learning 均**非** omni_powers 现行机制；(2) omni_powers 的记忆持久化走 `tasks_list.json` + `leader_checkpoint.md` + `decisions.md`（design §1/§2.4），不依赖跨会话 instinct；(3) ECC 的 leader-worker 与 omni_powers 的 leader-worker 形似但语义不同（omni_powers leader 是主会话单点、串行 task、merge gate 唯一写入口，design §3.4）。
- **置信度**：高（标注缺失是事实，对照另两份文件可验证）
- **优先级**：MEDIUM（不影响运行时，但影响资料库可读性与防误读）

### 问题 2：superpowers.md §4.2 标题疑似笔误"sun_agent-driven-development"

- **位置**：`docs/vendors_analyze/vendors_repo/superpowers.md:178`（§4.2 标题行）
- **现象**：标题写作 `### 4.2 sun_agent-driven-development（SDD，核心执行引擎）`，而正文及全文其他位置（§3 表、§4.1、§8）均用 `subagent-driven-development`（无下划线前缀 `sun_`）。repo 实际 skill 目录名也是 `subagent-driven-development`（§5 目录结构可证）。
- **影响**：明显的字符级笔误（`sub` → `sun_`），破坏标题检索与交叉引用一致性。若未来有脚本/agent 按标题索引 vendor 资料，会产生漏匹配。
- **建议**：改为 `### 4.2 subagent-driven-development（SDD，核心执行引擎）`。
- **置信度**：高（字符级事实）
- **优先级**：LOW（单字符修正，但属于正确性问题）

### 问题 3：mattpocock_skills.md 引用 `/opintake` 需确认版本同步

- **位置**：`docs/vendors_analyze/vendors_repo/mattpocock_skills.md:12`
- **现象**：原文"omni_powers 当前需求入口是 `/opintake`"。经核对 design，`/opintake` 是 heavy 需求入口（design §4.1、CLAUDE.md 快速开始一致），引用本身正确。但该行写于早期，未覆盖 lite 入口 `/oplintake`（design §5.6/§4.1 共 3 个需求入口：opintake/oplintake）。vendor 文件作历史背景资料，单提 heavy 入口可接受，但读者可能误以为 omni_powers 只有一个需求入口。
- **影响**：轻微。vendor 资料的核心职责是描述 vendor 而非 omni_powers，omni_powers 入口信息应以 design/CLAUDE.md 为准。此处仅作边界标注，若要完整可补 lite 入口。
- **建议**：可选项——将该行改为"omni_powers 当前需求入口是 `/opintake`（heavy）/ `/oplintake`（lite）"，或保持现状（边界标注非该文件核心职责）。倾向后者（降低维护成本，避免 vendor 资料随 omni_powers 演进频繁改动）。
- **置信度**：高（引用正确性已核实）
- **优先级**：LOW（非错误，仅完整性可提升）

### 问题 4：三份文件与 overview.md/spec_and_plan_comparison.md 内容重复

- **位置**：
  - everything-claude-code.md §3（工具全景）、§4.1（SessionStart）、§7（状态管理）与 overview.md §一（横向对比表 ECC 行）、§四（状态管理策略对比：ECC JSONL 事件溯源）、§五（记忆持久化对比）高度重叠
  - superpowers.md §4.2（SDD）、§6（SessionStart 注入）、§7（progress ledger）与 spec_and_plan_comparison.md §2.4（superpowers spec/plan）、overview.md §三/§四/§五多处重叠
  - mattpocock_skills.md §4.1（grill-with-docs）、§8（编排）与 spec_and_plan_comparison.md §2.10、deep-discussion-notes.md §"和 mattpocock_skills 的本质区别"重叠
- **现象**：vendor_repo 单体文件与 overview/comparison/deep-discussion 三份聚合文件存在大段语义重复。单体文件负责"全量细节"，聚合文件负责"横向对比摘要"，职责本应互补，但实际单体文件的§概览/§编排与聚合文件的对应段落重复度达 40-60%。
- **影响**：(1) 维护成本——vendor 概念更新时需同步多处；(2) 信噪比——读者浏览资料库时重复内容稀释关键信息。但这是参考资料库的常见取舍（单体详尽 vs 聚合可对比），非设计缺陷。
- **建议**：不做强制去重（单体文件的自足性有价值）。建议在 `vendors_repo/` 目录加一个 `README.md`（或 overview.md 头部补一段）说明阅读路径："先看 overview.md 横向对比 → 按需进入 vendors_repo/{repo}.md 看单体细节 → spec_and_plan_comparison.md 看 spec/plan 维度专项对比 → deep-discussion-notes.md 看讨论补充"。明确分层，读者各取所需。
- **置信度**：中（重复度是定性判断，非精确测量）
- **优先级**：LOW（改善体验，非正确性问题）

### 问题 5：三份文件未声明"快照时效性"，可能被误读为持续权威

- **位置**：三份文件均无生成时间戳或"截至 XXXX-XX-XX 状态"声明（superpowers.md:431 有"分析完成时间: 2026-07-02"是唯一例外；另两份无）。
- **现象**：
  - everything-claude-code.md §1 成熟度写"Star 数 211.9K+（采集时量级）"、版本"v2.0.0 (2026-06)"——有量级限定词但无采集日期
  - mattpocock_skills.md §1 写"约 50 个 commits，时间跨度 2026-06-17 至 2026-07-01"、"当前 v1.0.1"——有相对时间但无采集日期
  - superpowers.md §1 写"版本 6.1.0"、末尾"分析完成时间: 2026-07-02"——最完整
- **影响**：vendor 仓库持续演进（ECC 周更、mattpocock 两周 50 commits），无采集日期的文件会随时间变为过期信息。omni_powers 借鉴 vendor 时若误读为当前状态，可能基于过期信息做设计判断。
- **建议**：统一在每份文件 §1 概览开头加一行 `> 快照时间：YYYY-MM-DD（vendor 持续演进，本文件为时点快照）`。superpowers.md 已有，补另两份。
- **置信度**：高（时效性标注缺失是事实）
- **优先级**：MEDIUM（影响设计决策的可追溯性，成本低）

### 问题 6：三份文件未索引进 design 的任何引用链，存在"孤儿资料"风险

- **位置**：vendors_repo/ 目录整体
- **现象**：design.md / CLAUDE.md / RULES.md / op_decisions.md 正文均无指向 `vendors_repo/` 具体文件的链接。op_decisions.md D16 提到"grill-me"但未链接 mattpocock_skills.md。vendors_analyze/overview.md 是唯一索引者（横向对比表指向 vendors_repo/）。读者从 design 出发，无法发现这些资料的存在，除非主动浏览 docs/vendors_analyze/。
- **影响**：(1) 孤儿风险——随项目演进，这些资料可能被遗忘，既不维护也不清理；(2) 价值未兑现——vendor 的借鉴价值（如 ECC 的 install-state 机制、superpowers 的 progress ledger 思路、mattpocock 的 domain-modeling 词汇）无法在设计讨论时被自然唤起。
- **建议**：两步。(1) 在 CLAUDE.md 的"相关文档"表加一行：`| 厂商参考资料库 | docs/vendors_analyze/vendors_repo/（10 份单体 + overview 横向对比） |`（当前 CLAUDE.md "相关文档"表已有"厂商分析 | docs/vendors_analyze/overview.md"，但指向单体库的入口缺失）；(2) 在 op_decisions.md D16"grill-me"行加括注 `（详见 docs/vendors_analyze/vendors_repo/mattpocock_skills.md §4.1）`，建立首个反向索引锚点。后续涉及 vendor 借鉴的决策记录沿用此模式。
- **置信度**：高（索引缺失是事实，可 grep 验证）
- **优先级**：MEDIUM（提升资料库可达性，低成本高收益）

---

## 与 design 的一致性核验（无冲突项，记录备查）

逐条核验三份文件描述的 vendor 概念与 omni_powers design 的关系，确认无"现行设计冲突"（仅存在"借鉴后被替换"的历史关系，已由 op_decisions.md 记录）：

| vendor 概念 | 文件位置 | 与 design 关系 | 说明 |
|---|---|---|---|
| ECC SessionStart 重注入 + instinct | everything-claude-code.md §4.1/§6 | **非 omni_powers 机制** | omni_powers 走 `tasks_list.json` + `leader_checkpoint.md`（design §1），不依赖跨会话 instinct；/oprun 启动读取 checkpoint 重建进度（design §0.2），非 SessionStart 强灌。design §0 原则12"按需付费"与 ECC 全家桶路线立场分歧。 |
| ECC leader-worker + agent 编排 | everything-claude-code.md §8 | **形似语义不同** | ECC 的 leader-worker 是通用编排；omni_powers 的 leader 是主会话单点 + merge gate 唯一写入口 + task 严格串行（design §3.4/§2.4），隔离强度与语义不同。 |
| superpowers SDD progress ledger | superpowers.md §4.2/§7 | **思路被参考** | omni_powers 的 `leader_checkpoint.md` + `tasks_list.json` 承担类似职责（design §1），但 omni_powers 不用 `.superpowers/sdd/progress.md` 这种 worktree 级临时文件，而是主 worktree 单副本流程文件（design §3.4）。 |
| superpowers using-superpowers 强注入 | superpowers.md §4.1/§6 | **非 omni_powers 机制** | omni_powers 不做 SessionStart 全文注入（lite 明确零注入，design §5.3/A17；heavy 走 index.md 摘要，design §1）。 |
| superpowers brainstorming HARD-GATE | superpowers.md §4.3 | **语义对应闸门 A** | omni_powers 的闸门 A（design §2/§0 原则11）承担类似"设计未批不得实现"职责，但形态不同（闸门 A 是 spec 人审，非 skill 强制 gate）。 |
| mattpocock grill-me/grill-with-docs | mattpocock_skills.md §4.1 | **曾被借鉴后替换** | op_decisions.md D16:261 明确记录"早期曾引用外部 grill-me，当前统一改为 opinit blueprint-generator"。历史关系清晰。 |
| mattpocock CONTEXT.md / ADR | mattpocock_skills.md §4.1/§7 | **语义对应 decisions.md** | omni_powers 的 `op_record/decisions.md`（design §1）承担 ADR 职责；domain 术语归 `op_blueprint/domain.md`（heavy）/ spec 内联（lite）。vendor 的 CONTEXT.md 是单体文件，omni_powers 按职责拆分。 |
| mattpocock code-review 双轴 | mattpocock_skills.md §4.4 | **思路一致** | omni_powers 的 reviewer 双裁决（design §2.4：规格合规 + 测试可信）与 mattpocock 的 Standards+Spec 双轴同构，独立验证一致性。 |

---

## 归档/索引/去重建议汇总

| 动作 | 目标 | 优先级 |
|---|---|---|
| **补术语边界标注** | everything-claude-code.md（问题1） | MEDIUM |
| **修正笔误** | superpowers.md:178 `sun_` → `sub`（问题2） | LOW |
| **补快照时间戳** | everything-claude-code.md / mattpocock_skills.md（问题5） | MEDIUM |
| **加资料库入口索引** | CLAUDE.md 相关文档表 + op_decisions.md D16 反向锚点（问题6） | MEDIUM |
| **加阅读路径说明** | vendors_repo/README.md 或 overview.md 头部（问题4） | LOW |
| **归档判断** | **不归档**——三份文件服务 design 决策溯源（D16 已证），持续参考价值在；保持 vendors_repo/ 原位 | — |
| **去重判断** | **不去重**——单体详尽 vs 聚合可对比的职责分层有价值，靠阅读路径说明解决（问题4） | — |

---

## 审阅范围与限制

- 仅审阅三份目标文件，未逐字审阅 overview.md / spec_and_plan_comparison.md / deep-discussion-notes.md（仅作交叉引用核验时局部读取）。
- vendor 仓库本身（`~/github_repo/` 下原件）未实地复核，以 vendors_repo/*.md 描述为准。
- "服务 design"的判断基于 design.md + op_decisions.md + CLAUDE.md 的交叉引用分析，未覆盖 RULES.md / skills / agents 运行时文件（这些文件按 design 定位不引用 vendor 资料）。
