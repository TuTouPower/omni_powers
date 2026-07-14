# Sonnet 审阅报告：vendors_analyze 主文档

## 当前模型判断依据

依据 `/home/karon/.claude/settings.json` 顶层 `model` = `default_model`，`env.ANTHROPIC_MODEL` = `default_model`，当前会话 powered by `default_model`。本路不设置 model 覆盖，继承主会话。settings 中 secret 已省略，不写入报告。

## 审阅范围

以 `docs/omni_powers_design.md` 为规格核心，审阅 `docs/vendors_analyze/` 三份主文档：

- `docs/vendors_analyze/overview.md`（总览，入口文档）
- `docs/vendors_analyze/deep-discussion-notes.md`（深度讨论笔记）
- `docs/vendors_analyze/spec_and_plan_comparison.md`（SPEC/Plan 机制对比）

审阅重点：定位是否清晰、与现行 design 是否冲突、是否有应归档/去重/补充索引的问题。

---

## 高优先级问题（CRITICAL / HIGH）

### H1. overview.md 第六节"对 omni_powers 的关键启示"部分建议实为已实现功能的复述

- **位置**: `docs/vendors_analyze/overview.md` 第 176-188 行，"六、对 omni_powers 的关键启示"表格
- **现象**: 表格标题为"对 omni_powers 的建议"，但多行内容描述的是 design 已经实现或正在落地的机制。例如：
  - "多 Agent 编排"行建议"leader-worker + 两阶段 review gate + 文件交接""不让 implementer 自证完成"——design §2.4（reviewer 双裁决）、§2.5（evaluator 独立验收）、§3.4（merge gate）已全部覆盖。
  - "spec/plan 生成"行建议"采用 spec 作为唯一契约；变更用 delta/decision 记录"——design 原则 1 已确立"规格是唯一契约"，§2.4 spec 变更子流程 + decisions.md 已落地。
  - "task 生命周期"行建议"tasks_list.json 应继续作为执行唯一真相，并配 checkpoint 恢复"——design §1.1 tasks_list.json 就是唯一元数据源，leader_checkpoint.md 就是恢复锚点。
  - "文件计划恢复"行建议"op_blueprint/op_execution/op_record 已是更结构化版本，应继续沿用"——这就是 design §1 的整个目录结构设计。
- **影响**: 读者（尤其是新贡献者）阅读此表时无法区分"已采用的建议"和"待评估的新建议"，降低文档作为决策参考的可操作性。若有人基于此表提 feature request，可能是在已经存在的功能上重复造轮子。
- **建议**: 表格增加一列"omni_powers 现状"，标注每行的建议是"已采用""已规划"还是"待评估"。或把此节的标题从"对 omni_powers 的关键启示"改为"vendor 能力与 omni_powers 设计对照"，以对照验证代替建议表述。
- **置信度**: 高
- **优先级**: HIGH

### H2. overview.md 未作为入口文档索引同目录下的另外两份文档

- **位置**: `docs/vendors_analyze/overview.md` 第 6 行，文件头部说明
- **现象**: 头部只写"深度讨论补充来源：`deep-discussion-notes.md`"，完全未提及 `spec_and_plan_comparison.md`（同目录下第三份、约 530 行的深度对比文档）。`spec_and_plan_comparison.md` 的 SPEC/Plan 生成机制对比是 vendors_analyze 分析体系的重要组成部分，但读者从 overview 无法得知其存在。
- **影响**: `spec_and_plan_comparison.md` 变成"幽灵文档"——存在但入口不可达。只有浏览目录才能发现它，降低了分析成果的可发现性。
- **建议**: 在 overview.md 头部增加一行引用："SPEC/Plan 生成机制对比见 `spec_and_plan_comparison.md`"。同时在本文档末尾或相关节加交叉引用（如第五节"深度讨论结论"中 spec-kit vs OpenSpec 的对比段加"详见 spec_and_plan_comparison.md"）。
- **置信度**: 高
- **优先级**: HIGH

### H3. overview.md 开篇路径假设可能不存在

- **位置**: `docs/vendors_analyze/overview.md` 第 3 行
- **现象**: 写"分析对象：`vendors/` 下 10 个 Claude Code harness 相关插件/工具集"。但项目根目录下现在没有 `vendors/` 目录。当前 vendors 分析产物直接放在 `docs/vendors_analyze/` 下（含 `vendors_repo/` 子目录存储各 repo 详细分析）。`vendors/` 可能是分析阶段使用的临时 checkout 目录，现已不存在。
- **影响**: 读者按文档描述去找 `vendors/` 目录找不到，产生困惑。
- **建议**: 改为"分析对象：10 个 Claude Code harness 相关插件/工具集（各 repo 详细分析见 `vendors_repo/`）"，去掉对 `vendors/` 路径的引用。或如果 `vendors/` 是外部路径（不在本仓库），注明它是分析用的独立 checkout 位置。
- **置信度**: 中
- **优先级**: HIGH

---

## 中低优先级问题（MEDIUM / LOW）

### M1. overview.md 与 deep-discussion-notes.md 存在内容重叠但缺乏明确的去重说明

- **位置**: 两文档多处
- **现象**: 两文档都对同类 vendor 做了对比分析。重叠内容包括：
  - spec-kit vs OpenSpec 对比（overview §V + deep-discussion §II）
  - gstack vs ECC 对比（overview §V + deep-discussion §III）
  - superpowers / agent-skills / mattpocock_skills 对比（overview §V + deep-discussion §IV）
  - 各类总览图/分类表（overview §II/§III + deep-discussion §VI/§XI）
  overview.md 声明 deep-discussion-notes.md 是"深度讨论补充来源"，但没有说明两文档的分工边界——哪些内容在 overview 里看就够了、什么时候需要进 deep-discussion-notes.md 深挖。
- **影响**: 维护时不清楚"更新一个 vendor 的结论应该改哪个文件"，可能导致两文档结论漂移不一致。
- **建议**: 在 overview.md 头部增加两文档的去重边界声明："overview 提供结论性摘要 + 对照表；deep-discussion-notes.md 提供论证过程、架构细节和决策推理。日常查阅看 overview，需要理解'为什么这么判断'时看 deep-discussion-notes.md。"
- **置信度**: 高
- **优先级**: MEDIUM

### M2. overview.md 第九节对 omni_powers 方向的总结遗漏了核心差异化特征

- **位置**: `docs/vendors_analyze/overview.md` 第 233 行，"九、总判断"
- **现象**: 总结 omni_powers 方向为"更接近'OpenSpec/spec-kit 的规格契约 + superpowers 的 leader-worker + trellis/planning-with-files 的状态恢复'"。这个概括只覆盖了三个维度，遗漏了 omni_powers 多个核心差异化特征：merge gate 写入硬底线（design §3.4）、evaluator 独立验收 + hard-pass gate（design §2.5）、heavy/lite 双模式（design §5）、closer 一段式收口（design §2.6）。这些特征在所有 10 个 vendor 中找不到等价物。
- **影响**: 对照概括不完整，可能让读者低估 omni_powers 的独特性，误以为它是现有方案的重组。
- **建议**: 补充一句："但 merge gate 写入硬底线、evaluator 独立验收的 hard-pass gate、heavy/lite 双模式是 vendor 生态中没有对应物的原创设计。"或把三个类比改为四个：增加"+ 自研的防篡改/双模式/验收体系"。
- **置信度**: 高
- **优先级**: MEDIUM

### M3. deep-discussion-notes.md trellis 节"和 omni_powers 的借鉴边界"与 design 已落地内容的状态标注不够精确

- **位置**: `docs/deep-discussion-notes.md` 第 308-311 行，"和 omni_powers 的借鉴边界"
- **现象**: 写"可借鉴：动态摘要、自动补齐 task/prd/design 上下文，降低 leader prompt 重复"。但 design §2.4"leader 上下文收敛"已明确 leader 亲跑验证统一收敛为"脚本跑 + 单行 verdict 回传"，dispatch 时 workset/depends_on 已由脚本从 tasks_list.json 提取注入。换言之，omni_powers 已经在做"自动补齐上下文"（通过 dispatch 脚本注入 + leader_checkpoint 恢复），trellis 的 PreToolUse hook 方案是另一种实现方式而非新需求。同时又写"不可借鉴为硬边界"——这很好，但对"可借鉴"部分的判断需要更精确。
- **影响**: 若有人把"动态摘要"理解为 omni_powers 尚未做到的能力而提需求，将产生重复工作。
- **建议**: 将"可借鉴"改为"已借鉴"或"方向一致——omni_powers 通过 dispatch 脚本注入 + leader_checkpoint 恢复实现类似效果，trellis 的 hook 注入机制提供了另一种实现参考"。
- **置信度**: 中
- **优先级**: MEDIUM

### M4. 三份文档均标注日期 2026-07-02，未反映后续 design 演进

- **位置**: 三份文档的头部日期标注
- **现象**: 全部标注 2026-07-02。design 从那次分析以来经历多次提交（截至当前 main 分支最新为 f9ab735），若干机制已发生变化：D6 验收前置、D3 closer_gate、D5/D9/D4-B/D12 收尾、A18 事后报告等。分析文档中的部分判断可能已不准确。例如 overview.md 写"omni_powers 本体暂不需要内置浏览器守护进程"——当时可能是对的，但如果后续 evaluator 验收通道选型扩展，这个判断可能需要重新审视。
- **影响**: 读者不能信任分析文档中的所有判断仍然有效，降低了参考价值。
- **建议**: 在两份主文档头部增加"最后验证日期"或"与 design 同步状态"标注，如"本分析基于 2026-07-02 的 vendor 快照和 design 快照，部分结论可能因 design 演进需重新审视。如发现矛盾，以 design 原文为准。"或定期跑一次快速对照（10 分钟扫 overview §VI 对照 design 各机制是否存在，更新日期戳）。
- **置信度**: 高
- **优先级**: MEDIUM

### M5. CLAUDE.md 文档索引表只指向 overview.md，未覆盖另外两份 vendors_analyze 文档

- **位置**: `CLAUDE.md` 第 219 行，"相关文档"表格
- **现象**: 表格中"厂商分析"行只写"`docs/vendors_analyze/overview.md`"。design §1.3 文档职责矩阵的定位是"每个文档单一职责，重复内容只留一份，其他文档'详见 X.md'"——但这里反过来：overview.md 应该是入口，其补充文档（deep-discussion-notes.md、spec_and_plan_comparison.md）没有被索引。
- **影响**: 与 design 文档职责矩阵精神一致——入口文档负责指引，但入口文档本身没有被充分索引到其补充文档。读者可能认为 vendors_analyze 只有 overview.md。
- **建议**: 在 CLAUDE.md 索引行中补充："详见目录下的 `deep-discussion-notes.md`（论证过程）、`spec_and_plan_comparison.md`（SPEC/Plan 对比）"。或在 overview.md 本身补充文档级目录（已在 H2 中建议）。
- **置信度**: 高
- **优先级**: LOW

### M6. spec_and_plan_comparison.md 中 vendor 术语与 omni_powers 术语的边界标注不完整

- **位置**: `docs/vendors_analyze/spec_and_plan_comparison.md` 第 464-467 行，mattpocock_skills 的 grill-me/grilling 段
- **现象**: 此处有明确的免责标注："以下是 mattpocock_skills 的 vendor 术语，不是 omni_powers 当前入口"。这是好的实践。但其他 vendor 的分析段没有类似标注。例如 superpowers 的 brainstorming、spec-kit 的 Constitution、agent-skills 的 planning-and-task-breakdown 等术语可能与 omni_powers 的闸门 A / spec / tasks_list 概念混淆。
- **影响**: 轻微——大部分术语在上下文中自明，但对不熟悉全貌的读者可能有短期混淆。
- **建议**: 无需在每处都加标注（会过度冗长），但可以在文档头部加一段总体说明："本文中所有 vendor 术语（如 brainstorming、Constitution、SDD 等）均指对应 vendor 的概念，与 omni_powers 的 spec/闸门/tasks_list 体系无关。"
- **置信度**: 低
- **优先级**: LOW

### M7. deep-discussion-notes.md 第十一节"三个共同点"的结论与 spec_and_plan_comparison.md 有细微不一致

- **位置**: `docs/deep-discussion-notes.md` 第 367-373 行，"十、三个共同点"
- **现象**: 总结 bmad/trellis/planning-with-files 三个时写"都以单 agent 为主"。但 spec_and_plan_comparison.md §2.8 明确指出 trellis 的"默认 3 种 agent 类型：implement / check / research"，支持 leader-worker 模式（"PreToolUse hook 拦截并自动将任务上下文注入子 agent"）。deep-discussion-notes.md 自己也在 §VIII 写了"trellis 有 leader-worker"。同一文档内部的表述有自洽，但"三个共同点"的概括把 trellis 归入"单 agent 为主"不够精确。
- **影响**: 读者从"三个共同点"获得 trellis 以单 agent 为主的印象，但看 trellis 详细节却发现它支持 leader-worker，产生认知矛盾。
- **建议**: 将"都以单 agent 为主"改为"默认以单 agent 为主（trellis 有 leader-worker 模式、planning-with-files 可选多 agent、bmad 的 Party Mode 为同上下文协作）"。
- **置信度**: 中
- **优先级**: LOW

### M8. deep-discussion-notes.md 第五节的快速定位表的定位模糊

- **位置**: `docs/deep-discussion-notes.md` 第 156-163 行，"五、快速定位"
- **现象**: 这个快速定位表与 overview.md 第七节的快速定位表几乎完全重复（overview 的表更长，多两行）。deep-discussion-notes.md 是"深度讨论笔记"，快速定位表更像是 overview 该承担的职责。
- **影响**: 两处维护同样的表，更新时可能漏同步。
- **建议**: deep-discussion-notes.md 的快速定位表改为指向 overview.md 相应节的引用："快速定位见 `overview.md` §VII"，避免重复维护。
- **置信度**: 高
- **优先级**: LOW

---

## 改进建议

### S1. 为 vendors_analyze 三文档建立显式的文档级索引

当前三文档间靠一句"深度讨论补充来源：deep-discussion-notes.md"连接，关系不够清晰。建议在 overview.md 头部加一段文档级目录：

```markdown
## 本目录文档关系
- **overview.md**（本文）：结论性摘要、横向对比表、对 omni_powers 的启示
- **deep-discussion-notes.md**：论证过程、架构细节、决策推理
- **spec_and_plan_comparison.md**：10 个 vendor 的 SPEC/Plan 生成机制深度对比
- **vendors_repo/**：各 repo 的独立详细分析
```

### S2. overview.md §VI 表改"建议"为"对照验证"

将"对 omni_powers 的建议"改为两列对照结构：左列"vendor 能力"、中列"omni_powers 对应机制"、右列"状态（已采用/已规划/待评估）"。这样既展示 vendor 分析成果，又避免混淆"已实现"和"待实现"。

### S3. 考虑 vendors_analyze 文档的长期维护策略

vendor 分析是 2026-07-02 的一次性研究成果。随着 design 演进和 vendor 生态变化，这些文档会逐渐过时。当前有三个选择：

A. **冻结归档**：标注为"历史分析快照"，移入 `docs/archive/vendors_analyze_20260702/`，design 不再引用其具体结论，只保留 CLAUDE.md 中一句"vendor 分析见 archive"作为背景参考。

B. **定期更新**：保留当前位置，但增加"最后验证日期"字段，每季度或每次重大 design 变更后做一次对照检查。

C. **精简合并**：将三文档中仍有持续参考价值的部分（如 §VI 对照表 S2 改造后、独门技术对比）提炼进 design 或 op_decisions.md，原始分析移入 archive。

从 design §0.1 的"护栏按需付费"原则看，B 方案（定期更新）成本高而收益低——vendor 生态变化与 omni_powers 演进无关。建议 C（核心结论提炼 + 归档原始分析），保持文档干净。

### S4. spec_and_plan_comparison.md 可作为后续 SPEC 模板设计的参考索引

该文档对 10 个 vendor 的 SPEC 格式做了详尽对比（§III SPEC 格式对比表、§V 关键差异总结），其中 spec-kit 的 6 固定章节模板、OpenSpec 的 Delta spec ADDED/MODIFIED/REMOVED 格式、bmad 的五字段内核都是设计参考。建议在 design §2.2 spec 模板相关段落加一条交叉引用指向此文档，注明"vendor SPEC 格式对比见 `docs/vendors_analyze/spec_and_plan_comparison.md`"——作为"为什么选这个模板结构"的背景参考。

---

## 不确定项 / 可能误报

### U1. overview.md §VI 的建议性语气是否为刻意设计

如 H1 所述，该节写法可能是有意为之——作为一份独立分析文档，它确实应该总结"从 vendor 身上学到了什么"，其中的部分建议在分析时（2026-07-02）可能尚未被 omni_powers 正式采纳，只是后来被 design 吸收了。如果这是历史演进的痕迹（先分析、后设计），那么 H1 不是文档问题而是文档维护滞后——需要更新状态。本报告按"以 design 为现行真相"的审阅原则标记为 HIGH，若实际意图是保留历史视角，可降级为 MEDIUM 并加注"分析时的建议状态，以 design 原文为准"。

### U2. `vendors/` 目录是否在其他位置存在

如 H3 所述，overview.md 引用 `vendors/` 目录。未在项目根目录找到。可能是分析时使用的临时 checkout 目录（在 `~/karson_ubuntu/` 下而非 `omni_powers` 仓库内），也可能已在分析完成后清理。本报告标记为 HIGH，但如果该目录在其他路径存在且有明确约定，可降级。

### U3. CLAUDE.md 是否应索引全量 vendors_analyze 文档

如 M5 所述，CLAUDE.md 只索引了 overview.md。但 CLAUDE.md 本身的定位（design §1.3）是"门牌（指路），不重复 blueprint 内容"——它只给入口而非全量索引。从这个角度看，只列 overview.md 是符合 design 原则的。本报告按"用户期望能找到所有重要文档"的视角标记为 LOW，若认为 CLAUDE.md 应保持精简，此条可视为无需修复。
