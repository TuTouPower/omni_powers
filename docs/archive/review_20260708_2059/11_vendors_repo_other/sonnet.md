# sonnet 审阅报告：vendors_repo 其他参考资料

## 审阅范围

- `docs/vendors_analyze/vendors_repo/everything-claude-code.md`
- `docs/vendors_analyze/vendors_repo/mattpocock_skills.md`
- `docs/vendors_analyze/vendors_repo/superpowers.md`

核心参照：`docs/omni_powers_design.md`

## 总体判断

三份文档均为高质量的 vendor 分析，覆盖了当前 Claude Code 生态中三个最有代表性的项目。各自独立成文，结构清晰。但存在以下系统性问题：

1. **缺乏与 design 的显式关联**：三份文档都没有说明各自分析结果如何服务 design、哪些概念被借鉴、哪些被刻意避开。
2. **缺乏交叉索引**：三份文档彼此无引用，读者无法从一份跳到另一份对照。
3. **缺乏 vendors_analyze 目录级索引**：没有 README 或 index 说明各分析文档的用途、完成时间、与 design 的关系。

---

## everything-claude-code.md

### 问题 1：定位说明缺失

- **位置**：全文
- **现象**：文档是对 ECC 的纯事实性分析（结构、安装、工具全景），未在任何位置说明"为什么分析 ECC""这份分析与 omni_powers design 的关系是什么""哪些 ECC 概念被 design 借鉴/参考/刻意避开"。
- **影响**：读者（包括未来的 leader agent）读完不知道这份文档的"产出"是什么——它是决策参考、竞品分析、还是灵感来源记录。文档变成孤立信息孤岛。
- **建议**：在文档开头或结尾增加一个「与 omni_powers 的关系」段，说明：(a) ECC 的 leader-worker 模式、TDD 流程、SessionStart 注入等概念对 design 的启发；(b) design 刻意不跟随的方向（MCP 依赖、277 skills 大而全、跨 harness 支持）；(c) 本分析的结论——哪些可学、哪些不跟。
- **置信度**：高
- **优先级**：P2

### 问题 2：MCP 依赖路径分歧未标注

- **位置**：第 3.5 节（MCP Servers 20+）
- **现象**：ECC 重度依赖 MCP server（nexus、github、supabase、memory 等 20+），而 omni_powers design 明确"零外部依赖、不依赖 MCP server"。这是两个系统在架构哲学上的根本分歧，但分析文档未标注此差异。
- **影响**：如果未来有人基于此分析文档做技术选型，可能误认为 MCP 依赖是"可选项"而忽视 design 的零依赖约束。
- **建议**：在 MCP 相关段落增加标注：「注意：omni_powers design 明确零 MCP 依赖，此处仅作事实记录」。
- **置信度**：高
- **优先级**：P2

### 问题 3：规模对比缺失

- **位置**：全文
- **现象**：ECC 有 67 agents、277 skills、48 hooks，omni_powers 有 4 agents、10 skills、若干 hooks。两个系统在"广度 vs 深度""工具集 vs 工作流"上的哲学差异在分析中未对照。
- **影响**：读者可能误以为 ECC 是 omni_powers 的"上位替代"，而忽略 design 刻意追求的精简和聚焦。
- **建议**：增加对比段，说明 ECC 的定位是"通用 harness 插件市场"，omni_powers 的定位是"特定工作流系统"。
- **置信度**：中
- **优先级**：P3

### 问题 4：SessionStart 注入机制对照缺失

- **位置**：第 4.1 节、第 6 节
- **现象**：ECC 的 SessionStart 注入（session summary + learned skills + instincts）是核心卖点。omni_powers design 的 heavy 模式也有 SessionStart 注入（index.md 摘要），lite 模式则明确无 SessionStart 注入（靠用户手动 `/oplrun`）。分析文档未对照。
- **影响**：读者无法判断 ECC 的记忆持久化方案对 omni_powers 是否有参考价值。
- **建议**：增加对照说明 ECC 的跨会话记忆与 omni_powers 的 checkpoint 机制的异同。
- **置信度**：中
- **优先级**：P3

---

## mattpocock_skills.md

### 问题 5：code-review 双轴概念重叠未消歧

- **位置**：第 4.4 节
- **现象**：Matt 的 `code-review` 是双轴（Standards + Spec），omni_powers 的 reviewer 也是双裁决（规格合规 + 测试可信）。名称相似但轴不同——Matt 的 Standards 轴对应 omni_powers 的 conventions.md，Spec 轴近似但不等同于 reviewer 的"规格合规"裁决。分析文档未消歧。
- **影响**：读者可能混淆两个系统的 reviewer 职责边界，误以为可以互相替换。
- **建议**：增加消歧说明：「Matt 的 Standards+Spec 双轴与 omni_powers 的 规格合规+测试可信 双裁决是不同维度，不可混淆。Matt 的 Spec 轴检查的是 PRD/spec 文件是否被实现覆盖；omni_powers 的规格合规检查的是 task spec 的验收标准/不变量是否被满足」。
- **置信度**：高
- **优先级**：P2

### 问题 6：domain-modeling 产出路径分歧未对照

- **位置**：第 4.1 节（grill-with-docs）、第 7 节（状态管理）
- **现象**：Matt 的 `domain-modeling` 产出 CONTEXT.md 放在 repo 根目录；omni_powers 的 domain.md 放在 `op_blueprint/domain.md`（heavy）或不存在（lite）。路径和范围都不同，分析文档未对照。
- **影响**：如果 omni_powers 项目同时使用 Matt 的 skills，可能产生 CONTEXT.md 和 domain.md 两份领域模型文档，内容重叠或矛盾。
- **建议**：增加互操作警告：「若 omni_powers 项目同时安装 mattpocock_skills，注意 CONTEXT.md 与 op_blueprint/domain.md 可能重叠。建议以 design 的文档职责矩阵（§1.3）为准，CONTEXT.md 视为外部产物」。
- **置信度**：中
- **优先级**：P3

### 问题 7：grill 流程与闸门 A 的关系未说明

- **位置**：第 4.1 节
- **现象**：Matt 的 `grill-with-docs` 是 agent 驱动的追问式需求澄清，omni_powers 的闸门 A 是人工审批 spec。两者都解决"需求不清晰"的问题，但手段完全不同（agent 追问 vs 人审）。分析文档未比较。
- **影响**：读者可能认为 grill 可以替代闸门 A，但 design 的原则 11 明确"正常路径下人只出现在闸门 A 和事后报告两个位置"——grill 无法替代人工审批的安全阀作用。
- **建议**：增加比较段，说明 grill 是"需求探索辅助工具"，闸门 A 是"契约审批关口"，两者互补而非替代。
- **置信度**：中
- **优先级**：P3

### 问题 8：symlink 安装策略与 omni_powers 的差异

- **位置**：第 2 节（安装机制）
- **现象**：Matt 的 `link-skills.sh` 使用 symlink 策略（git pull 即更新），omni_powers 的 install.sh 使用文件复制策略。分析文档记录了这一事实但未说明两种策略的利弊及 design 的选择理由。
- **影响**：轻微。仅作为技术细节差异。
- **建议**：可增加一行注释：「omni_powers 选择文件复制而非 symlink，因 install.sh 一次装齐后不再更新，symlink 的"git pull 即更新"优势对 omni_powers 不适用」。
- **置信度**：低
- **优先级**：P3

---

## superpowers.md

### 问题 9：最接近 omni_powers 的 vendor 但关键差异未系统对照

- **位置**：全文
- **现象**：superpowers 的 brainstorming→plan→SDD→review→finish 管线与 omni_powers 的 spec→task loop→merge→close 管线高度相似，但以下关键差异未系统对照：

| 维度 | superpowers | omni_powers |
|------|-----------|-------------|
| 独立验收角色 | 无（reviewer 兼） | 有 op-evaluator |
| 真相源（blueprint） | 无 | heavy 有，lite 无 |
| 收口角色 | 无 | heavy 有 op-closer |
| lite 模式 | 无 | 有 |
| 机械护栏（merge gate） | 无 | P1 核心防线 |
| spec 写保护 | 无 | 有 |
| 可测性契约 | 无 | spec 模板必填 |

这些差异是 omni_powers design 的核心价值主张（原则 6"测试按耦合物分层"、原则 7"证据由机器产出"、§3.4 merge gate），分析文档在单个工具详解中散落提及但未汇总对照。

- **影响**：读者可能误认为 superpowers 是 omni_powers 的"简化版"或"灵感来源"，而忽略 design 在安全模型上的根本差异。
- **建议**：在文档末尾增加「与 omni_powers 的关键差异」对照表，标注以上维度。或在 vendors_analyze 目录级增加一份对照文档。
- **置信度**：高
- **优先级**：P2

### 问题 10：SessionStart 注入策略的根本分歧

- **位置**：第 4.1 节、第 6 节
- **现象**：superpowers 的 `using-superpowers` 在每次 session start 时全文注入到 context，强制 agent 在任何操作前先检查 skill。omni_powers 的 lite 模式明确无 SessionStart 注入（靠用户手动 `/oplrun`），heavy 模式仅注入 index.md 摘要。这是两种相反的发现机制——superpowers 是"推"（push，agent 被动接受），omni_powers 是"拉"（pull，用户主动触发）。分析文档在 skill 详解中描述了 superpowers 的注入机制，但未与 omni_powers 对照。
- **影响**：读者可能质疑 omni_powers 为什么不采用 superpowers 的注入策略，而文档未提供答案。
- **建议**：增加对照说明：「superpowers 的 SessionStart 注入策略与 omni_powers 的显式触发策略是两种设计选择——前者降低使用门槛但增加每会话固定 context 开销，后者节省 context 但要求用户记住命令。omni_powers 选择后者因 lite 模式的核心约束是零侵入（不改 CLAUDE.md、不加 hook），SessionStart 注入在 lite 下不可用」。
- **置信度**：高
- **优先级**：P2

### 问题 11：subagent 模型差异未评估利弊

- **位置**：第 4.2 节（SDD）
- **现象**：superpowers 使用 `general-purpose` subagent + prompt template（implementer-prompt.md、task-reviewer-prompt.md），omni_powers 使用专用 agent type（`op-implementer`、`op-reviewer`、`op-evaluator`）。分析文档记录了 superpowers 的做法，但未评估两种模型的利弊：
  - superpowers 方式：灵活（prompt 可动态调整），但 agent 无专属工具约束
  - omni_powers 方式：agent 有明确的工具白名单和角色边界，但需要维护 agent 定义文件
- **影响**：读者无法从分析中得出"omni_powers 为什么选择专用 agent type"的结论。
- **建议**：增加利弊评估段。
- **置信度**：中
- **优先级**：P3

### 问题 12："铁律/红牌"心理暗示 vs 机械护栏的根本分歧

- **位置**：第 4.4 节（TDD）、第 4.5 节（debugging）、第 6 节
- **现象**：superpowers 大量使用 prompt 中的心理暗示（Iron Laws、Red Flags、Rationalizations 反驳表）来约束 agent 行为。omni_powers design 的原则 7 和 §3.3 明确依赖机械护栏（merge gate、spec 写保护、访问隔离）而非 prompt 约束——design 的原则 12 甚至说"护栏按需付费，定期做减法"。这是两个系统在设计哲学上的根本分歧：superpowers 相信"反复告诫能改变行为"，omni_powers 相信"只有被监督者控制之外的机械检查才可信"。分析文档未标注此分歧。
- **影响**：读者可能认为 superpowers 的 Iron Laws 是 omni_powers 可以"借鉴"的增强，而忽略 design 对 prompt 级约束的根本不信任（原则 7：implementer 的测试输出是它自己跑 Bash 产生、自己写进 report 的，可伪造）。
- **建议**：增加哲学分歧标注：「superpowers 的 Iron Laws/Red Flags 属于 prompt 级行为约束，omni_powers design 明确此类约束不可信（agent 可自行绕过）。omni_powers 的等效机制是 merge gate + reviewer 双裁决 + evaluator 独立验收——机械检查而非文字告诫」。
- **置信度**：高
- **优先级**：P1

---

## 跨文档问题

### 问题 13：vendors_analyze 目录缺乏索引

- **位置**：`docs/vendors_analyze/` 目录整体
- **现象**：`vendors_analyze/` 下有 `overview.md`（厂商分析总览）和 `vendors_repo/` 子目录（含本报告审阅的三份文档），但缺乏目录级 README 或 index 说明：
  - 每份分析文档的用途和完成时间
  - 各文档与 `docs/omni_powers_design.md` 的关系
  - 哪些分析结论已被 design 吸收、哪些被刻意避开
  - 文档的维护策略（是否需要随 vendor 更新而更新）
- **影响**：新读者（包括未来的 leader agent）进入 `vendors_analyze/` 后不知道从哪读起、读完后不知道这些分析与 design 的关系。与 design 的 §1.3 文档职责矩阵精神不一致。
- **建议**：在 `vendors_analyze/` 下增加 README.md，含：(a) 目录说明；(b) 每份文档的一句话定位 + 完成时间；(c) 与 design 的关系说明；(d) 维护策略（快照型，不随 vendor 更新）。或直接在现有 `overview.md` 中补充此信息。
- **置信度**：高
- **优先级**：P2

### 问题 14：三份文档之间缺乏交叉引用

- **位置**：三份文档各自独立
- **现象**：ECC、Matt、superpowers 三者在多个维度上有重叠（都有 TDD、都有 code review、都有 leader-worker），但三份文档彼此无引用。读者无法从 superpowers 的分析跳转到 ECC 的对照，也无法从 Matt 的分析跳转到 superpowers 的对比。
- **影响**：降低分析文档的协同价值。例如读者在 superpowers 文档中看到 SDD 的 task-brief 文件交接机制，想知道 ECC 或 Matt 是否有类似机制，需要手动切换文档。
- **建议**：在每份文档的相关段落增加"参见"链接（如「参见 everything-claude-code.md 第 4.3 节的 Agent Orchestration」）。
- **置信度**：中
- **优先级**：P3

---

## 总结

| 优先级 | 数量 | 关键项 |
|--------|------|--------|
| P1 | 1 | #12 superpowers Iron Laws vs 机械护栏哲学分歧未标注 |
| P2 | 5 | #1 ECC 定位说明缺失、#2 MCP 分歧未标注、#5 code-review 双轴混淆、#9 superpowers 关键差异未系统对照、#10 SessionStart 注入策略分歧、#13 目录索引缺失 |
| P3 | 6 | #3 规模对比、#4 SessionStart 对照、#6 domain-modeling 路径分歧、#7 grill vs 闸门 A、#8 symlink 策略、#11 subagent 模型、#14 交叉引用 |

三份文档作为 vendor 参考资料本身质量合格。核心缺陷不在于内容错误，而在于**缺乏与 design 的显式关联**和**设计哲学分歧未标注**。最紧迫的是 #12（superpowers 的 Iron Laws 心理暗示与 omni_powers 机械护栏的根本分歧），因为这是 design 安全模型的核心假设，若不标注可能导致读者误读 design 的防线定位。

建议优先处理 P1+P2 项，P3 项可随 vendors_analyze 目录整体整理时一并处理。
