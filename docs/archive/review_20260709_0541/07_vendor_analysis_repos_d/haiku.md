## 当前模型判断依据

- `/home/karon/.claude/settings.json` 顶层 `model=haiku`；`env.ANTHROPIC_MODEL=default_model`；`env.ANTHROPIC_DEFAULT_HAIKU_MODEL=default_haiku[1m]`。
- 主会话环境提示当前由 `default_haiku[1m]` 驱动。无法读取运行时内部状态；current 路继承主会话。
- 用户明确授权调用 haiku 路多模型审阅（`model_override_authorized`）。

## 审阅范围

- `/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/superpowers.md`（全文，431 行）
- `/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/trellis.md`（全文，522 行）
- 排除 `vendors/` 与 `docs/archive/`。
- 必读上下文 `docs/omni_powers_design.md` 已读（作对照，不重复审阅）。

两份文档为厂商分析文档（第三方工具调研），审阅标准聚焦于：事实准确性、内部一致性、与项目设计的对照标注是否正确、文档完整性、可追溯性。

---

## 高优先级问题（CRITICAL / HIGH）

### H1. trellis.md §1 成熟度段落数据前后矛盾
- **位置**：`trellis.md` 第 16-17 行
- **现象**：第 16 行声称"支持 16 个 AI 编码平台"，并列出 Claude Code、Cursor、OpenCode、Codex、Kiro、Gemini、Qoder、CodeBuddy、Copilot、Droid、Pi、Devin、Antigravity、Kilo、Trae、ZCode——逐项数到 16 个。但 §8.2 双模式路由表（第 492-493 行）只列了 12+4=16 个平台，其中"Sub-agent dispatch"列出 10 个、"Inline"列出 4 个。交叉核对：`§8.2 Sub-agent` 列含 `Claude Code、Cursor、OpenCode、Gemini、Qoder、CodeBuddy、Copilot、Droid、Pi、Kiro`（10 个），`Inline` 列含 `Codex、Kilo、Antigravity、Devin`（4 个），合计 14 个，缺 `Trae` 和 `ZCode`。
- **影响**：§1 声称的 16 个平台与 §8.2 路由表实际枚举不一致（差 2 个）。读者按 §8.2 核对会怀疑数据可信度。
- **建议**：§8.2 路由表补全 `Trae` 和 `ZCode`，或 §1 明确这两个平台的归属模式（Sub-agent / Inline）。
- **置信度**：高（两处都在同一文件内，可机械核对）。
- **优先级**：HIGH

### H2. trellis.md task.json status 枚举在两处不一致
- **位置**：`trellis.md` 第 281-284 行（§4.5 状态机图）与 第 358-376 行（§5.3 task.json schema）
- **现象**：
  - §4.5 状态机图注释称"`completed` 标签目前 DEAD"，状态流转是 `planning → in_progress → archived`（无 completed 中间态）。
  - §5.3 task.json schema 注释写 `status: "planning|in_progress|completed|archived"`——把 `completed` 列为合法枚举值。
  - §7.2 又写"`planning → in_progress → archived`（直接 archive，中间无 completed 阶段）"。
- **影响**：三处对 `completed` 态的处理互相矛盾：一处标 DEAD、一处列为合法枚举、一处说不存在中间态。文档分析方若据此设计对齐方案会困惑。
- **建议**：统一为"枚举字段保留 `completed`（schema 层向后兼容），但当前工作流不产生此值（直接 archive）"，并在 §4.5 / §5.3 / §7.2 三处同步这一表述。
- **置信度**：高（同一文件内三处直接矛盾）。
- **优先级**：HIGH

### H3. superpowers.md §1 Skills 计数与 §3 表格计数矛盾
- **位置**：`superpowers.md` 第 5 行（概览）与 第 53-69 行（§3 Skills 表格）
- **现象**：
  - 第 5 行概览称"12 个自动触发的 skill"。
  - §3 Skills 表格逐行枚举共 14 行：using-superpowers、brainstorming、writing-plans、subagent-driven-development、executing-plans、test-driven-development、systematic-debugging、verification-before-completion、requesting-code-review、receiving-code-review、using-git-worktrees、finishing-a-development-branch、dispatching-parallel-agents、writing-skills。
  - §5 文件规范第 296-310 行目录树也列了 14 个 skill 目录。
  - 文末脚注（第 431 行）又称"12 个 skills"。
- **影响**：核心事实（skill 总数）在文档内自相矛盾，读者无法判断哪个数对。
- **建议**：核对实际仓库 `skills/` 目录，统一为正确数（按目录树列出应为 14）。概览与脚注同步修正。
- **置信度**：高（文档内可机械核对）。
- **优先级**：HIGH

---

## 中低优先级问题（MEDIUM / LOW）

### M1. superpowers.md §1 版本号与 §5 plugin.json 版本号需交叉标注一致性
- **位置**：`superpowers.md` 第 13 行（§1）与 第 349 行（§5 frontmatter 示例）
- **现象**：§1 写"版本 6.1.0"，§5 plugin.json 示例也写 `"version": "6.1.0"`——两处一致，无矛盾。但 §2 第 37 行 plugin.json 示例只给了 `name` 和 `version` 两个字段（省略号），与 §5 完整示例（第 347-358 行）存在重复。建议 §2 示例标注"见 §5 完整 schema"避免维护漂移。
- **影响**：低（当前一致，但两处示例容易随版本升级产生漂移）。
- **建议**：§2 plugin.json 示例加一行注释指向 §5。
- **置信度**：中。
- **优先级**：LOW

### M2. superpowers.md §4.2 SDD 状态返回值与 omni_powers 对照标注位置混乱
- **位置**：`superpowers.md` 第 188 行、第 207 行
- **现象**：第 188 行在状态枚举 `DONE/DONE_WITH_CONCERNS/BLOCKED/NEEDS_CONTEXT` 后补注"superpowers vendor 状态，不适用于 omni_powers 当前 implementer 状态集"；第 207 行在 Model 选择策略后补注"superpowers vendor 行为，不适用于 omni_powers"。这两处对照标注是**本模块审阅范围内唯一的 omni_powers 对照信息**，对项目落地有价值，但标注风格不统一（一处用括号内联、一处用分号内联），且分散在正文里容易被忽略。
- **影响**：低（信息正确，但可读性差）。
- **建议**：统一对照标注格式（如统一用 `> [omni_powers 对照: ...]` 块），或汇总到独立"§9 与 omni_powers 对照"小节。
- **置信度**：中。
- **优先级**：MEDIUM

### M3. trellis.md §1 提交数 "~50" 与 superpowers.md §1 提交数 "~50" 雷同，疑似套用模板
- **位置**：`trellis.md` 第 14 行；`superpowers.md` 第 12 行
- **现象**：两份文档都写"2026 年至今 ~50 个 commit"。trellis 还写"每日活跃合并 PR"。两个独立仓库的 commit 数恰好都是 ~50 的概率较低，可能其中一处为套用模板未核实。
- **影响**：中（影响数据可信度，但无法在不联网核实的情况下确认对错）。
- **建议**：标注数据采集日期 + 采集方式（如 `git log --oneline | wc -l` 输出），或标"截至 2026-07-02 快照"。
- **置信度**：低（仅基于巧合怀疑）。
- **优先级**：MEDIUM

### M4. trellis.md §2 symlink 策略描述与 §3 配置文件复制机制表述冗余
- **位置**：`trellis.md` 第 59 行（§2 symlink 策略）与 第 61-72 行（变更配置文件汇总表）
- **现象**：第 59 行说"不使用 symlink，所有 hooks 脚本通过文件复制写入各平台目录"，汇总表又逐行重复"复制"。信息正确但冗余。
- **影响**：低。
- **建议**：汇总表"变更方式"列可简化为只列差异项（如 settings.json 的"全量写入/merge"），复制类的不必每行标注。
- **置信度**：高。
- **优先级**：LOW

### M5. trellis.md §4.5 状态机图用 ASCII 箭头注释 DEAD 态，可读性差
- **位置**：`trellis.md` 第 281-285 行
- **现象**：状态机用 `(completed 标签目前 DEAD)` 内联注释标记死代码，但 ASCII 图本身画的是 `planning → in_progress → archived`，"completed" 在图里根本没出现，注释显得突兀。
- **影响**：低（语义可理解，但图与注释脱节）。
- **建议**：要么图里画出 completed 节点并标 `[DEAD]`，要么把注释移到图下方文字说明。
- **置信度**：高。
- **优先级**：LOW

### M6. superpowers.md §7 称"无 checkpoint 机制"但 §4.2 又讲 Progress Ledger 解决 compaction
- **位置**：`superpowers.md` 第 397-401 行（§7）与 第 206 行（§4.2 Progress Ledger）
- **现象**：§7 明确写"无 checkpoint 机制：无保存/恢复会话状态的系统"，但 §4.2 Progress Ledger 的设计目的就是"防止 compaction 后 controller 丢失状态重复分派"，§7 第 401 行也承认"仅 SDD 的 progress ledger 提供 compaction 恢复能力"。这两处表述有张力：要么 Progress Ledger 算 checkpoint（则 §7"无 checkpoint"表述不准），要么它不算（则应说明为何不归类为 checkpoint）。
- **影响**：中（读者会困惑 Progress Ledger 到底算不算状态恢复机制）。
- **建议**：§7 改为"无通用 checkpoint 机制（仅 SDD 子流程有 Progress Ledger 局部恢复）"，与 §4.2 对齐。
- **置信度**：中。
- **优先级**：MEDIUM

### M7. trellis.md §8.3 Channel 系统与核心工作流的关系交代不足
- **位置**：`trellis.md` 第 498-506 行（§8.3 Channel 系统）
- **现象**：第 506 行说"Channel 系统相对独立于核心 3-Phase 工作流，更多用于高级多 agent 协作场景"，但 §3.2 Skills 表（第 96 行）列了 `trellis-channel` skill，§3.6 CLI（第 140 行）列了 `trellis channel` 命令。Channel 作为一等公民出现在 skill/CLI 里，却在 §8 编排模式里被定性为"独立于核心工作流"。
- **影响**：低（不影响事实准确性，但读者难以判断 Channel 是否推荐用法）。
- **建议**：补一句"Channel 用于多 agent 并行协作（如 parent/child task 树的子任务派发），单 agent 线性工作流不触发"。
- **置信度**：中。
- **优先级**：LOW

### M8. superpowers.md 文末脚注 source 路径与模块审阅范围不一致
- **位置**：`superpowers.md` 第 431 行
- **现象**：脚注写 `source: /home/karon/github_repo/superpowers v6.1.0`。本模块审阅的是 `docs/vendors_analyze/vendors_repo/superpowers.md`（分析文档），不是源仓库。脚注指向的是被分析的对象仓库，表述正确，但容易与"本文档自身来源"混淆。
- **影响**：低。
- **建议**：脚注改为"被分析对象 source: ..."，与文档自身来源区分。
- **置信度**：高。
- **优先级**：LOW

### M9. 两份文档均缺少"已知局限性"小节
- **位置**：`superpowers.md` 全文；`trellis.md` 全文
- **现象**：两份分析文档结构完整（概览/安装/工具/详解/文件规范/SessionStart/状态管理/编排），但都没有"已知局限"或"不适用场景"小节。作为厂商调研，缺这一维度会导致项目方误判工具适用性。
- **影响**：中（影响调研结论的全面性）。
- **建议**：补 §9 已知局限性（如 superpowers 的 SessionStart 全文注入对 context 的开销、trellis 的 `.trellis/` 目录侵入性等）。
- **置信度**：中。
- **优先级**：MEDIUM

---

## 改进建议

1. **统一平台计数核对**：trellis.md §1 的"16 个平台"应与 §8.2 路由表逐一对齐，补全 Trae/ZCode 的模式归属；superpowers.md §1 的"10+ 个 harness"表述宽松，但建议也给出精确数。
2. **状态枚举单一真相源**：trellis.md 三处 status 枚举（§4.5 / §5.3 / §7.2）应统一，建议以 §5.3 schema 为权威源，其余两处引用。
3. **Skills 计数修正**：superpowers.md 的 12/14 矛盾需核实源仓库后统一。
4. **对照标注格式化**：superpowers.md 中两处 omni_powers 对照标注（第 188、207 行）风格不一，建议汇总到独立小节或统一块格式，便于项目方快速定位"哪些 superpowers 行为不适用于 omni_powers"。
5. **补"已知局限"维度**：两份文档作为厂商调研，建议各补一节局限性分析，提升调研决策价值。
6. **数据可追溯**：commit 数、版本号、下载量等易变数据建议标注采集日期与采集命令。

---

## 不确定项 / 可能误报

1. **H3（Skills 计数）**：概览说 12、表格列 14，但无法排除"using-superpowers 是 bootstrap 不算常规 skill"或"executing-plans 是 subagent-driven-development 的 fallback 不独立计数"的可能。若源仓库 README 自称 12，则 14 是表格多列。需核对源仓库 README 才能定论。**标注为可能误报，但文档内矛盾本身客观存在**。
2. **M3（commit 数雷同）**：两份文档都写 ~50 commit，仅基于"巧合可疑"，无法在不联网核实的情况下确认是否套用模板。可能两者确实都在 ~50 量级。
3. **M6（Progress Ledger 是否算 checkpoint）**：取决于"checkpoint"的定义边界。若严格定义为"完整会话状态保存/恢复"，Progress Ledger 确实不算（只记 task 完成行）。§7 表述技术上可成立，但读者困惑客观存在。
4. **H1（平台计数）**：§8.2 表格可能是有意省略 Trae/ZCode（这两个平台或许是后加的，尚未定模式归属）。若如此，§1 的 16 是对的、§8.2 是待补的，矛盾仍在但定性不同。
