# 当前模型判断依据

可观测来源：settings 顶层 model=default_model；env.ANTHROPIC_MODEL=default_model；默认档位 haiku=default_haiku[1m] / sonnet=default_sonnet[1m] / opus=default_opus[1m]；主会话 powered by default_model。current 路继承主会话。未写入任何 secret。

# 审阅范围

核心参考：`/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md`

审阅文件：

- `/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/agent-skills.md`
- `/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/openspec.md`
- `/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/planning-with-files.md`
- `/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/spec-kit.md`

审阅重点：vendors_repo 参考资料是否仍服务 design；是否存在与现行设计冲突的未归档结论；是否需要索引、去重、标注参考边界。

# 高优先级问题

## 1. `agent-skills.md` 的编排反模式表述容易被误读为 omni_powers 设计约束

- 位置：`docs/vendors_analyze/vendors_repo/agent-skills.md:485-558`，尤其 `8.6 反模式`、`8.7 Claude Code / agent-skills 编排边界`
- 现象：文档详细记录 agent-skills 反对「Persona 调用 Persona」「串行编排器转述」「深层 Persona 树」，并在 `8.7` 补了一句“不要把这一点泛化为 omni_powers 的永久平台契约”。但当前篇幅上，反模式解释远长于边界提示，读者容易把 agent-skills 的“用户/命令层编排”吸收到 omni_powers 当前 leader-worker 系统。
- 影响：与 design 的核心结构冲突。design 明确以 leader 编排 subagent：`op-implementer`、`op-reviewer`、`op-evaluator`、`op-closer`，并把“每 task 全新 subagent”“leader-worker”“review/eval/closer 串行链”作为系统内核。若后续维护者误用 agent-skills 反模式，会削弱或质疑现行 Stage 3/Stage 4 设计。
- 建议：在 `agent-skills.md` 文件开头或 `8.7` 前增加“参考边界”框：该资料仅参考 skill 结构、生命周期覆盖、anti-rationalization、red flags、验证 checklist、并行 fan-out 报告合并；不采纳其“Persona 不调用 Persona”作为 omni_powers 平台约束。并加一句指向 design：omni_powers 的权威编排以 `docs/omni_powers_design.md` §2.4、§3.4、§4.1 为准。
- 置信度：高
- 优先级：P1

## 2. `spec-kit.md` 工作流能力描述可能与 omni_powers “无独立 plan 文档 / task 严格串行”冲突

- 位置：`docs/vendors_analyze/vendors_repo/spec-kit.md:108-110`、`192-221`、`456-500`
- 现象：文档强调 spec-kit 的 workflow 引擎、`tasks.md`、`[P]` 并行标记、`max_concurrency`、多 step 编排，并较正面描述“理论上单个 Agent 可将这些并行任务分发给子 Agent”。但 design 明确规定：plan 是分布式信息，不是独立文档；顺序依赖在 `tasks_list.json` + `leader_checkpoint`；task 严格串行执行，`depends_on` 不授权并行。
- 影响：会给维护者留下“可借鉴 spec-kit workflow/todos 作为下一步增强”的未归档结论，实际会冲击现有安全模型：共享流程文件单副本、merge gate、task 即 commit、串行回流均假设不并行。
- 建议：在 `spec-kit.md` 的 `8. 编排模式` 后补“与 omni_powers 的采纳/拒绝清单”：采纳 spec→plan→tasks 的阶段意识、模板 checklist、宪法/原则校验思路；拒绝独立 `tasks.md` 作为状态源、拒绝 `[P]` 并行执行语义、拒绝 workflow 引擎替代 leader 状态机。标注 design 权威：`docs/omni_powers_design.md` §0 原则 8/9、§2.3、§2.4。
- 置信度：高
- 优先级：P1

## 3. `planning-with-files.md` 的 hook 注入和文件共享记忆叙述与现行“hook 对 subagent 失效、返回后验证”模型边界不够清晰

- 位置：`docs/vendors_analyze/vendors_repo/planning-with-files.md:5-7`、`57-70`、`292-317`、`355-400`
- 现象：文档详细肯定 planning-with-files 通过 SessionStart/UserPromptSubmit/PreToolUse/PostToolUse/Stop 等 hook 自动注入 plan、以文件作为共享内存、多 agent 共享 `task_plan.md`。但 design 当前反复强调：hook deny 对 subagent 失效；防线在 leader 主会话返回后验证；plan 是分布式信息，不是文档；流程文件单一物理副本，subagent 不直接共享写 `tasks_list.json/decisions.md/review.md`。
- 影响：该资料若无边界标注，容易引导后续把 omni_powers 往“hook 注入 plan head / task_plan.md 共享内存 / worker 共同写 plan”方向扩展，破坏现有单写者、串行、merge gate、安全根设计。
- 建议：在 `planning-with-files.md` 开头增加“仅作反例/局部借鉴”标注：可借鉴 context 外化、catchup、attestation、flock/atomic mv 的工程思想；不采纳 per-turn hook 注入、worker 共享写计划文件、Stop hook gate 作为安全根。并引用 design §0 原则 7/8/9、§0.1、§3.3。
- 置信度：高
- 优先级：P1

## 4. OpenSpec/Spec Kit 与 omni_powers 两层规格模型相似但边界未对齐，容易混淆“源真目录”语义

- 位置：`docs/vendors_analyze/vendors_repo/openspec.md:16-18`、`40-60`、`202-217`、`242-284`、`363-384`；`docs/vendors_analyze/vendors_repo/spec-kit.md:284-320`、`416-449`
- 现象：OpenSpec 使用 `openspec/specs/` 源真 + `openspec/changes/` delta；spec-kit 使用 `.specify/` + `specs/<feature>/`。这与 omni_powers `op_blueprint/specs/` + `op_execution/specs/` 表面相似，但 design 的关键差异是：heavy 生效规格只收“经实现和验收淬炼的结论”；工作 spec 与 task 1:1；lite 无 blueprint 真相源，工作 spec 兼任；spec 变更走 leader delta + decisions + 事后报告。
- 影响：如果未标注边界，维护者可能把 OpenSpec 的 `archive`/delta merge 或 spec-kit 的 feature specs 直接类比为 omni_powers blueprint 合入，忽略 evaluator/closer/leader 自审、baseline 合入、task 归档、P0 事后报告等闭环。
- 建议：新增一张“规格模型映射表”：OpenSpec `specs/` ≈ omni_powers heavy `op_blueprint/specs/` 但合入条件不同；OpenSpec `changes/` ≈ `op_execution/specs/` 但 omni_powers 是 task:spec=1:1；spec-kit `specs/<feature>/tasks.md` 不映射为状态源；lite 不读 `op_blueprint/`。放在 vendors_repo 索引或两份文件末尾。
- 置信度：高
- 优先级：P1

# 中低优先级问题

## 1. 四份资料重复记录安装机制、工具全景、SessionStart、状态管理，缺少横向索引和取舍摘要

- 位置：四份文件全局，尤其各自 `2. 安装机制`、`6. SessionStart 注入`、`7. 状态管理`、`8. 编排模式`
- 现象：四份资料结构一致，但缺少跨文件总览，重复信息较多。读者需要逐份阅读才能知道：哪些用于 omni_powers 已采纳、哪些拒绝、哪些仅保留历史观察。
- 影响：参考资料体量上升后，design 维护者不容易快速定位“可借鉴点”和“不可采纳点”；重复描述也增加过期风险。
- 建议：新增或更新 `docs/vendors_analyze/overview.md` / vendors_repo 索引：按主题横向列四列（安装、spec 模型、状态源、编排、hook、agent、测试/验收、安全边界），每项标 `adopted / rejected / reference-only / conflict-risk`。四份原文件保留细节，索引承担决策入口。
- 置信度：高
- 优先级：P2

## 2. vendor 成熟度与版本信息是时间点快照，缺少“非权威、需复核”标注

- 位置：`agent-skills.md:7-14`、`openspec.md:20-25`、`planning-with-files.md:7`、`spec-kit.md:5-8`
- 现象：资料记录 commit 频率、版本、作者、测试数、支持平台数量等，但未统一声明这些是分析时点快照。
- 影响：未来读者可能把版本号、支持 Agent 数、测试数当长期事实。尤其这些 vendor 都处于快速迭代期，数字最容易过期。
- 建议：每份文件顶部统一加“分析日期 + 快照声明 + 事实需重新拉取仓库确认”。OpenSpec 已有分析日期，其他三份建议补齐。
- 置信度：中
- 优先级：P2

## 3. `agent-skills.md` Slash Commands 数量统计存在表述小冲突

- 位置：`docs/vendors_analyze/vendors_repo/agent-skills.md:98-110`、`155`
- 现象：标题写 `Slash Commands（8 个）`，表格列出 `/spec`、`/plan`、`/build`、`/build auto`、`/test`、`/review`、`/code-simplify`、`/ship`、`/webperf` 共 9 行；若 `/build auto` 是 `/build` 子模式，则应明确“不单算命令”。总数统计又写 `8 Commands`。
- 影响：小一致性问题，不影响 design 判断，但会降低 vendor 资料可信度。
- 建议：改成“8 个命令 + 1 个子模式”，或把 `/build auto` 合并到 `/build` 行。
- 置信度：高
- 优先级：P3

## 4. `openspec.md` 对 archive 不阻塞 tasks 未完成的记录需要补边界，避免导入到 omni_powers

- 位置：`docs/vendors_analyze/vendors_repo/openspec.md:202-217`
- 现象：OpenSpec 允许 archive 不阻塞 tasks 未完成，只警告；这与 omni_powers “每 task 验收 PASS 后收口归档；阻塞 task 不进 closer；未修问题落 issues”不同。
- 影响：若直接借鉴 archive 语义，可能弱化 omni_powers 的验收后归档门槛。
- 建议：在该段后标注：OpenSpec archive 语义不适用于 omni_powers task 归档；omni_powers 归档须以 reviewer PASS + evaluator PASS/免派 + closer/leader 收口为前提。
- 置信度：高
- 优先级：P2

## 5. `planning-with-files.md` 的 attestation/flock 机制值得提炼，但当前埋在细节中

- 位置：`docs/vendors_analyze/vendors_repo/planning-with-files.md:138-157`、`187-203`、`379-384`
- 现象：attestation、hash 校验、flock、atomic mv、stall 检测是对 omni_powers 未来共享文件写入协议有价值的工程参考，但当前与不采纳的 hook 注入、共享 plan 方案混在一起。
- 影响：有价值机制可能被一起归为“不采纳”；未来若 design 重新考虑并行 task 或共享文件写入协议，会难以复用这些参考。
- 建议：在索引或文件末尾单独列“可提炼资产”：`flock + atomic mv` 可作为未来并行前共享文件写协议参考；`attestation` 可作为主分支侧 e2e/trailer 强化参考；`stall guard` 可作为循环上限与挂起诊断参考。
- 置信度：中
- 优先级：P2

## 6. `spec-kit.md` “GitHub 官方出品”表述需要证据边界

- 位置：`docs/vendors_analyze/vendors_repo/spec-kit.md:5`
- 现象：一句话定位称“GitHub 官方出品”。当前审阅只读本地文档，无法验证该归属是否准确、是否长期有效。
- 影响：若归属有误，会放大该 vendor 的参考权重，影响设计取舍。
- 建议：标注“按分析时仓库归属/README 判断”，或在后续联网复核后补证据链接。若无法复核，改成“GitHub spec-kit 项目”。
- 置信度：中
- 优先级：P3

# 改进建议

1. 建立 `vendors_repo` 总索引，按 design 主题横向比较四个项目：spec 源真、工作目录、状态源、hook、agent 编排、测试/验收、归档、安装侵入性、可采纳点、拒绝点。
2. 每份 vendor 文件顶部增加统一“参考边界”块：`适合借鉴`、`不适合迁入 omni_powers`、`与 design 冲突风险`、`权威设计入口`。
3. 把“采纳/拒绝”的决策从 vendor 细节中抽出来，放入索引或 `docs/op_decisions.md`，避免未归档结论散落在 vendor 分析里。
4. 对所有快速变化事实加快照声明：分析日期、仓库版本/commit、支持平台数、命令数、测试数均非长期事实。
5. 对相似概念建立映射词表：OpenSpec `change`、spec-kit `feature`、planning-with-files `plan`、agent-skills `skill` 分别映射/不映射到 omni_powers 的 `task/spec/blueprint/issues/checkpoint`。
6. 保留四份文件作为“原始分析”，但让 design 维护者默认从索引读结论，降低重复阅读成本。

# 不确定项

1. 未联网复核 vendor 仓库最新状态；版本、支持平台数、命令数、作者/官方归属均按本地资料判断。
2. 未读取 `docs/vendors_analyze/overview.md` 或其他 vendor 总览文件；若已有索引，本报告中“缺少索引”可能应调整为“现有索引未覆盖本分块边界”。
3. 未审阅四份 vendor 文件之外的同目录资料；跨 vendor 去重建议仅基于本分块四份资料。
4. 未验证 `agent-skills.md` 中命令数是否源自原仓库真实定义；只确认本文内部表述存在计数不一致。
