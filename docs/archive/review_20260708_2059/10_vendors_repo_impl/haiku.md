# 审阅报告：vendors_repo 三个实现/工作流参考（bmad-method / gstack / trellis）

> 审阅视角：haiku
> 核心参考：docs/omni_powers_design.md（heavy+lite 合并版）
> 目标文件：
> - docs/vendors_analyze/vendors_repo/bmad-method.md
> - docs/vendors_analyze/vendors_repo/gstack.md
> - docs/vendors_analyze/vendors_repo/trellis.md
> 源文件只读；本报告仅做评估，不改源文件。

## 总体结论

三份文件是 2026-07-02 生成的厂商调研快照，定位为 **design 形成期的参考资料**（非运行时契约）。design 与核心运行时文档（RULES.md / CLAUDE.md / op_decisions.md）均不引用它们。它们的服务价值通过 overview.md §六"对 omni_powers 的关键启示"表间接落地——该表已把三份文件的借鉴点沉淀为 design 决策（leader-worker 编排、tasks_list.json 状态机、最小 SessionStart 注入、hook 不作访问控制等）。

三份文件内容详实、结构统一（9 节模板：概览/安装/工具全景/核心工具详解/文件规范/SessionStart/状态管理/编排模式/对比），作为证据底座保留合理。主要问题集中在：(1) 缺独立索引；(2) 部分关键警示（hook 不作访问控制）只在 overview.md 出现，单体文件内缺失；(3) 个别与现行 design 冲突的厂商做法未标注差异。

无需归档（仍有参考价值）、无需去重（单体 vs 横切是合理信息架构），建议补索引 + 补警示 + 补差异标注。

---

## 问题清单

### P-01 三份文件均缺"hook 不作访问控制"警示，与 design §0.1/§2.5 定位冲突

- **位置**：
  - bmad-method.md 无（bmad 不用 hook，本条不适用）
  - gstack.md §3.2 Hooks、§4.4 Security Stack（描述 hook 作安全防线）
  - trellis.md §3.5 Hooks、§4.2 PreToolUse Sub-Agent Context Injection（描述 hook 注入子 agent 上下文）
- **现象**：gstack 与 trellis 单体文件把 hook 描述为安全/上下文注入手段，未提示 Claude Code 的 hook 对 subagent 整体失效（deny 失效）。design §0.1/§2.5/§3.3 已明确：hook deny 对 subagent 失效，访问控制靠 worktree 结构 + merge gate，不靠 hook 拦截。
- **影响**：design 形成期读者若只读单体文件，可能误以为 hook 可作 omni_powers 的隔离/防篡改手段。当前 overview.md §六已加警示（"不可作为访问控制、写权限隔离或安全边界"），但单体文件内无对应提示，警示只落在横切文档。
- **建议**：在 trellis.md §4.2 与 gstack.md §3.2 各补一行交叉引用——"omni_powers design §0.1/§2.5 已判定 hook 对 subagent 失效，此机制不可移植为访问控制"。属文档完善，非必须。
- **置信度**：高（design §0.1/§2.5 明确，overview.md §六已警示，单体文件缺）
- **优先级**：LOW（参考资料，且横切文档已兜底；单体补注仅提升自足性）

### P-02 vendors_analyze 目录缺索引文件（README/index）

- **位置**：docs/vendors_analyze/（10 个单体文件 + overview.md + deep-discussion-notes.md + spec_and_plan_comparison.md，无 README 或 index）
- **现象**：目录有 13 个 .md 文件，无导航。读者需靠 overview.md 自行推断文件关系。CLAUDE.md 有指向 `docs/vendors_analyze/overview.md` 的单行引用（"厂商分析"），但目录内无自描述。
- **影响**：新增维护者或 design 演进时回查参考，定位成本高。无法快速判断哪个文件描述哪个 repo、横切文档覆盖哪些维度。
- **建议**：补 `docs/vendors_analyze/README.md`，列：(1) 目录定位（design 形成期参考资料，非运行时契约）；(2) 三类文件关系（单体 = repo 证据底座，overview/deep-discussion/spec_and_plan = 横切对比）；(3) 10 个 repo 一句话定位 + 文件指针；(4) 生成时间 2026-07-02 + 时效声明。
- **置信度**：高（目录结构事实）
- **优先级**：LOW（不影响运行时，仅可维护性）

### P-03 trellis.md §4.5 描述的 task 状态机与 design §1.1 状态机存在语义差异，未标注

- **位置**：trellis.md §4.5 Three-Phase Workflow + Breadcrumb State Machine（状态机：`no_task → planning → in_progress → archived`，`completed` 标 dead code）
- **现象**：trellis 状态机 4 态 + completed dead；design §1.1 状态机 9 态（pending/ready/in_progress/reviewing/closing/done/suspended/blocked/obsolete），语义更细。trellis 文件未标注两者差异，读者可能误对照。
- **影响**：低。文件定位为厂商参考，非要求 trellis 状态机对齐 design。但 design §1.1 的 blocked/obsolete/suspended 等态是 omni_powers 独有演进，trellis 无对应概念，对照时易混淆。
- **建议**：trellis.md §4.5 末尾补一行——"omni_powers design §1.1 状态机为 9 态扩展（增 blocked/obsolete/suspended 等），trellis 4 态是其子集"。可选。
- **置信度**：中（对比需要跨文件，design §1.1 明确）
- **优先级**：LOW（参考资料，读者可自行对照 design）

### P-04 gstack.md §4.4 Security Stack 与 design §0.1 信任根定位差异未标注

- **位置**：gstack.md §4.4 Security Stack（L1-L6 六层防御，含 ML 分类器、canary token、combineVerdict 集成判决）
- **现象**：gstack 安全栈面向"Sidebar Agent 读敌对网页"场景（prompt 注入防御），与 omni_powers 的"防 subagent 篡改测试/spec"场景不同。design §0.1 信任根是"leader 主会话 + 闸门 A 人审 + trailer 机械证据"，不依赖 ML 分类器。gstack.md 未标注两者安全目标差异。
- **影响**：低。gstack 安全栈是针对浏览器 QA 场景的专业方案，omni_powers 无浏览器 QA 需求（design §2.5 evaluator 用 computer use，不内置浏览器守护进程）。读者可能误以为 gstack L4-L6 可移植到 omni_powers。
- **建议**：gstack.md §4.4 末尾补一行——"此安全栈面向浏览器 prompt 注入防御；omni_powers 无浏览器 QA 需求，design §0.1 信任根为 leader + 闸门 A + trailer，不依赖 ML 分类器"。可选。
- **置信度**：中（场景差异明确，但需读者跨文件对照）
- **优先级**：LOW（参考资料，design §0.1 已自足）

### P-05 bmad-method.md §9 对比表部分条目与现行 design 不符

- **位置**：bmad-method.md §9 与 omni_powers 的对比关键差异（末节表格）
- **现象**：表格描述 omni_powers "Agent 模型 = 功能角色（op-implementer/reviewer/evaluator/closer）"、"hooks 使用 = hooks 负责入口环境/路径纪律"、"SessionStart 注入 = 无大段 SessionStart 注入；依赖 skill 按需读取 `$OP_HOME` 文档"。与现行 design 基本一致，但：
  - "hooks 负责" 说法与 design §0.1/§3.3 当前定位（hook 对 subagent 失效，仅主会话 advisory）略有出入，表格未体现 hook 已降级为 advisory。
  - 未提 lite 模式（design §5，lite 零 hook）。
- **影响**：低。表格是 2026-07-02 快照，design 后续演进（A11/A16/A18/A19 等）未反映。但对比表本身描述厂商差异，非 omni_powers 现状权威——权威是 design 本身。
- **建议**：表格"omni_powers"列末行补注——"详见 docs/omni_powers_design.md 现行版，本表为 2026-07-02 快照"。可选。
- **置信度**：中（快照时效问题，design 是权威）
- **优先级**：LOW（参考资料，有时效声明即可）

### P-06 三份文件与横切文档的内容重叠属合理信息架构，无需去重

- **位置**：bmad-method.md / gstack.md / trellis.md 与 overview.md §五、deep-discussion-notes.md §三/七/八、spec_and_plan_comparison.md §2.5 等存在内容重叠
- **现象**：三个 repo 的核心机制在单体文件详述，在横切文档有摘要复述。例：trellis SessionStart 注入在 trellis.md §6、overview.md §三（500-800 tokens）、deep-discussion-notes.md §八均有描述。
- **影响**：无负面影响。单体 = 证据底座（完整执行流程、文件规范、代码级细节），横切 = 交叉对比（跨 repo 维度归类）。两类文件服务不同阅读场景，重复是有意的信息分层。
- **建议**：无需去重。保留现状。
- **置信度**：高（信息架构判断）
- **优先级**：—（无动作）

### P-07 三份文件保留价值确认，无需归档

- **位置**：bmad-method.md / gstack.md / trellis.md 整体
- **现象**：文件生成于 2026-07-02，design 已迭代到 heavy+lite 合并版。但文件描述的是厂商做法（bmad 三层配置、gstack 浏览器守护进程、trellis hook 注入），这些做法本身不随 omni_powers design 演进而过期。design 未来若重新评估"浏览器验证""三层配置""hook 注入子 agent 上下文"等机制，仍需回查这些证据底座。
- **影响**：无。文件仍有参考价值。
- **建议**：保留在 `docs/vendors_analyze/vendors_repo/`，不迁移 `docs/archive/`。补时效声明（生成时间 + 非运行时契约）进 P-02 建议的 README.md 即可。
- **置信度**：高（参考价值判断）
- **优先级**：—（无动作，配合 P-02）

---

## 汇总

| ID | 问题 | 优先级 | 动作 |
|---|---|---|---|
| P-01 | gstack/trellis 单体缺"hook 不作访问控制"警示 | LOW | 补交叉引用（可选） |
| P-02 | vendors_analyze 缺索引 README | LOW | 补 README.md |
| P-03 | trellis 状态机与 design 差异未标注 | LOW | 补一行标注（可选） |
| P-04 | gstack 安全栈与 design 信任根差异未标注 | LOW | 补一行标注（可选） |
| P-05 | bmad 对比表部分条目与现行 design 不符 | LOW | 补时效声明（可选） |
| P-06 | 单体与横切内容重叠 | — | 无需去重（合理分层） |
| P-07 | 三份文件归档判断 | — | 保留原位，不归档 |

整体优先级 LOW：三份文件是自洽的参考资料集，服务 design 形成期调研。design 已吸收其有效借鉴点（overview.md §六），现行运行时不依赖它们。建议动作均为文档完善类（补索引、补警示、补差异标注），非阻塞性问题。
