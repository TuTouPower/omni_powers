# Opus 审阅报告：vendors_analyze 主文档

## 当前模型判断依据
依据当前主会话的 model 设定与环境参数，判定当前正运行于 default_opus 模式下，本路审阅已被授权调用并继承 Opus 模型。未包含任何机密或敏感信息。

## 审阅范围
以 `docs/omni_powers_design.md`（现行最高设计档案）为对齐基准，对 `docs/vendors_analyze/` 目录下的三份核心厂商分析文档进行完整只读审阅：
1. `docs/vendors_analyze/overview.md`（总览入口）
2. `docs/vendors_analyze/deep-discussion-notes.md`（深度讨论笔记）
3. `docs/vendors_analyze/spec_and_plan_comparison.md`（规格与计划对比）

---

## 高优先级问题（CRITICAL/HIGH）

### H1. 文档定位缺失历史冻结声明，易与现行设计（Design）产生演进错位
- **位置**：`docs/vendors_analyze/overview.md` 全文及 `docs/vendors_analyze/deep-discussion-notes.md` 开头。
- **现象**：三份分析文档的生成时间均标注为 2026-07-02，其表述多使用“对 omni_powers 的建议”等指引性语气。然而在 2026-07-02 之后，omni_powers 经历多次核心重构（例如 D6 验收前置、D3 closer_gate 机械校验、A18 事后报告等），许多当时的“建议”已转为“已固化不变量”或“已废弃方向”（例如 lite 模式彻底移除 SessionStart 注入以换取零侵入性）。文档中缺乏任何“本分析已冻结，不随 omni_powers 现行设计同步更新”的历史快照免责声明。
- **影响**：新的贡献者或 LLM Agent 可能会将这些调研建议误认为是“待实现的 Feature 堆栈”，导致在已被 design 明确决策、废弃或已实现的领域（如三层合并配置、自动 hook 注入等）进行重复开发或引发设计方向偏离。
- **建议**：在三份文档的头部显式添加统一的历史调研快照声明：
  > **注意**：本文件为 2026-07-02 时期的调研快照，不随项目设计持续演进。现行系统规格与机制必须以 `docs/omni_powers_design.md` 和 `$OP_HOME/RULES.md` 为唯一真相源。
- **置信度**：高
- **优先级**：HIGH

### H2. 核心分析文件 `spec_and_plan_comparison.md` 处于索引真空状态（幽灵文档）
- **位置**：`docs/vendors_analyze/overview.md` 头部索引及 `CLAUDE.md`“相关文档”表。
- **现象**：`overview.md` 仅在头部提及“深度讨论补充来源：`deep-discussion-notes.md`”，而在 `CLAUDE.md` 的“相关文档”表中，“厂商分析”仅指向 `docs/vendors_analyze/overview.md`。长达 530 行的 `spec_and_plan_comparison.md`（详尽对比了 10 个 harness 的规格生成格式）在入口和总览中完全未被提及或索引。
- **影响**：该文档处于不可达状态，读者或 agent 若不通过扫描文件系统则无法感知其存在，导致前期关于 spec-kit, OpenSpec 等模板方案的核心调研资产被实质性闲置。
- **建议**：
  1. 在 `overview.md` 头部补充对 `spec_and_plan_comparison.md` 的指引；
  2. 在 `CLAUDE.md` 的“厂商分析”说明中增加对该对比文档的索引；
  3. 在 `overview.md` 第五节“spec-kit vs OpenSpec”等具体对比处，添加“详见 `spec_and_plan_comparison.md` 对应章节”的交叉引用。
- **置信度**：高
- **优先级**：HIGH

### H3. 引用不存在的物理路径 `vendors/` 且缺乏外部环境说明
- **位置**：`docs/vendors_analyze/overview.md` 第 3 行。
- **现象**：文档声明：“分析对象：`vendors/` 下 10 个 Claude Code harness 相关插件/工具集”。然而在 omni_powers 的仓库根目录下并没有 `vendors/` 目录，`.gitignore` 中也未对其进行忽略配置。
- **影响**：读者在阅读文档时会倾向于在代码库中寻找 `vendors/` 以对照分析，找不到会导致困惑，且可能被误认为是未提交完的脏文件或本地依赖缺失。
- **建议**：修正路径描述，明确指出这些 repo 的源码不在当前仓库中，例如：“分析对象：10 个外部 Claude Code harness 开源仓库（各仓库详细分析见 `vendors_repo/`）”。
- **置信度**：高
- **优先级**：HIGH

---

## 中低优先级问题（MEDIUM/LOW）

### M1. “建议”内容与 omni_powers 极简原则（YAGNI）存在隐性设计冲突
- **位置**：`docs/vendors_analyze/overview.md` 六、对 omni_powers 的关键启示表格中“配置可定制”行。
- **现象**：该行将 `bmad-method` 的“三层可合并配置”列为可借鉴点，虽然加了“但别先做复杂化”的后缀，但在“对 omni_powers 的建议”列中写了“后续可引入默认/项目/用户三层模型配置”。这与 omni_powers 追求零侵入（lite 模式不碰项目配置）、由环境变量自适应模型（OP_*_MODEL）的极简主义（YAGNI）原则相悖。
- **影响**：可能会误导后续开发人员过度设计 omni_powers 的配置机制，引入复杂的 TOML/YAML 合并逻辑，增加项目集成和跨平台维护成本。
- **建议**：明确驳回三层可合并配置在 omni_powers 现行阶段的适用性，将其标记为不予采纳，以保持 profile 及环境变量的极简控制。
- **置信度**：高
- **优先级**：MEDIUM

### M2. 快速定位表与分类图在多文件间高冗余复制，缺乏维护边界
- **位置**：`docs/vendors_analyze/overview.md`（第二、三、七节）与 `docs/vendors_analyze/deep-discussion-notes.md`（第五、六、十、十一节）。
- **现象**：两份文档包含了几乎完全一致的“分类总览”、“维度归类”、“十个 repo 类型总览”以及“快速定位”表格。这些内容在 deep-discussion-notes.md 里基本是 overview.md 对应节的直接拷贝或轻微变体。
- **影响**：形成重复真相源。当未来需要修正某个 repo 的分类或定位时，两份文件极易发生修改不同步，导致分析报告自相矛盾。
- **建议**：贯彻 design §1.3 的去重边界规则：将分类图、维度归类及快速定位表格的唯一真相源保留在 `overview.md`，而在 `deep-discussion-notes.md` 的对应章节中仅写文字论述，并以“分类与快速定位表详见 `overview.md` §II/§VII”进行引用指引。
- **置信度**：高
- **优先级**：MEDIUM

### M3. 对 omni_powers“状态恢复”机制的归因对比不够精准
- **位置**：`docs/vendors_analyze/overview.md`“九、总判断”第三条。
- **现象**：总判断中称：“omni_powers 当前方向：更接近 'OpenSpec/spec-kit 的规格契约 + superpowers 的 leader-worker + trellis/planning-with-files 的状态恢复'”。omni_powers 的状态恢复（依靠 `tasks_list.json` 与 `leader_checkpoint.md`）本质上是为 multi-agent system (MAS) 串行调度而自研的确定性流程状态机。`planning-with-files` 是基于 file 级别的 long-context 恢复，`trellis` 是基于 session 级别的 hook 注入。omni_powers 并没有借鉴它们的注入与追赶机制，而是坚持“bash 先算状态，LLM 再决策”的原则。
- **影响**：此项定性概括掩盖了 omni_powers 在状态恢复及 subagent 场景下禁用 hook（advisory 声明）的自主设计独特性，可能导致读者误以为其状态恢复也是通过动态 hook 注入或 context files 拼装实现的。
- **建议**：将其修正为：“... + 自研的基于 tasks_list.json 与 checkpoint 的确定性流程状态机（不同于 planning-with-files 和 trellis 的动态注入机制）”。
- **置信度**：中
- **优先级**：LOW

### M4. Trellis 模式下的“多 agent 协作”表述在同一文档内微观不一致
- **位置**：`docs/vendors_analyze/deep-discussion-notes.md` 第十节与第八节。
- **现象**：在第十节“三个共同点”中将 trellis 归为“都以单 agent 为主”；而在第八节详细论述 trellis 时又写道其支持“PreToolUse hook ... 向 implement/check/research 子 agent 注入 ... trellis 有 leader-worker 模式”。这在逻辑上前后矛盾。
- **影响**：削弱了深度讨论笔记的严谨性，容易让读者混淆 trellis 真实的 agent 编排模型。
- **建议**：在第十节“三个共同点”中将描述修改为：“默认以单 agent 为主（其中 trellis 支持利用 hook 注入上下文的轻量级子 agent 派发，bmad 提供同上下文圆桌 Party Mode）”。
- **置信度**：高
- **优先级**：LOW

---

## 改进建议

### S1. 优化 `vendors_analyze` 整体组织架构与生命周期策略（推荐“冻结归档”）
既然 vendors 分析是 2026-07-02 的一次性研究成果，而 omni_powers 的现行设计（design.md）早已成熟，继续保持这些分析文档作为活跃的“建议来源”是不合理的。
- **建议**：采用“冻结归档（Archived Snapshot）”策略：
  1. 在 `docs/vendors_analyze/` 目录下所有主 Markdown 头部统一加注归档说明；
  2. 在 `docs/omni_powers_design.md` 或 `op_decisions.md` 中需要提及设计灵感时，单向引用这些调研文件（例如：“设计参考自 spec-kit/OpenSpec，详见 docs/vendors_analyze/...”），但不再把它们作为运行或持续维护文档看待。

### S2. 引入 `spec_and_plan_comparison.md` 作为 SPEC 模板演进的设计依据
`spec_and_plan_comparison.md` 整理了极其丰富的 SPEC/Plan 对比数据（包含 OpenSpec 的 Delta spec 增量管理，bmad-method 从 memlog 自动派生 SPEC 等）。
- **建议**：在 `docs/omni_powers_design.md` 的 §2.2 “Stage 1 工作 spec” 中加入一行备注：“omni_powers 的工作 spec 模板博采众长，参考了 spec-kit 憲法合规与 OpenSpec 差异化管理的优缺点，详见 `docs/vendors_analyze/spec_and_plan_comparison.md`”，增加设计方案的学术与工程支撑。

---

## 不确定项

### U1. `vendors_repo/` 目录的丢失
虽然 `overview.md` 提到“每个 repo 的详细分析见 `vendors_repo/{repo_name}.md`”，但当前 `docs/vendors_analyze/` 目录下仅有 `vendors_repo/` 目录。若这些文件此前被归档到了别处，或者本身就是未全部完成的草稿，应一并予以说明或清理。
