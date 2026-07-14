# archive 文档审阅报告 — sonnet 视角

## 当前模型判断依据

可观测来源：settings 顶层 model=default_model；env.ANTHROPIC_MODEL=default_model；默认档位 haiku=default_haiku / sonnet=default_sonnet / opus=default_opus；主会话 powered by default_model。当前分块走 sonnet 路，独立判断，不写任何 secret。

## 审阅范围

逐文件审阅 `docs/archive/` 下 5 个文件：

1. `docs/archive/README.md` — 归档目录自述文件
2. `docs/archive/agent_protocol_old.md` — 早期多 agent 协议
3. `docs/archive/agent_team_vs_subagent.md` — Agent Team vs Sub Agent 决策记录
4. `docs/archive/omni_powers_lite_design.md` — lite 独立设计文档
5. `docs/archive/op_findings.md` — 早期实验发现

核心参考：`docs/omni_powers_design.md`（现行设计）+ `RULES.md`（前 80 行运行时协议）。同时追踪 `CLAUDE.md`、`skills/opinit/SKILL.md` 对 archive 目录的引用。

---

## 高优先级问题

### [HIGH] agent_team_vs_subagent.md 结论与现行架构直接矛盾

- **位置**：`docs/archive/agent_team_vs_subagent.md`，§九「结论」及 §八「Sub Agent 的已知致命 Bug」
- **现象**：全文基于 Agent Team 架构撰写，结论为「建议：当前保持 Agent Team 方案不变。核心原因不是 Agent Team 更好，而是 Sub Agent 的错误传播 bug（#56869 closed/not_planned + #63678 仍开启）让依赖 Sub Agent 做关键路径任务风险太高」。
- **现行事实**：全线 Sub Agent（RULES.md 首段：「全线 Sub Agent，每次 fresh dispatch」；design §2.4 与 §3.4 全用 Sub Agent + merge gate 兜底）。
- **影响**：若有读者只看到此文结论而未读现行 RULES/design，会被误导为系统仍用 Agent Team，或误以为 Sub Agent 不可靠。该文件在 archive 中缺乏「此结论已被推翻」的显式标注——仅靠文件所在目录名「archive」暗示历史状态，不够明确。
- **置信度**：高（结论与现状直接相反，有实测验证）。
- **建议**：在文件顶部（⚠️ banner 下方）追加：

```markdown
> ⚠️ **决策已变更（2026-07）**：本文结论「保持 Agent Team」在 heavy v6 重构中被推翻。
> 当前全线使用 Sub Agent（见 `docs/omni_powers_design.md` §3.4）。
> 关于 Sub Agent bug #56869/#63678/#65423——当前系统以 merge gate + reviewer 双裁决 + leader 亲验为兜底
> （不依赖 Sub Agent 的单点可靠性），实际运行中该 bug 触发概率远低于本文估计。
> Superpowers 全线 Sub Agent 并被大量用户使用的实践证明此决策可成立。
> 本文保留作为「当时技术背景下为何选 Agent Team」的决策档案。
```

### [HIGH] omni_powers_lite_design.md 节号引用漂移

- **位置**：`docs/archive/omni_powers_lite_design.md`，顶部 banner
- **现象**：banner 写「见其 §13-§15」，但现行合并版 `docs/omni_powers_design.md` 中 lite 在 **§5**。原文所指的「§13-§15」是合并版最初的章节编号（后经整体结构重排，lite 从末尾上移至 §5）。
- **影响**：读者按 §13-§15 去 design 文档查找，会找到错误位置（当前 design 无 §13-§15）。
- **置信度**：高（两个版本对照确认）。
- **建议**：将 banner 中「§13-§15」改为「§5」。

---

## 中低优先级问题

### [MEDIUM] op_findings.md 实验 1-7 全部涉及已废弃的 Agent Team 机制

- **位置**：`docs/archive/op_findings.md`，实验 1-7
- **现象**：实验 1（同名 spawn）、2（shutdown 机制）、3（config 残留）、4（tmux 面板清理）、5（上下文监控）、6（ctx_stats 可用性）、7（model 参数）全部围绕 **Agent Team 的 teammate 生命周期**。当前系统全线 Sub Agent，这些实验结论（如「spawn 前查 config」「shutdown 后必须 jq 清 config」「tmux 清理不可靠」）**不再适用于当前架构**。
- **影响**：该文件被 `CLAUDE.md` 引用为「实验发现（归档）」，粗读会以为这些实验仍有参考价值。实际只有实验 9（Superpowers 研究）对现行架构有历史参考意义。
- **置信度**：高。
- **建议**：在文件顶部（现有「基于当前 Claude Code 版本，结果可能随版本升级变化」下方）加大段标注：

```markdown
> ⚠️ **适用性警告（2026-07）**：实验 1-7 全部基于 Agent Team 的 teammate 机制，
> 当前系统已全线迁移至 Sub Agent（RULES.md / design §3.4），这些实验结论不再适用。
> 仅实验 9（Superpowers 研究）对现行架构尚有历史参考价值。
```

### [MEDIUM] agent_protocol_old.md 旧术语/旧路径/旧流程量极大，虽有 banner 但内容易误导

- **位置**：`docs/archive/agent_protocol_old.md`，全文约 550 行
- **现象**：全文充满了已废弃的内容：
  - 角色：coder / reviewer / test-reviewer / task-splitter / leader（四角色的 coder+双 reviewer 模式，非现行 implementer+reviewer+evaluator+closer）
  - 状态机：「待开始 → 进行中 → 审阅中 → 完成」，无现行「待规划」「收口中」「跳过」等态
  - 路径：全部用 `docs/harness_execution/`、`docs/harness_record/`、`docs/harness_blueprint/`、`docs/harness/` 旧路径
  - 通信：SendMessage + 标记文件 + task_review.js，非现行 Sub Agent dispatch
  - 并发：leader 手动 worktree + 波次 DAG，非现行严格串行
  - 依赖机制：`blocked_by` 用中文值（`"key"`/`"domain"`/`"quality"`/`"spawn"`），现行用 `"resource"`/`"quality"`/`"spawn"`
  - 测试矩阵：无现行 §3.1 可写性矩阵与行为层/结构层分层
  - blueprint：`docs/harness_blueprint/specs/` 按功能聚合，非现行分层（生效 vs 工作 spec）模型
- **影响**：文件已在顶部标注「⚠️ 已废弃」，且 `docs/archive/README.md` 有充分告警，但 550 行废弃内容的体量使得「只看 banner 就能免疫误导」的假设偏乐观——特别是紧凑恢复场景 leader 上下文被 compact 清空后，若错误地参照了本文件，会造成严重偏航。
- **置信度**：高。
- **建议**：banner 已足够。可考虑在每段顶部追加 `> ⚠️ 本节已废弃` 标记进一步降风险（量太大，代价高于收益——当前处置已可接受）。降级为 **LOW**。

### [MEDIUM] agent_team_vs_subagent.md Superpowers 对比表中 omni_powers 列已过时

- **位置**：`docs/archive/agent_team_vs_subagent.md`，§十「和 omni_powers 逐项对比」表格
- **现象**：表格中 omni_powers 列为「混合：3 个 Agent Team + 1 个 Sub Agent」「Agent Team 常驻有开销」「review 模型：并行双 reviewer（code + test）」——均不反映现行架构。
- **影响**：低（读者应能理解这是历史对比）。但文件末尾 §十二「全量迁移到 Sub Agent 的变更方案」与现行架构高度吻合——读者可能困惑「迁移方案」为何还放在 archive。
- **置信度**：高。
- **建议**：在对比表上方加注「此列为 omni_powers 2026-06 架构（Agent Team），非现行 Sub Agent 架构」。

### [MEDIUM] archive 目录内文件缺乏统一的「被谁取代 / 去哪找现行版本」元数据

- **位置**：`docs/archive/` 全目录
- **现象**：各文件的 banner 写法不一致——`agent_protocol_old.md` 有「当前编排依据见 `RULES.md`」；`omni_powers_lite_design.md` 有「已并入 `docs/omni_powers_design.md`」；`agent_team_vs_subagent.md` 只写日期无取代指向；`op_findings.md` 只写「最终规则见 RULES.md」但不区分哪些实验结论仍有效。
- **影响**：读者在 archive 中看完某文件后，缺少统一的「去哪找现行版本」出口。
- **置信度**：中。
- **建议**：在 `docs/archive/README.md` 中增加一个映射表：

```markdown
| 归档文件 | 现行位置 |
|---|---|
| agent_protocol_old.md | RULES.md（运行时）+ design §2-§3（机制） |
| agent_team_vs_subagent.md | RULES.md §角色拓扑 + design §3.4 |
| omni_powers_lite_design.md | design §5（已合并） |
| op_findings.md | RULES.md（运行时规则）；Agent Team 实验 1-7 已废弃 |
```

### [LOW] archive/README.md 提到「agent 不应 grep 本目录」，可扩至「不应读取」

- **位置**：`docs/archive/README.md` 第 7 行
- **现象**：当前写「agent **不应 grep 本目录**作为当前协议依据」，但 agent 直接 Read 单文件也属于将其作为协议依据的行为。
- **影响**：极小——「不应 grep」已表达意图，扩至读取属锦上添花。
- **置信度**：高。
- **建议**：改为「agent 不应读取或 grep 本目录」。

### [LOW] op_findings.md 在 CLAUDE.md 中被引用为「实验发现（归档）」——标注已够

- **位置**：`CLAUDE.md` 第 103 行
- **现象**：CLAUDE.md 的「相关文档」表中有 `docs/archive/op_findings.md | 实验发现（归档）`。标注为「归档」已充分传达其历史属性，不做修改。
- **影响**：无。
- **置信度**：高。
- **建议**：维持现状。

### [LOW] agent_protocol_old.md 中「英文/中文状态映射」仍用旧映射

- **位置**：`docs/archive/agent_protocol_old.md` 第 13 行
- **现象**：`pending=待开始 / coding=进行中 / reviewing=审阅中 / done=完成 / blocked=阻塞`——现行状态枚举已完全重构（见 design §1.1 状态表，ASCII 机读值 + 中文渲染层分离）。
- **影响**：极低（文件整体已废弃）。
- **置信度**：高。
- **建议**：无需处置——文件顶部 banner 已明确声明「文中英文状态映射（pending/coding 等）已不再使用」。

---

## 改进建议

1. **统一 archive 文件 banner 格式**：建议所有 archive 文件遵守统一模板：
   ```markdown
   > ⚠️ **已归档（<日期>）**
   > - 现行版本：<指向现行文件的路径>
   > - 归档原因：<一句话>
   > - 适用性范围：哪些章节仍有参考价值 / 哪些已完全过时
   ```
   当前五份文件的 banner 写法差异大，一致性低。

2. **archive/README.md 增加「现行版本映射表」**（见上文 [MEDIUM] 建议）。

3. **agent_team_vs_subagent.md 的 Superpowers 对比保留价值明确化**：该文件 §十-§十二 的「全量迁移到 Sub Agent 的变更方案」实际上**已经被采纳并落地**——可在 archive README 中将其标注为「迁移设计参考——已落地」，让后续读者知道这不是未执行的提案。

4. **archive 目录与现行设计的交叉引用完整性检查**：当前 `docs/omni_powers_design.md` §1.3 提到 blueprint-generator 从 `docs/archive/` 提取内容——这是对 archive 的唯一功能性引用。`skills/opinit/SKILL.md` 也引用了 archive 作为输入源。这两处引用合理（archive 可能含用户项目的历史文档，非本系统自身的 archive），无需改动。

---

## 不确定项

### [UNCERTAIN] op_findings.md 实验 8 是否存在

- **观察**：`op_findings.md` 中实验编号为 1、2、3、4、5、6、7、9——**缺实验 8**。
- **推测**：实验 8 可能被删除、被合并到其他实验、或原计划未写。
- **置信度**：低（无法从存档本身判定原因）。
- **建议**：如有记录，考虑补一个注释说明实验 8 的去向。不影响 archive 作为历史快照的完整性。

### [UNCERTAIN] agent_team_vs_subagent.md §十一「上下文继承机制」的断言在 Sub Agent 迁移后是否需要更新

- **观察**：§十一基于官方文档核对了 Sub Agent vs Teammate 的上下文加载差异，并得出结论「Sub Agent 和 Teammate 的上下文几乎一样」。这个分析对理解为什么可以安心迁移到 Sub Agent 有正面价值。但当前系统已全线 Sub Agent，本节是否应移到 design doc 而非留在 archive？
- **置信度**：中。
- **建议**：考虑将 §十一的关键内容（三者的上下文继承对比表）摘录到 design doc 或 RULES.md 的附录中，作为「为什么用 Sub Agent 而非 Agent Team」的技术依据。当前完全留在 archive 中可能被忽略。
