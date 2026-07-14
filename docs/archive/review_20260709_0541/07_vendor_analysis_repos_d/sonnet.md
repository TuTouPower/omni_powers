# Sonnet 视角审阅报告

## 当前模型判断依据

`~/.claude/settings.json` 顶层 `model=haiku`；`ANTHROPIC_DEFAULT_SONNET_MODEL=default_sonnet`；`env.ANTHROPIC_MODEL=default_model`。主会话由 `default_model` 驱动。当前审阅路继承会话模型，定位为 sonnet 视角。

## 审阅范围

仅审阅以下两个文件，排除 `vendors/` 与 `docs/archive/`：

- `/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/superpowers.md`（432 行）
- `/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/trellis.md`（522 行）

已完整阅读设计文档 `docs/omni_powers_design.md` 作为上下文参考。

---

## 高优先级问题（CRITICAL / HIGH）

无。

---

## 中低优先级问题（MEDIUM / LOW）

### MEDIUM-1：superpowers.md skill 数量前后矛盾

- **位置**：`superpowers.md` 第 5 行（概览段）与第 52-69 行（工具全景表格）
- **现象**：第 5 行声称"通过 12 个自动触发的 skill 覆盖……全流程"，但第 3 节的技能表中实际列出了 **14 个 skill**（using-superpowers / brainstorming / writing-plans / subagent-driven-development / executing-plans / test-driven-development / systematic-debugging / verification-before-completion / requesting-code-review / receiving-code-review / using-git-worktrees / finishing-a-development-branch / dispatching-parallel-agents / writing-skills）。
- **影响**：读者无法确定 superpowers 到底提供多少 skill。若数据来自不同版本（v6.1.0 可能有 14 个，早期版本 12 个），应注明版本对应关系；若概览数字为笔误，应修正为 14。
- **建议**：核实 superpowers v6.1.0 的实际 skill 数量，统一概览与工具全景两处的数字。如果某些 skill 不算"自动触发"（如 writing-skills 需手动调用），应在概览段加以区分说明。
- **置信度**：高
- **优先级**：MEDIUM

### MEDIUM-2：superpowers.md 标题 typo—"sun_agent" 应为 "subagent"

- **位置**：`superpowers.md` 第 177 行，`### 4.2 sun_agent-driven-development（SDD，核心执行引擎）`
- **现象**：标题中 `sun_agent` 是明显拼写错误，应为 `subagent`。正文内后续引用均为正确的 `subagent-driven-development`。
- **影响**：typogray 级别，不影响理解，但作为正式分析文档应保持准确。
- **建议**：修正为 `subagent-driven-development`。
- **置信度**：高
- **优先级**：MEDIUM

### MEDIUM-3：trellis.md skill 目录数量与 skill 列表不一致

- **位置**：`trellis.md` 第 52 行（安装机制第 5 步）与第 87-103 行（Skills 表格）
- **现象**：安装章节称"写入 `.claude/skills/` 下 13 个 skill 目录"，但第 3.2 节 Skills 表格列出了 18 个 skill（12 个 trellis-* + 1 contribute + 1 first-principles-thinking + 1 python-design + 3 个独立 gitnexus 入口，即 gitnexus-* 共 6 个=18）。数字 13 可能是将 gitnexus 系列计为 1 个父目录的结果（12 + 1 = 13），但文档内未解释分组方式。
- **影响**：读者可能误认为 trellis 只提供 13 个 skill 目录。对 vendor 能力评估的准确性有轻微损耗。
- **建议**：在安装章节注明"13 个 skill 目录（含 gitnexus 系列共享一个父目录）"，或在 Skills 表格前加总计数说明。
- **置信度**：中
- **优先级**：MEDIUM

### LOW-1：superpowers.md 概览中"自动触发"语义不精确

- **位置**：`superpowers.md` 第 5 行
- **现象**：称所有 12 个 skill "自动触发，无需用户手动调用"。实际上部分 skill（如 `writing-skills`、`dispatching-parallel-agents`）在 superpowers 的设计中是 conditional trigger——需匹配特定场景才触发，并非任何操作都无条件触发。此外 `executing-plans` 是 `subagent-driven-development` 的替代方案，二者不会同 session 触发。
- **影响**：读者可能产生"14 个 skill 每次会话都加载"的误解。superpowers 实际机制是通过 description 字段做关键词匹配触发，非全量加载。
- **建议**：将"所有 skill 自动触发"改为"skill 通过 description 字段做关键词匹配自动触发"，并注明两两互斥的替代关系（subagent-driven-development / executing-plans）。
- **置信度**：中
- **优先级**：LOW

### LOW-2：trellis.md 概览未提及 Python 依赖

- **位置**：`trellis.md` 第 5-9 行（概览段）与第 33 行（安装机制）
- **现象**：概览段总结 trellis 定位时未提及它对 Python >= 3.9 的硬依赖。第 33 行（安装机制）有写到"需要 Python >= 3.9"，但概览段的"设计哲学/解决什么问题"中缺少这一约束。相比 superpowers 的"零外部依赖"，trellis 的 Python 运行时依赖是一个有意义的差异点。
- **影响**：快速扫读概览的读者可能忽略 trellis 的 Python 依赖要求，影响技术选型判断。
- **建议**：在概览段末尾补充一句"运行时依赖：Node.js（npm 全局安装）+ Python >= 3.9（hook 脚本与 task 脚本）"。
- **置信度**：高
- **优先级**：LOW

### LOW-3：trellis.md 状态机 dead code 标注可更明确

- **位置**：`trellis.md` 第 280-291 行（状态机图）
- **现象**：状态机图中标注了 `completed` 标签"目前 DEAD"，正文第 291 行解释"completed：目前 dead code，task archive 时一并完成"。这个说明正确，但仅出现在流程图中、未在 §7.2 Task 状态一节复述。读者如果先读 §7.2 再回头看 §4.5，可能最初以为状态机有三个活跃状态。
- **影响**：轻微理解障碍，不影响最终结论。
- **建议**：在 §7.2 的"状态机"一行补充"（completed 态为预留 dead code，实际 archive 直接从 in_progress 跳转）"。
- **置信度**：高
- **优先级**：LOW

---

## 改进建议

1. **两文件添加交叉对比段**：当前 superpowers.md 和 trellis.md 各自独立，没有对比。建议在两个文件末尾（或另起独立对比文件）各附一段与 omni_powers 的差异映射——例如 superpowers 的 progress ledger 对标 omni_powers 的 tasks_list.json + leader_checkpoint，trellis 的 SessionStart 注入对标 heavy 的 SessionStart hook、lite 则无此机制。这比正文内零星括号注（如"不适用于 omni_powers"）更具导航价值。

2. **统一"分析完成时间"标注**：两个文件末尾均有 `分析完成时间: 2026-07-02`。若文件后续有更新，建议在头部加 frontmatter `last_updated` 或版本号，避免读者误以为分析数据冻结在 7 月 2 日。

3. **trellis.md 补充卸载/回滚说明**：trellis.md 在 §2 安装机制中详细列出了修改的文件清单（settings.json / CLAUDE.md / hooks / agents / skills / commands），但未提及 `trellis uninstall` 命令是否完整回滚这些修改。实际上 §3.6 有列出 `trellis uninstall`，建议在安装机制末尾加一句"卸载：`trellis uninstall` 可清理注入块与生成文件（详见 §3.6）"以完成闭环。

4. **superpowers.md 补充 eval 套件细节**：概览段提到"有专门 eval 套件（superpowers-evals），含 tmux 驱动的实际 session 测试"——这在评估 vendor 测试可信度时是关键信息，但正文未展开。建议在 §3 或 §4 增加一小段说明 eval 套件的覆盖范围（覆盖哪些 skill / 测试方式 / 是否 CI 集成）。

---

## 不确定项 / 可能误报

1. **superpowers.md 的 12 vs 14 矛盾**：若 superpowers 的 14 个 skill 中有 2 个在 v6.1.0 标记为 experimental 或被文档归为"辅助 skill"（如 writing-skills 本身用于创建 skill、非开发流程一环），则概览"12 个覆盖全流程的 skill"可能有意排除了辅助 skill。因无法访问 superpowers 仓库核实，此条存疑。建议分析者确认后决定：修正概览数字，或补充"12 个核心流程 skill + 2 个辅助 skill"的区分说明。

2. **trellis.md 的 13 个目录**：若 trellis 实际写入的目录结构是将多个 skill 合并到共享父目录（如 `gitnexus/` 下 6 个子 skill 共享一个目录入口），则 13 个目录属实（12 个独立 + 1 个 gitnexus 父目录）。同样因无法访问仓库核实，此条存疑。

3. **trellis.md 中 `completed` 状态的 dead code 判断**：此结论基于当前分析时的代码快照（2026-07-02）。若 trellis 在 0.6.5 之后的版本激活了 `completed` 态，则文档需要更新。

4. **两文件对 omni_powers 的交叉引用**：superpowers.md §4.2 第 3c 步和 §4.2 第 207 行有两处括号注说明"不适用于 omni_powers"。这些注释本身无误，但属于分析者的判断而非 vendor 事实。如果审阅范围限定为 vendor 事实准确性，这些 omni_powers 对照注释不在审阅范围内；如果对照准确性也需审阅，则当前注释与 omni_powers_design.md 的描述一致，没有矛盾。
