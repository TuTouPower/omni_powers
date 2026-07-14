# 当前模型判断依据

可观测来源：settings 顶层 model=default_model；env.ANTHROPIC_MODEL=default_model；默认档位 haiku=default_haiku[1m] / sonnet=default_sonnet[1m] / opus=default_opus[1m]；主会话 powered by default_model。current 路继承主会话。未写入任何 secret。

# 审阅范围

核心参考：`/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md`

审阅文件：

- `/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/everything-claude-code.md`
- `/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/mattpocock_skills.md`
- `/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/superpowers.md`

审阅重点：vendors_repo 参考资料是否仍服务 design；是否存在与现行设计冲突的未归档结论；是否需要索引、去重、标注参考边界。

# 高优先级问题

## 1. `everything-claude-code.md` 把自动 agent 编排与 hook 持久化描述为核心优势，但缺少 omni_powers 不采纳边界

- 位置：`docs/vendors_analyze/vendors_repo/everything-claude-code.md:448-479`、`511-550`、`551-580`、`714-736`、`827-870`；design `docs/omni_powers_design.md:19`、`21`、`28-35`、`319-342`、`590-615`、`680-684`。
- 现象：文档正面记录 ECC 的 SessionStart 历史注入、Continuous Learning、自动触发 specialist agent、DAG / `/multi-*` 并行和 hook 质量门控。但现行 design 明确：hook 对 subagent 失效，强防线在 leader 返回后验证 + merge gate；task 严格串行，`depends_on` 不授权并行；四个 op-* agent 是固定职责链，不是按变更自动路由的大规模 agent 市场。
- 影响：后续维护者可能把 ECC 的“自动触发 agent + SessionStart 记忆 + 多 agent DAG”误读为 omni_powers 演进方向，冲击 design 的安全根、串行 task、低复杂度和最小状态注入原则。
- 建议：在 `everything-claude-code.md` 开头或 `8. 编排模式` 后增加“采纳/拒绝边界”：采纳选择性安装、规则包分层、agent/rule/schema 校验、上下文成本意识；不采纳自动 specialist agent 路由、大规模 agent 市场、DAG 并行、SessionStart 历史重注入作为默认能力；hook 仅可作主会话 advisory，不是 omni_powers 安全边界。引用 design §0 原则 7/9/12、§3.3、§3.4。
- 置信度：高
- 优先级：P1

## 2. `superpowers.md` 的强制 bootstrap / 自动 skill 触发与 omni_powers 显式 profile + skill 入口存在方向冲突

- 位置：`docs/vendors_analyze/vendors_repo/superpowers.md:5-10`、`44-47`、`56-69`、`148-175`、`361-379`、`411-427`；design `docs/omni_powers_design.md:5`、`649-694`、`721-735`、`739-758`、`760-769`。
- 现象：superpowers 通过 SessionStart 注入 `using-superpowers` 全文，让 agent 在任何响应前先检查并自动调用 matching skill；其价值在“强纪律自动触发”。omni_powers 当前设计则是用户显式 `/opinit`/`/opintake`/`/oprun` 或 lite `/opl*` 入口，profile 判定模式，lite 明确不加 hook、不改项目配置、不做自动发现。
- 影响：如果无边界标注，后续可能把“自动注入 meta-skill”引回 omni_powers，破坏 lite 零侵入承诺，也增加 compact/session 反复注入成本。更严重时，自动 skill 路由会绕开 profile 互斥和 `/oprun` 启动状态重建。
- 建议：在 `superpowers.md` 的 SessionStart/using-superpowers 小节补注：仅借鉴 Iron Law、red flags、verification-before-completion、TDD 和文件交接纪律；不采纳“任何响应前自动 skill 检查”作为 omni_powers 入口机制。omni_powers 权威入口仍是 README/design 的 heavy/lite 七个外部 skill，compact 恢复靠 profile + checkpoint，而非 meta-skill 常驻注入。
- 置信度：高
- 优先级：P1

## 3. `superpowers.md` 的 SDD plan/ledger 与现行“plan 分布式、task 元数据唯一源”缺少映射，容易引入重复状态源

- 位置：`docs/vendors_analyze/vendors_repo/superpowers.md:177-210`、`382-401`；design `docs/omni_powers_design.md:20`、`280-309`、`319-342`、`626-638`。
- 现象：superpowers SDD 使用 plan 文件、task brief、review package、`.superpowers/sdd/progress.md` ledger 和 git commit SHA 恢复。design 则明确 plan 不是独立文档；顺序依赖进 `tasks_list.json` + `leader_checkpoint`；跨 task 决策复制进 spec；review package 由脚本按 dispatch 锚点生成；task 完成状态在 `tasks_list.json`/`op_record/progress.md`，不是隐藏 workspace ledger。
- 影响：若把 SDD ledger/plan 文件直接吸收，会产生与 `tasks_list.json`、`leader_checkpoint.md`、`op_record/progress.md` 竞争的状态源，增加 compact 恢复歧义和 task 串行调度风险。
- 建议：在 `superpowers.md` 的 SDD 小节加入映射表：`task-brief` 可类比 dispatch prompt 指针但不落新 truth；`review-package` 已被 omni_powers 采纳为脚本产物；`progress ledger` 不采纳，状态以 `tasks_list.json` 和 `op_record/progress.md` 为准；`plan file` 不采纳，plan 信息四归宿见 design §2.3。
- 置信度：高
- 优先级：P1

## 4. `mattpocock_skills.md` 的 `code-review` 双轴并行子代理与当前审阅任务要求、omni_powers 串行内核存在直接冲突风险

- 位置：`docs/vendors_analyze/vendors_repo/mattpocock_skills.md:239-260`、`393-404`；design `docs/omni_powers_design.md:319`、`327-342`、`612-638`。
- 现象：mattpocock 的 `code-review` 明确通过并行 Standards/Spec sub-agent 审查 diff；本次审阅要求又明确“不调用其他 Agent”。omni_powers 运行时 reviewer 也是一个 op-reviewer 双裁决角色，但不是两个并行通用 subagent，也不以 diff baseline review 作为 task 编排中心。
- 影响：容易把 vendor 的 code-review skill 当成 omni_powers reviewer 设计依据，误导后续把 op-reviewer 拆成并行 agent 或把审阅流程建立在“基准点 diff + 两轴报告”上。这样会增加上下文隔离复杂度，也偏离现行 task 严格串行、review-package + 单 reviewer verdict 的设计。
- 建议：在 `mattpocock_skills.md` 的 `code-review` 段加边界：可借鉴“双轴分离”的思想和 Fowler smell baseline；不采纳其并行 sub-agent 执行形态为 omni_powers 运行时 reviewer。omni_powers 以 `op-reviewer` 单 agent 内完成“规格合规 + 测试可信”，verdict 由 leader 落盘。
- 置信度：高
- 优先级：P1

# 中低优先级问题

## 1. 三份 vendor 资料与 `overview.md` 大量重复，缺少“设计取舍索引”层

- 位置：三份文件全局，尤其各自 `2. 安装机制`、`3. 提供的工具全景`、`6. SessionStart 注入`、`7. 状态管理`、`8. 编排模式`；`docs/vendors_analyze/overview.md:10-21`、`44-60`、`129-139`、`175-188`、`203-235`。
- 现象：三份文件各自完整记录安装、工具数量、hooks、agents、状态管理、编排模式；`overview.md` 又横向重复了核心结论。但索引只给“关键启示”，没有对这三份细节建立 `adopted / rejected / reference-only / conflict-risk` 清单。
- 影响：维护者需要反复读长文才能知道哪个 vendor 结论服务 design，哪个只是背景。重复信息也会放大过期风险，例如 Star、版本、工具数量、hook 能力、支持 harness 数。
- 建议：更新 `docs/vendors_analyze/overview.md` 或新增 `docs/vendors_analyze/README.md`：按 design 主题列“ECC / superpowers / mattpocock_skills”横向矩阵，字段包括入口机制、状态源、agent 编排、hook 边界、TDD/review、安装侵入性、可采纳点、拒绝点。三份原文件保留为原始分析，入口从索引读结论。
- 置信度：高
- 优先级：P2

## 2. `everything-claude-code.md` 的规模和成熟度数据可能夸大参考权重，缺少快照/证据边界

- 位置：`docs/vendors_analyze/vendors_repo/everything-claude-code.md:21-40`、`274-327`、`364-392`；`docs/vendors_analyze/overview.md:10-18`。
- 现象：文档记录极高 Star/Fork、230+ 贡献者、997+ tests、67 agents、277 skills、20+ MCP 等易变数据。文件末尾没有像 `superpowers.md:431` 一样写 source path/分析时间；也没有声明这些数字是时点快照。
- 影响：ECC 的规模数据会显著影响“成熟度”判断，可能让维护者因规模而偏向复制大系统复杂度，违背 design 原则 12“护栏按需付费，定期做减法”。若数据过期或来源不稳，决策权重会失真。
- 建议：给文件顶部或末尾补“分析完成时间、source/commit、数据为快照，不作当前选型依据”；将 Star/Fork/工具数量移入背景，不作为采纳强理由。`overview.md` 同步加快照声明。
- 置信度：中
- 优先级：P2

## 3. `mattpocock_skills.md` 的 `grill-with-docs`/CONTEXT/ADR 产物与 omni_powers spec/decisions 体系重叠但边界只局部提示

- 位置：`docs/vendors_analyze/vendors_repo/mattpocock_skills.md:11-18`、`166-191`、`326-338`、`359-391`；design `docs/omni_powers_design.md:13-18`、`63-110`、`240-276`、`351-370`。
- 现象：文件开头已提示 `grill-me`、`CONTEXT.md`、ADR 是 vendor 术语，omni_powers 当前入口是 `/opintake`，决策归 `op_record/decisions.md`。但后文仍详细描述 `CONTEXT.md`、ADR、领域模型即时更新、issue tracker 配置等，缺少与 `op_blueprint/domain.md`、`op_record/decisions.md`、工作 spec 的映射表。
- 影响：可能引入并行文档体系：`CONTEXT.md` vs `domain.md`、ADR vs `decisions.md`、`to-prd`/`to-issues` vs `/opintake`。这会破坏 design 的文档职责矩阵和两层规格模型。
- 建议：补一张“术语不迁移表”：Matt `CONTEXT.md` 的领域术语能力若采纳，应落 `op_blueprint/domain.md`（heavy）或工作 spec（lite），不新增根目录 CONTEXT；ADR 权衡若采纳，应落 `op_record/decisions.md`；`grill-with-docs` 追问法可作为 opspec/spec 编写技巧，不作为新入口。
- 置信度：高
- 优先级：P2

## 4. `superpowers.md` 和 `mattpocock_skills.md` 都强调 TDD，但与 omni_powers 的行为层/结构层测试可写性矩阵未对齐

- 位置：`docs/vendors_analyze/vendors_repo/superpowers.md:235-255`；`docs/vendors_analyze/vendors_repo/mattpocock_skills.md:219-238`；design `docs/omni_powers_design.md:226-238`、`548-564`。
- 现象：两份 vendor 文档都强调 RED/GREEN、先写失败测试、seam、真实代码测试。design 更细分行为层与结构层：行为层归 evaluator，implementer 不直接改 `e2e/`；fix 的 BUG-* 回归测试由 leader 观察先红后绿；结构层单测归 implementer。
- 影响：若直接吸收 vendor TDD 表述，可能误导 implementer 为 feat 直接新增/修改行为层 e2e，或在 fix 中自证 BUG-* 先红后绿，从而绕开 design 的防同源污染模型。
- 建议：在两份文件的 TDD 小节增加 omni_powers 注释：采纳“先红后绿”和反模式纪律；执行边界以 design §2.1、§3.1 为准，行为层测试所有权不同于 vendor 通用 TDD，implementer 只拥有结构层测试，BUG-* 先红后绿由 leader/evaluator 独立观察。
- 置信度：高
- 优先级：P2

## 5. `everything-claude-code.md` 的 MCP/LLM 抽象层内容与 omni_powers 当前最小依赖路线关系不明

- 位置：`docs/vendors_analyze/vendors_repo/everything-claude-code.md:364-392`、`435-439`；design `docs/omni_powers_design.md:647-694`。
- 现象：ECC 记录 20+ MCP server、LLM 抽象层、多 harness adapter。omni_powers 当前安装模型是 `install.sh` 复制固定 skill/agent/hook/scripts，依赖仅 jq/git/bats 可选，模型只通过 `OP_*_MODEL` 环境变量参数化。
- 影响：如果不标边界，未来可能把 MCP server、跨 provider LLM 抽象、多 harness adapter 当成必要基础设施，增加安装面和 secret/权限风险，也偏离“不写 secret”“按需付费”的设计。
- 建议：标注 ECC MCP/LLM 层为“背景参考，不纳入当前路线”；若未来引入，只能作为可选适配层，并必须先进入 design/RULES，明确 secret、权限和离线失败策略。
- 置信度：中
- 优先级：P3

## 6. `superpowers.md` 标题拼写存在小错误，影响资料可信度

- 位置：`docs/vendors_analyze/vendors_repo/superpowers.md:177`
- 现象：标题写成 `sun_agent-driven-development（SDD，核心执行引擎）`，应为 `subagent-driven-development`。
- 影响：不影响 design 判断，但该文件作为 vendor 分析资料，标题错字会降低检索和引用可信度。
- 建议：修正为 `subagent-driven-development（SDD，核心执行引擎）`。
- 置信度：高
- 优先级：P3

# 改进建议

1. 给三份文件顶部增加统一“参考边界”块：`本文为 vendor 调研，不是设计契约；现行权威以 docs/omni_powers_design.md、RULES.md、agents/*.md、skills/*/SKILL.md 为准；采纳项必须进入 design/RULES/实现才生效`。
2. 更新 `docs/vendors_analyze/overview.md` 为设计取舍索引：对 ECC、superpowers、mattpocock_skills 分别标 `采纳 / 拒绝 / 仅参考 / 冲突风险`。
3. 将重复的安装、数量、工具全景保留在单份 vendor 原始分析中，索引只保留对 omni_powers 有决策意义的差异。
4. 对所有 SessionStart、hook、自动 agent 路由、DAG 并行、持久记忆能力加设计边界注释，避免覆盖现行 profile、checkpoint、merge gate、安全根。
5. 对 TDD、review、domain modeling 等共通术语补 omni_powers 映射：行为层/结构层、op-reviewer 双裁决、op_blueprint/domain、op_record/decisions、tasks_list/status。
6. 易过期事实统一加快照声明：分析日期、source path/commit、版本、工具数量、Star/Fork/贡献者仅为背景，不作长期事实。

# 不确定项

1. 未联网复核三个 vendor 仓库最新状态；版本、工具数量、Star/Fork、支持平台均按本地资料判断。
2. 未审阅同目录所有 vendor 文件；跨 vendor 去重建议仅基于本分块三份文件和已读 `overview.md`。
3. 未读取 `RULES.md`、agents、skills 现行实现；本报告以 `docs/omni_powers_design.md` 为核心判断参考资料是否服务设计。
4. `overview.md` 已有部分边界提示（如 trellis 子 agent ctx 注入不可作安全边界），但未覆盖本分块三份资料的具体采纳/拒绝清单。