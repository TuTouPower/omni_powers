# 当前模型判断依据

可观测来源：settings 顶层 model=default_model；env.ANTHROPIC_MODEL=default_model；默认档位 haiku=default_haiku[1m] / sonnet=default_sonnet[1m] / opus=default_opus[1m]；主会话 powered by default_model。current 路继承主会话。未写入任何 secret。

# 审阅范围

核心参考：`docs/omni_powers_design.md`，辅助对照：`RULES.md`、`CLAUDE.md`、`docs/op_decisions.md`、`skills/opinit/SKILL.md`。

目标文件已逐文件、逐段审阅，不抽样：

- `docs/archive/README.md`
- `docs/archive/agent_protocol_old.md`
- `docs/archive/agent_team_vs_subagent.md`
- `docs/archive/omni_powers_lite_design.md`
- `docs/archive/op_findings.md`

引用关系核查：检索了当前入口与文档/skill/agent 范围内对 `docs/archive/` 及目标文件名的引用，排除审阅报告目录与 archive 自身。

# 高优先级问题（CRITICAL/HIGH）

## HIGH-1：`agent_team_vs_subagent.md` 文件内缺少归档/废弃横幅，且同文存在相反结论

- 位置：`docs/archive/agent_team_vs_subagent.md:1-4`、`docs/archive/agent_team_vs_subagent.md:281-299`、`docs/archive/agent_team_vs_subagent.md:467-567`；当前引用：`docs/op_decisions.md:153-172`
- 现象：
  - 文件开头只有标题和来源说明，没有“已归档/仅历史参考/当前以 RULES + design 为准”的横幅。
  - 第九节结论仍写“建议：当前保持 Agent Team 方案不变”（`docs/archive/agent_team_vs_subagent.md:299`）。
  - 第十二节又写“全量迁移到 Sub Agent 的变更方案”（`docs/archive/agent_team_vs_subagent.md:467` 起），与当前 design/RULES 的“全线 Sub Agent”一致。
  - 当前 `docs/op_decisions.md:172` 仍以“详见”形式引用该归档文件第十二节，但未提醒读者该文件前半部分结论已被后续决策推翻。
- 影响：直接打开文件或从 `op_decisions.md` 跳转时，读者可能先读到“保持 Agent Team”结论，误以为当前编排仍依赖 Team/SendMessage/常驻 teammate；这与当前 design 的“leader + Sub Agent fresh dispatch”冲突。
- 建议：在文件首行标题下追加强横幅：本文为历史分析快照，最终裁决见 `docs/op_decisions.md` D15 与 `docs/omni_powers_design.md` / `RULES.md`，第九节“保持 Agent Team”已被第十二节及 D15 推翻。并在 `docs/op_decisions.md:172` 改为“历史分析背景见……第十二节；文件内早期结论已废弃”。
- 置信度：高
- 优先级：HIGH

## HIGH-2：`op_findings.md` 被当前入口列为相关文档，但文件内旧模型结论与现行模型策略相反

- 位置：`docs/archive/op_findings.md:1-4`、`docs/archive/op_findings.md:76-84`；当前引用：`CLAUDE.md:103`
- 现象：
  - `CLAUDE.md:103` 将 `docs/archive/op_findings.md` 列为“实验发现（归档）”。
  - 文件开头只写“最终规则见 RULES.md”，没有明确“已归档/历史快照/部分结论已被后续 design 推翻”的强横幅。
  - 实验 7 结论写“spawn 时必须显式传 model 参数”（`docs/archive/op_findings.md:84`）。当前 design/RULES 明确为：`OP_*_MODEL` 可配置；未设则不传 model 参数，继承主会话当前模型；dispatch 不准自行指定 model。
- 影响：当前入口仍能引导读者阅读此文件；读者可能按旧实验结论改 agent dispatch，强行显式传 model，破坏现行“未设则继承主会话”的模型策略。
- 建议：在 `op_findings.md` 顶部追加废弃横幅，并点名列出已被推翻的高风险结论：实验 7 model 参数策略、Agent Team 相关实验仅作历史。可在 `CLAUDE.md` 表格中把“实验发现（归档）”改为“历史实验发现（不作为当前规则）”。
- 置信度：高
- 优先级：HIGH

# 中低优先级问题（MEDIUM/LOW）

## MEDIUM-1：`archive/README.md` 的“agent 不应 grep 本目录”与 opinit 当前迁移流程存在例外边界未说明

- 位置：`docs/archive/README.md:3-7`；当前引用/流程：`docs/omni_powers_design.md:170`、`skills/opinit/SKILL.md:70-79`、`skills/opinit/SKILL.md:111-120`
- 现象：`archive/README.md` 写“agent 不应 grep 本目录作为当前协议依据”。但当前 design 与 opinit 明确要求 blueprint-generator 读取 `docs/archive/` + git log + 现有代码，提炼已实现功能；opinit 还会扫描 archive 中未执行计划候选。
- 影响：语义上“作为当前协议依据”是限定语，基本正确；但执行 agent 可能粗读为“任何时候都不读 archive”，从而在 opinit 迁移/提炼历史项目文档时漏读 archive，影响 blueprint 初始化质量。反向风险是未理解“不是当前协议依据”，把 archive 旧协议直接当现行规则。
- 建议：补一句例外边界：常规运行/审阅不得把本目录当现行协议；仅 `opinit` 的历史迁移、blueprint 提炼、未执行计划抽取可读取，并必须丢弃过期协议内容，以 design/RULES 为准。
- 置信度：高
- 优先级：MEDIUM

## MEDIUM-2：`omni_powers_lite_design.md` 归档横幅的合并章节指向已过期

- 位置：`docs/archive/omni_powers_lite_design.md:3`；对照：`docs/archive/README.md:13`、`docs/omni_powers_design.md:710-910`
- 现象：归档横幅写“已并入 `docs/omni_powers_design.md`（heavy + lite 合并版，见其 §13-§15）”。当前合并版 lite 章节实际为 §5；`docs/archive/README.md:13` 也写 §5。
- 影响：读者按归档横幅跳转会找不到 §13-§15，降低“以当前 design 为准”的可用性。该文件整体已明确归档，误导性有限。
- 建议：把 `§13-§15` 改为 `§5`，或写“见当前合并版 lite 模式章节（章节号以当前 design 为准）”。
- 置信度：高
- 优先级：MEDIUM

## MEDIUM-3：`omni_powers_lite_design.md` 历史内容含“spec 级 Stage 4 验收”，与现行 per-task 验收前置冲突，虽有归档横幅但未点名关键差异

- 位置：`docs/archive/omni_powers_lite_design.md:155-198`；对照：`docs/omni_powers_design.md:842-866`
- 现象：归档文档 `§7.1/§7.3` 写 Stage 4 是“整份 spec 所有 task 闭环后跑一次”，并在 task 收口后再派 evaluator。当前合并版 design 已改为 `review PASS → evaluator per-task 裸评（验收前置）→ PASS 后 leader 收口 commit/归档`。
- 影响：直接阅读归档文档中工作流段时，可能误解 lite 当前执行顺序，尤其是“验收前置 D6”这一现行关键约束。
- 建议：在顶部归档横幅补充“本文包含已废弃顺序：Stage 4 spec 级验收、旧脚本自包含方案、旧 e2e 路径等；当前以合并版 §5 为准”。不必逐段修历史正文。
- 置信度：高
- 优先级：MEDIUM

## LOW-1：`agent_protocol_old.md` 已有废弃横幅，但 Quick Reference 标题仍写“compact 恢复先读此段”

- 位置：`docs/archive/agent_protocol_old.md:3`、`docs/archive/agent_protocol_old.md:8-19`
- 现象：文件顶部已明确“已废弃”，但下一段标题仍是“Quick Reference（compact 恢复先读此段）”，且列出旧常驻 teammate、旧状态英文映射、旧 `docs/harness_*` 路径。
- 影响：顶部横幅能阻断大部分误用；但快速扫读时，标题本身仍像运行时指令。
- 建议：把标题改为“历史 Quick Reference（勿用于当前 compact 恢复）”，或在该段前再加一句“以下为旧协议原文”。
- 置信度：中
- 优先级：LOW

## LOW-2：`archive/README.md` 对 `op_findings.md` 的说明弱于实际风险

- 位置：`docs/archive/README.md:12`
- 现象：README 写“早期实验发现（部分结论可能已过时）”。实际 `op_findings.md` 至少包含与当前模型策略相反的结论，且 Agent Team 相关实验整体已是历史。
- 影响：读者可能低估旧实验结论与当前 design 冲突程度。
- 建议：改为“早期实验发现（含已被当前 design 推翻的结论，仅作决策背景）”。
- 置信度：高
- 优先级：LOW

# 改进建议

1. 统一 archive 文件首屏横幅模板：
   - “已归档/冻结历史快照”
   - “不作为当前协议或执行依据”
   - “当前入口：RULES.md + docs/omni_powers_design.md”
   - “若从 op_decisions 跳转，仅作决策背景”
2. 对仍被当前文档引用的 archive 文件，引用处加限定语：
   - `agent_team_vs_subagent.md`：只引用第十二节的迁移背景，早期 Agent Team 结论已废弃。
   - `op_findings.md`：只作历史实验记录，不作为当前模型/dispatch 规则。
3. 在 `archive/README.md` 明确 opinit 例外：opinit 可读 archive 做历史迁移/blueprint 提炼，但必须以当前 design/RULES 过滤过期内容。
4. 不建议改写 archive 正文主体。保持冻结历史，只修首屏警示与当前引用限定，能同时保留历史追溯与避免误导。

# 不确定项

1. `docs/omni_powers_design.md:170` 与 `skills/opinit/SKILL.md:78` 的 `docs/archive/` 读取，面向“使用方项目初始化”还是也覆盖本仓库自身初始化。若只面向使用方项目，`archive/README.md` 的例外说明可写得更窄。
2. `CLAUDE.md:103` 是否应继续保留 `op_findings.md` 在“相关文档”表中。若该表意图是导航所有历史材料，可保留但需强化“历史”。若意图是当前操作入口，建议移除。
