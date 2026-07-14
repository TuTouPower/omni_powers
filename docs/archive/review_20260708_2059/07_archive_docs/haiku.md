# archive 文档审阅（haiku 视角）

## 当前模型判断依据

- settings 顶层无 model override；env 无 ANTHROPIC_MODEL。
- 默认档位 haiku=default_haiku[1m]。
- 主会话 powered by default_model；本审阅任务由用户显式授权 haiku 档（多模型审阅分块）。
- 当前路径继承主会话，对应 default_haiku[1m]。未写入任何 secret。

## 审阅范围

核心参考：`docs/omni_powers_design.md`（heavy+lite 合并版）+ `RULES.md`（运行时）+ `CLAUDE.md`（入口）。

逐文件审阅（全量，不抽样）：

1. `docs/archive/README.md`
2. `docs/archive/agent_protocol_old.md`
3. `docs/archive/agent_team_vs_subagent.md`
4. `docs/archive/omni_powers_lite_design.md`
5. `docs/archive/op_findings.md`

审阅维度：是否正确标注为历史；是否仍被当前入口引用；是否与现行 design/RULES 产生误导性冲突。

---

## 高优先级问题（CRITICAL/HIGH）

### H1. agent_team_vs_subagent.md 结论已被现行协议推翻，但未标注「结论已废」

- **位置**：`docs/archive/agent_team_vs_subagent.md` §九 结论（第 283-299 行）、§十二（第 467 行起）
- **现象**：
  - §九明确写「**建议：当前保持 Agent Team 方案不变**」「Sub Agent 致命 bug 未修复让依赖 Sub Agent 做关键路径任务风险太高」。
  - §十二标题「全量迁移到 Sub Agent 的变更方案」列为待执行计划。
  - 文档头无归档声明、无「结论已废」标注（仅有创建日期 2026-06-27）。
- **现行协议**：`RULES.md` 第 10 行明确「**全线 Sub Agent，每次 fresh dispatch**」；design §0.2 能力矩阵与 §3.4 merge gate 已建立在 subagent 之上；整个系统已全线 subagent 化。
- **影响**：agent 若 grep 本目录（尽管 README 已警告）会读到「保持 Agent Team」的过时结论，与现行协议直接冲突。文档自身无标记表明结论已被推翻，读者需交叉对照 §十二才知道迁移已发生。
- **建议**：文档头追加归档 banner，明确写「本文结论已被推翻——现行协议全线 Sub Agent（见 RULES.md / design §3.4）。本文仅作决策演变历史保留」。最低限度也要在 §九结论段顶部加一行「⚠️ 此结论已于后续版本推翻」。
- **置信度**：高
- **优先级**：HIGH

### H2. agent_team_vs_subagent.md §八 Sub Agent bug 论述与 §十 Superpowers 段自相矛盾，且未标注最终走向

- **位置**：§八（第 227-279 行）vs §十末（第 386-389 行）
- **现象**：§八列三个 issue（#56869/#63678/#65423）论证 Sub Agent「生产就绪 ~~生产就绪~~ 有未修复致命 bug」，结论倾向保留 Agent Team。§十末又写「Superpowers 证明了 Sub Agent 模式是可行的」「这动摇了之前 Agent Team 更可靠的结论」。
- **影响**：文档内部论述来回摇摆，无最终裁决标注。读者无法判断：bug 究竟是否致命？现行全线 subagent 化后这些 bug 如何对待？
- **现行协议佐证**：现行已全线 subagent，design §0.1 信任根声明已把 Sub Agent hook 失效纳入设计（「hook 对 subagent 失效不是缺陷，是 design 选择」），防线移到主会话 + merge gate。
- **建议**：在 §八与 §十各加一行归档注记，指明「现行协议的最终立场见 design §0.1（信任根声明）+ §0.2 能力矩阵——防线在主会话侧，不依赖子代理内 hook」。
- **置信度**：中高
- **优先级**：HIGH

### H3. omni_powers_lite_design.md 与现行 design §5 在脚本策略上存在表面冲突，归档标注不足以消解误导

- **位置**：`docs/archive/omni_powers_lite_design.md` §8.3（第 221-263 行）、§13（第 332-363 行）、§14 末「落地状态」
- **现象**：
  - 归档文档 §8.3/§13 坚持「lite skill 自带脚本」「lite 与 heavy 脚本成两份副本」「`build_lite.sh` 校验副本漂移」是**待实现的 P0 缺口**（§1.2.1 标「待实现 P0」）。
  - §14 顶部又标「核心链路已实现」并把 `build_lite.sh` 漂移校验列为已落地。
  - 现行 design §5.5 明确：install.sh 已统一装 `~/.claude/scripts/omni_powers/` 共享目录，「**消灭 per-skill 副本同步机制**」「旧方案 B 的 `build_lite.sh` 副本校验 + 三份 `op_check_env` 互检不再需要」。
  - 归档文档顶部仅写「已并入 design §13-§15」——但**现行 design 的 lite 段是 §5，不是 §13-§15**，目录编号都错了。
- **影响**：归档 lite 文档描述的脚本策略（per-skill 自带副本 + `build_lite.sh` 同步）与现行 design §5.5（共享目录 + 明确淘汰副本机制）方向相反。归档顶部「并入 §13-§15」的指路错误，读者按此找不到现行内容，会误以为 lite 设计没动过。
- **建议**：
  1. 修正归档顶 banner 的章节引用（应为 §5，非 §13-§15）。
  2. 在 §8.3 与 §13 顶部加注「⚠️ 此方案（per-skill 副本 + build_lite.sh）已被现行 design §5.5 淘汰，改为 install.sh 共享脚本目录」。
- **置信度**：高
- **优先级**：HIGH

### H4. CLAUDE.md 与 design 对 archive 的引用描述与实际状态不一致

- **位置**：`CLAUDE.md` 第 52 行、第 103 行；`design §1.3` 第 170 行（`docs/archive/`）
- **现象**：
  - CLAUDE.md 第 52 行描述 archive「含 op_findings.md、omni_powers_lite_design.md 等」——这是部分清单，漏列了本批审阅的 `agent_protocol_old.md` 与 `agent_team_vs_subagent.md`（archive README 倒是列齐了）。
  - CLAUDE.md 第 103 行「实验发现（归档）| `docs/archive/op_findings.md`」单独指 op_findings，OK。
  - design §1.3 第 170 行「blueprint-generator 从 `docs/archive/` + git log + 现有代码提炼已实现功能」——把 archive 当作**已实现功能的素材源**引用。但 archive 的所有文档都明确标「冻结历史归档」「agent 不应 grep 作当前协议依据」。blueprint-generator 若真去读 archive 提炼功能，会读到旧协议（agent_protocol_old.md）、废弃 lite 设计等噪音。
- **影响**：design §1.3 的引用与 archive README 的「仅供追溯设计演变，不应作协议依据」存在语义张力。blueprint-generator 的实际行为需核实——若真读 archive，提炼出的「已实现功能」会混入历史协议描述。
- **建议**：
  1. design §1.3 第 170 行的 `docs/archive/` 引用需澄清边界——指明仅提炼**非协议类**的已实现功能素材（如代码、git log），archive 的协议/设计文档不应作为功能提炼源。
  2. 或在 opinit SKILL.md 明确「blueprint-generator 跳过 archive 中的 *.md 协议文档，只读代码与 git log」。
- **置信度**：中
- **优先级**：HIGH（若 blueprint-generator 真读 archive 则升 CRITICAL——需交叉核实 opinit 实现）

---

## 中低优先级问题（MEDIUM/LOW）

### M1. agent_protocol_old.md 角色名与路径全是旧版，无逐段对照标注

- **位置**：`docs/archive/agent_protocol_old.md` 全文
- **现象**：
  - 角色：coder / code-reviewer / test-reviewer / task-splitter（旧），现行是 op-implementer / op-reviewer / op-evaluator / op-closer（无 task-splitter）。
  - 路径：`docs/harness_execution/` / `docs/harness_record/` / `docs/harness_blueprint/`（旧），现行是 `docs/omni_powers/op_execution/` / `op_record/` / `op_blueprint/`。
  - agent 名：op-coder / op-code-reviewer / op-test-reviewer（旧），现行 op-implementer 等。
  - 文档头有「⚠️ 已废弃」banner（第 3 行），这点做得对。
- **影响**：banner 已声明废弃，误导风险低。但文档长达 540+ 行，全文术语/路径与现行冲突，若 agent 跳过 banner 直接 grep 段落，会拿到旧路径/旧角色名。
- **建议**：banner 已足够（README 也重申了「不应 grep 作协议依据」）。可考虑在每个主要章节标题（## 角色 / ## 文件分层 等）追加行内注「（旧版，见现行 RULES.md）」，但成本收益不高，属可选。
- **置信度**：高
- **优先级**：MEDIUM

### M2. agent_protocol_old.md 状态机用 pending/coding/reviewing/done/blocked，与现行 ASCII 枚举不一致

- **位置**：第 47-79 行
- **现象**：旧协议状态 pending/coding/reviewing/done/blocked，英文中文混用；现行 design §1.1 的 ASCII 枚举是 pending/ready/in_progress/reviewing/closing/done/suspended/blocked/obsolete，9 态。旧协议仅 5 态，无 ready/closing/obsolete/suspended 区分。
- **影响**：纯历史对照，banner 已标注。误导风险低（agent 不应据此判定当前状态值）。
- **建议**：无需改动，banner 足够。
- **置信度**：高
- **优先级**：LOW

### M3. omni_powers_lite_design.md §14 落地状态段引用的章节编号与现行 design 不符

- **位置**：第 367-376 行
- **现象**：§14 顶部「已实现」段引用「§13-§15」作为并入目标，但现行 design 的 lite 段是 §5。归档文档自身的章节编号（§1-§15）是旧独立文档的结构，与合并后的 design 章节不对应。
- **影响**：与 H3 同源，已在 H3 提出修正方案。此处单独列是为强调：归档文档内部章节引用（如「见 §8.3」「§9」）指的都是归档文档自己的章节，不是现行 design 的章节——读者需意识到这点。
- **建议**：归档顶部 banner 已说「并入 design」，补充一句「本文内部章节编号（§1-§15）与现行 design 章节不对应，引用本文内部段落时注意区分」。
- **置信度**：高
- **优先级**：MEDIUM

### M4. op_findings.md 实验 7 关于 model 参数的结论表述可能过时

- **位置**：`docs/archive/op_findings.md` 实验 7（第 77-84 行）
- **现象**：结论写「spawn 时必须显式传 model 参数。agent 定义文件里的 model 字段不被 spawn 读取」。现行 RULES.md 第 16 行写「`OP_IMPLEMENTER_MODEL` 等，值填 haiku/sonnet/opus；未设则**不传 model 参数，继承主会话当前模型——dispatch 绝不准自行指定 model**」。
- **张力点**：实验 7 说「必须显式传」，现行协议说「未设则不传，继承主会话」。表面冲突。
- **实质**：实验 7 是 Agent Team 时代（spawn teammate）的结论——teammate 的 model 字段不被 spawn 读取，故必须传。现行全线 subagent，dispatch 由 leader 通过 Agent 工具的 model 参数控制，未设环境变量时不传即继承。两者上下文不同（teammate vs subagent），结论不矛盾但表述易混淆。
- **影响**：低。文档头标 2026-06-25，属 Agent Team 时代实验。读者若不区分 teammate/subagent 会误判。
- **建议**：在实验 7 末尾加注「此结论针对 Agent Team 时代的 teammate spawn；现行全线 subagent，model 由 leader dispatch 的环境变量控制（见 RULES.md 角色拓扑段）」。
- **置信度**：中高
- **优先级**：MEDIUM

### M5. op_findings.md 实验 6 ctx_stats 结论需补充现行适用性

- **位置**：第 52-74 行
- **现象**：结论「ctx_stats 对上下文监控无用——只显示 context-mode 拦截字节数，不显示实际上下文窗口占用率」。这是 Agent Team 时代的发现。现行全线 subagent，subagent 上下文本就不在主会话监控范围（每次 fresh dispatch，上下文隔离），「监控 teammate 上下文占用率」这个需求本身已消失。
- **影响**：低。实验结论本身仍成立（ctx_stats 的行为没变），但其应用场景（监控常驻 teammate）已不存在。
- **建议**：可选——在实验 6 末尾加注「此监控需求随全线 subagent 化消失，subagent 每次 fresh dispatch 不存在上下文累积问题」。
- **置信度**：中
- **优先级**：LOW

### M6. agent_team_vs_subagent.md §十一 上下文继承机制表格需标注时效

- **位置**：第 393-465 行
- **现象**：基于「Claude Code 官方文档 v2.1.178」整理的 Sub Agent / Fork / Teammate 上下文继承对比表。文档日期 2026-06-27，Claude Code 版本迭代快，文档行为可能已变。
- **影响**：低。这是事实性整理（基于官方文档），非协议结论。即便 Claude Code 行为变了，作为「2026-06-27 快照」仍有参考价值。
- **建议**：可选——表格头加「截至 2026-06-27 / Claude Code v2.1.178 的快照，最新行为以官方文档为准」。
- **置信度**：中
- **优先级**：LOW

### L1. archive/README.md 列表完整但漏「归档原因」分级

- **位置**：`docs/archive/README.md` 第 9-13 行
- **现象**：列出 4 个归档文件，每个一句话说明。但没区分「结论已废」（agent_team_vs_subagent.md）与「结论仍有效但已迁移」（omni_powers_lite_design.md）与「纯历史快照」（agent_protocol_old.md）与「实验记录可能过时」（op_findings.md）。
- **影响**：低。读者需打开每个文件才能判断其当前状态。
- **建议**：可选——README 列表每项追加「状态：结论已废 / 已迁移 / 历史快照 / 可能过时」标签。
- **置信度**：高
- **优先级**：LOW

### L2. agent_protocol_old.md 引用的脚本（task_review.js 等）现行已不存在

- **位置**：第 22-34 行、§Workflow 化（第 510 行起）
- **现象**：引用 `task_review.js` / `task_review_autofix.js` / `task_full.js` / `close_check.sh`。现行 scripts 目录下这些 task_review*.js 已不在（现行是 op_read_verdict.sh 等）。
- **影响**：低。banner 已标注废弃，脚本路径属历史细节。
- **建议**：无需改动。
- **置信度**：高
- **优先级**：LOW

---

## 改进建议

1. **统一归档 banner 格式**（最高收益）：四个归档文档的 banner 风格不一——
   - `agent_protocol_old.md`：banner 清晰，标「已废弃」+ 指向 RULES.md。
   - `omni_powers_lite_design.md`：banner 标「已归档」但章节引用错误（§13-§15 应为 §5）。
   - `agent_team_vs_subagent.md`：**无归档 banner**，只有创建日期。
   - `op_findings.md`：只有「2026-06-25 实验验证」一行，无归档声明。

   建议统一为：「⚠️ 历史归档（日期 YYYY-MM-DD）。现行协议见 RULES.md + design.md。本文 [结论已废 / 已迁移 / 历史快照 / 可能过时]，具体见 [X 节注记]。」

2. **agent_team_vs_subagent.md 顶部补归档 banner**：这是唯一没有归档声明的文件，且其核心结论（保持 Agent Team）已被推翻，误导风险最高。

3. **修正 omni_powers_lite_design.md 顶部章节引用**：§13-§15 → §5（H3）。

4. **design §1.3 第 170 行的 archive 引用需澄清边界**（H4）：明确 blueprint-generator 是否真读 archive，若读则限定范围。

5. **archive/README.md 补充状态分级**（L1）：让读者一眼判断每个文件的当前可信度。

---

## 不确定项

1. **blueprint-generator 是否真读 archive/**：design §1.3 第 170 行写「从 docs/archive/ + git log + 现有代码提炼」，但本次审阅未交叉核实 `skills/opinit/SKILL.md` 步骤三的实际实现。若真读 archive 的 *.md，提炼出的「已实现功能」会混入协议噪音——需核实后定级（H4）。本次审阅范围内未读 opinit SKILL.md，留待 entry/skills 分块审阅覆盖。

2. **agent_team_vs_subagent.md 引用的三个 GitHub issue（#56869/#63678/#65423）当前状态**：文档记录的是 2026-06-27 的状态（#56869 closed/not_planned，#63678/#65423 stale）。这些 issue 在 2026-07-08 的状态未核实。若已修复，文档的「致命 bug」论述更需标注过时。本次审阅未联网核实。

3. **op_findings.md 实验 1-5（spawn 同名/shutdown/tmux 清理）的现行适用性**：这些是 Agent Team 时代的 teammate 管理实验。现行全线 subagent，teammate 管理需求消失。但实验结论本身（spawn 同名加序号、shutdown 残留等）作为 Claude Code Agent Team 行为记录仍有参考价值。是否需逐条标注「Agent Team 时代，现行不适用」未定，倾向不标（文档头日期已表明时效）。
