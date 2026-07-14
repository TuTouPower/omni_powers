# haiku 视角审阅报告：vendors_repo 核心四份（agent-skills / openspec / planning-with-files / spec-kit）

## 当前模型判断依据

会话模型为 default_haiku[1m]（主会话 powered by default_model，current 路继承主会话）。用户授权调用 haiku 做本分块审阅。本次审阅未读取任何 secret，全部基于本地只读源文件。

## 审阅范围

核心参考：`docs/omni_powers_design.md`
本分块目标（全量只读）：
- `docs/vendors_analyze/vendors_repo/agent-skills.md`（29.5K，567 行）
- `docs/vendors_analyze/vendors_repo/openspec.md`（18.5K，421 行）
- `docs/vendors_analyze/vendors_repo/planning-with-files.md`（22.5K，401 行）
- `docs/vendors_analyze/vendors_repo/spec-kit.md`（21.3K，501 行）

交叉参考（用于判断服务关系）：
- `docs/vendors_analyze/overview.md`、`spec_and_plan_comparison.md`、`deep-discussion-notes.md`
- `docs/op_decisions.md`、`docs/omni_powers_design.md`、`RULES.md`

## 总体判断

四份资料是 overview / 横向对比 / 深度讨论的**输入材料**，design §"对 omni_powers 的关键启示"与 overview §"六/九 总判断"明确"最值得借鉴 OpenSpec delta spec / spec-kit 模板门禁 / planning-with-files 恢复锚点"，结论直接源自这四份资料 → **仍服务 design，无与现行设计冲突的未归档结论**。

资料本身是 2026-07-02 采集的静态快照（见 openspec.md `> 分析日期：2026-07-02`，git history `cf8a3df docs: reorganize vendor analysis docs`），而 design 自此后历经 D3-D13/A16-A20 等多轮演进。作为参考档案（非运行时契约），**时效漂移不构成设计冲突，但需标注参考边界**。

## 高优先级问题

### H1. 四份资料缺少统一的"参考边界声明"，易被误读为现行契约

- **位置**：`vendors_repo/` 四份文件头部（agent-skills.md L1-15、openspec.md L1-9、planning-with-files.md L1-9、spec-kit.md L1-8）
- **现象**：四份资料均以"概览/定位/成熟度"开篇，无前置声明说明"这是 2026-07-02 的静态采集快照、非 omni_powers 运行时契约、design 已在此后演进"。openspec.md 仅在头部 `> 分析日期：2026-07-02` 给出日期，其余三份连日期都无。
- **影响**：后续 agent（尤其 lite 下无 SessionStart 注入、靠文件重建上下文的场景）读 `docs/vendors_analyze/vendors_repo/*.md` 可能误把 vendor 现状当作 omni_powers 现行设计的事实依据，或把 design "借鉴"叙述误读为"vendor 已实现 omni_powers 全部能力"。overview §九 已有"omni_powers 当前方向：更接近 OpenSpec/spec-kit 的规格契约 + superpowers 的 leader-worker + trellis/planning-with-files 的状态恢复"，但该判断未回填到 vendors_repo 每份文件头部。
- **建议**：在四份文件头部统一加一行参考边界声明（模板示例）：`> 参考档案：2026-07-02 采集快照，仅作 design 借鉴来源，非 omni_powers 运行时契约。design 已演进至 heavy/lite 双模式 + merge gate（§3.4）+ D13 等机制，本文件描述的 vendor 能力可能与现状有差异。`
- **置信度**：高
- **优先级**：高

## 中低优先级问题

### M1. overview/对比文档对 spec-kit 与 OpenSpec 的"重 vs 轻"二分可能掩盖 omni_powers 已落地的中间态

- **位置**：`spec_and_plan_comparison.md` L27-167（spec-kit "最严格结构化"）、L374-413（planning-with-files "只要 Plan 不要 SPEC"）；`overview.md` §九总判断
- **现象**：spec_and_plan_comparison 把 spec-kit 列为"最重 6 固定章节 + Constitution 门禁"，OpenSpec 为"轻 delta spec"，planning-with-files 为"无 spec 概念"。omni_powers design §0 原则 3"能在 spec 期解决的难题不留给执行期" + §2.2 spec 模板（INV/AC/边界/可测性契约三类技术决策 + 内联设计探索）实际是 spec-kit 重模板与 OpenSpec delta 的**中间态**，且 §1.2 两层 spec 流转（生效规格淬炼 vs 工作 spec 一次性）吸收了 OpenSpec delta 的优点。这份"omni_powers 已合成两家之长"的判断在对比文档里没有体现。
- **影响**：低。对比文档定位是横向参照，不是 omni_powers 自我陈述。但若后续维护者只读对比文档，可能误判 omni_powers 应再向 spec-kit 靠拢（加重模板）或向 OpenSpec 靠拢（全 delta），忽略 design 已做的合成。
- **建议**：在 `spec_and_plan_comparison.md` 结尾加一节"omni_powers 的合成路径"，或在该文档头部交叉引用 design §1.2（两层 spec 流转）+ §2.2（spec 模板），说明 omni_powers 不是二选一而是吸收两家。可选。
- **置信度**：中
- **优先级**：中

### M2. planning-with-files 的 gated completion 门禁描述与 omni_powers 验收前置（D6）存在语义对照，但未在资料内交叉标注

- **位置**：`planning-with-files.md` L185-203（check-complete.sh gated 5 层 guard）、L67（Stop hook gated 模式）
- **现象**：planning-with-files 的 gated Stop hook（未完成 phase 阻止 agent 停止）与 omni_powers lite 的 D6"验收前置——先验 PASS 才 commit"（design §5.6 L863）在"完成定义前置"上有相似诉求，但实现路径相反：planning-with-files 靠 hook 拦 Stop，omni_powers lite 靠 leader 亲验 + 收口前机械检查（§5.9）。资料内未标注这层对照关系。
- **影响**：低。planning-with-files 资料本身是 vendor 描述，无需承担 omni_powers 对照。但 omni_powers 维护者读到此节可能误以为"planning-with-files 已解决 gated 问题，omni_powers 可直接借鉴其 Stop hook"——实际 omni_powers design §0 原则 7 明确"hook 对 subagent 失效"，planning-with-files 的 Stop hook 在 omni_powers subagent 场景下不适用。
- **建议**：在 `planning-with-files.md` 的 gated 描述段或 omni_powers design §5.9 补一句交叉引用：planning-with-files 的 Stop gate 依赖 hook 生效，omni_powers 因 hook 对 subagent 失效（§0 原则 7）选择 leader 亲验路径，两者前提不同。可选。
- **置信度**：中
- **优先级**：中

### M3. agent-skills 编排反模式（persona 不互调）的"不要泛化为平台契约"提醒在 overview 已有，但四份资料内不一致

- **位置**：`agent-skills.md` L308（"Personas 不调用 Personas——编排是 slash command 的工作；这是 agent-skills 的流程规则，不泛化为 omni_powers 的永久平台契约"）、L554-557（8.7 编排边界）、L565-566（8.8 与 omni_powers 差异）
- **现象**：agent-skills.md 内部已显式声明"不泛化为 omni_powers 平台契约"（L308/L554），这是**已做对的事**。但 openspec.md L410-420（对比 omni_powers 表格）只列差异未列参考边界，spec-kit.md L496（"不内置多 Agent 协作编排"）未提 omni_powers 对照，planning-with-files.md L393-401（8.4 总结）未提与 omni_powers 隔离前提。
- **影响**：低。agent-skills.md 已树立标杆，其余三份未对齐属风格不统一，不影响 design 决策。
- **建议**：可选——在 openspec.md / spec-kit.md / planning-with-files.md 的"对比 omni_powers"段统一加一句参考边界，与 agent-skills.md L308 风格对齐。
- **置信度**：中
- **优先级**：低

### M4. spec-kit 的 Constitution 机制与 omni_powers domain.md/conventions.md 的对应关系未标注

- **位置**：`spec-kit.md` L25（宪法模板）、L143（plan 阶段宪法合规检查）、L351（constitution-template.md）
- **现象**：spec-kit 的 `.specify/memory/constitution.md`（项目宪法，MUST 原则，所有 spec/plan 阶段校验合规）与 omni_powers `op_blueprint/domain.md`（跨功能业务不变量）+ `conventions.md`（编码约定）在"不可变原则"角色上高度对应。design §1.3 文档职责矩阵已将 domain/conventions 定位为 blueprint 真相源，但 spec-kit.md 未标注这层映射。
- **影响**：低。design 已正确吸收（domain/conventions 即 omni_powers 的 constitution 等价物），资料未标注不影响现行设计。但维护者若想强化"宪法合规检查"机制，需知道 omni_powers 已有对应物。
- **建议**：可选——在 spec-kit.md L143 宪法合规检查段加一行交叉引用：omni_powers 对应物为 `op_blueprint/domain.md` + `conventions.md`，spec 变更子流程（design §2.4）即合规校验入口。
- **置信度**：中
- **优先级**：低

## 改进建议

### S1. 建立 vendors_repo 索引文件，标注每份资料的参考边界与 design 映射点

当前 `vendors_repo/` 目录下 10 份 md 无索引文件。建议加一个 `vendors_repo/README.md`（或 `_index.md`），内容：

- 采集时间统一声明（2026-07-02 快照）
- 每份资料的一句话定位 + 对应 design 借鉴点（如 spec-kit → design §1.3 文档职责矩阵、§2.2 spec 模板；OpenSpec → design §1.2 两层 spec 流转的 delta 思想；planning-with-files → design §5.9 恢复锚点；agent-skills → design §2.4 双裁决/§3.1 测试可写性矩阵的纪律借鉴）
- 明确"非运行时契约，design 演进以 docs/omni_powers_design.md 为准"

这能一次性解决 H1 + M3 的参考边界缺失问题，比逐文件加头部声明更可维护。

### S2. 在 overview §六"对 omni_powers 的关键启示"表加一列"design 落地状态"

当前该表只列"可借鉴点 + 建议"，未标注哪些建议已被 design 吸收、哪些未吸收。加一列指向 design 章节（如"delta spec → design §1.2 已吸收"、"trellis hook 注入 → design §0 原则 7 已评估不适用 subagent"），让参考关系闭环。

## 不确定项

### U1. 四份资料的"成熟度/Star 数/commit 频率"等时效性指标已过期

- **位置**：agent-skills.md L8-14（首次提交 2026-06-09、Star Trendshift）、openspec.md L21-25（极活跃）、planning-with-files.md L7（v3.1.3 2026-06-16）、spec-kit.md L7（v0.12.3.dev0）
- **现象**：这些是 2026-07-02 采集时的快照数据，现在（2026-07-08）已过期 6 天。vendor 可能已发版、改架构、修 bug。
- **影响**：对 design 决策**无影响**——design 借鉴的是结构思想（delta spec / 模板门禁 / 恢复锚点 / 编排反模式），非具体版本能力。但若未来有人据这些数据做 vendor 选型，可能误判。
- **置信度**：高（确信数据已过期）
- **优先级**：低（不影响 design，归档性质决定可容忍）
- **处置**：不更新数据（参考档案非实时追踪），但在 S1 的索引文件里统一声明"时效性指标以采集日为准，不保证现行"。

### U2. 是否存在"未归档的结论被 design 默默采纳但未记 decisions.md"

- **现象**：我检查了 `docs/op_decisions.md`，仅 L198/L217 引用 `vendors/omni_powers_harness_design/omni_powers_harness_v5.md`（非本审阅目标的旧路径），无对 vendors_repo 四份资料的显式引用。design §0 原则、§1.2、§2.2 等借鉴了 spec-kit/OpenSpec 思想，但这些借鉴的决策依据未在 decisions.md 单独记录。
- **影响**：不确定。可能 design 作者认为"借鉴思想不必逐条记 decisions"（design §0 原则 4 明确"不进 spec 的小决策直接做不记录"），也可能漏记。
- **置信度**：低（无法判定是遗漏还是按原则省略）
- **优先级**：低
- **处置**：仅记录存疑，不建议补记——补记可能违反 design §0 原则 4"不为一次性决策做记录"。
