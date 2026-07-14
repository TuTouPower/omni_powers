# 当前模型判断依据

可观测来源：settings 顶层 model=default_model；env.ANTHROPIC_MODEL=default_model；默认档位 haiku=default_haiku[1m] / sonnet=default_sonnet[1m] / opus=default_opus[1m]；主会话 powered by default_model。current 路继承主会话。未写入 secret。

# 审阅范围

核心参考：`/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md`

本次只读审阅：

- `/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/bmad-method.md`
- `/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/gstack.md`
- `/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/trellis.md`
- `/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/overview.md`（仅用于索引/去重判断）

审阅重点：三份 vendors_repo 参考资料是否仍服务 design，是否与现行 heavy/lite 设计冲突，是否需要归档、索引调整或去重。

# 高优先级问题

## 1. bmad-method 对比表把 omni_powers 安装与 hook 定位写成旧版，会误导后续设计取舍

- 位置：`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/bmad-method.md:504-518`；design §4.1、§5.1、§5.3、§5.5。
- 现象：对比表写 omni_powers “git clone + `/opinit` 写 `$OP_HOME` 与 hooks”“运行时按 `$OP_HOME` 定位”“hooks 负责入口环境/路径纪律”。现行 design 已明确 heavy/lite 共用 `install.sh` 一次装齐，heavy 需要 `--set-ophome`，lite 可不写 `$OP_HOME`；lite 零侵入不改项目配置与已有文档；共享脚本目标是 `${OP_SCRIPT_ROOT:-$OP_HOME}` fallback；hook 在现行设计中是 heavy 独有且对 subagent advisory，主防线是 leader 返回后验证 + merge gate/结构隔离。
- 影响：这份 vendor 资料仍有借鉴价值，但对 omni_powers 自身的横向对比已经过期。若后续从该表回看安装/路径设计，会把 `$OP_HOME` 和 hook 误当两版共同基础，冲突于 lite 零侵入与共享脚本方向。
- 建议：更新 bmad-method §9 表格：安装方式改为“install.sh 全局装 skill/agent/scripts；每项目 `/opinit` heavy 或 `/oplinit` lite”；配置注入改为“heavy 可写 env.OP_HOME，lite 不写 settings/CLAUDE.md”；hooks 使用改为“heavy advisory + merge gate，lite 无 hook”。保留 bmad 的“三层配置/Step-file/按需加载”作为可借鉴点。
- 置信度：高。
- 优先级：高。

## 2. gstack 对比未标出“全局配置/自动更新/浏览器重资产”与 omni_powers 零侵入边界的冲突风险

- 位置：`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/gstack.md:22-50`、`184-208`、`274-337`、`698-733`；design §5.3、§0.1、§3.3、§5.1。
- 现象：gstack 文档完整描述 setup 会写 `~/.claude/settings.json`、`~/.gstack/config.yaml`、项目 `CLAUDE.md`、可选 SessionStart auto-update、Plan-tune hooks、Browse Daemon 等，但没有在“与 omni_powers 的适配边界”中明确：这些机制多数只适合作为反例/外部参考，不应被纳入 omni_powers lite；heavy 也应避免自动更新与全局常驻浏览器这种高侵入运行时。
- 影响：gstack 的浏览器验证、安全栈、E2E eval infra 对 design 的 evaluator/可测性契约有参考价值；但其安装和常驻能力与 omni_powers 当前“lite 零侵入、heavy 主防线不靠 hook、脚本确定性计算”方向冲突。缺少边界说明会让后续维护者把 gstack 的“强工具全家桶”当成可直接搬运项，放大安装、权限、token、维护成本。
- 建议：在 gstack 文档末尾新增“对 omni_powers 的取舍”小节：可借鉴 Browse Daemon 的结构化浏览器信号、E2E session runner、redact pre-push 思路；不建议引入 SessionStart 自动升级、项目 CLAUDE.md 路由注入、全局 telemetry/learn 目录、常驻浏览器作为核心依赖；如未来引入浏览器能力，应作为 evaluator 可选 driver，不进入 install/init 默认路径。
- 置信度：高。
- 优先级：高。

## 3. trellis hook 注入价值未与 design 的“hook 不作安全边界”原则绑定，容易被误读为可替代 dispatch 脚本/结构隔离

- 位置：`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/trellis.md:122-129`、`167-245`、`470-522`；`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/overview.md:186-187`；design §0.1、§2.5、§3.3、§3.4、§5.7。
- 现象：trellis 文档客观写出 SessionStart、UserPromptSubmit、PreToolUse 子 agent 上下文注入机制，并在 `trellis.md:220-223` 提到“不可作为访问控制、写权限隔离或硬安全边界”。overview 也在最后建议“可借鉴动态摘要；不可作为访问控制或硬隔离依据”。但 trellis 单篇中“关键价值：比 superpowers 少依赖 leader 手写 prompt，更多靠 hook 保证上下文一致”这类措辞没有进一步映射到 omni_powers 当前 design：dispatch 脚本负责 review-package/eval_brief 机械组装，hook 对 subagent deny 失效，访问隔离靠 worktree/merge gate。
- 影响：trellis 是三份中最贴近 omni_powers 的 leader-worker/context injection 参考。若单篇被脱离 overview 阅读，可能误导实现方向：用 PreToolUse prompt 注入替换 `op_assemble_eval_brief.sh`、workset 注入、merge gate 或 sparse checkout，从而削弱 design 的被监督者之外证据链。
- 建议：在 trellis 文档 §4.2 或 §8 后补一段“映射到 omni_powers”：只借鉴“动态摘要/派发前上下文补齐/marker 防重复注入”；不可替代 eval_brief 机械组装、worktree 访问隔离、merge gate 白名单；lite 可用提示词级隔离但须显式标弱于 heavy。
- 置信度：高。
- 优先级：高。

# 中低优先级问题

## 1. 三份 vendor 单篇都缺少“当前仍服务 design 的条目清单”，读者需要自行从长文抽取

- 位置：`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/bmad-method.md` 全文；`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/gstack.md` 全文；`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/trellis.md` 全文；design §0、§2.5、§4.1、§5。
- 现象：三份资料是 repo 调研报告，信息密度高，但没有按现行 design 重新标注“保留借鉴 / 明确不采纳 / 已被 design 吸收 / 与 lite 冲突”。overview §6 有横向启示，但单篇本身缺少维护决策。
- 影响：资料仍有价值，但维护成本上升。后续审阅者要反复重读长文判断哪些机制仍可借鉴，容易把旧讨论当待办，或把已吸收机制重复设计。
- 建议：三篇各补一个固定小节“对 omni_powers 当前 design 的状态”：
  - bmad-method：保留“三层配置、Step-file、按需加载”参考；不采纳 persona/Party Mode；安装对比需更新。
  - gstack：保留浏览器/QA/E2E infra/redact 思路；不采纳默认 auto-update、全局 telemetry、路由全家桶、常驻浏览器默认依赖。
  - trellis：保留动态上下文注入、workflow breadcrumb、task CLI 状态机参考；不采纳 hook 作为安全边界或跨平台复杂适配为近期目标。
- 置信度：高。
- 优先级：中。

## 2. overview 已浓缩三份结论，单篇与 overview 之间存在重复但缺少索引反向链接

- 位置：`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/overview.md:141-162`、`175-201`、`230-235`；三份 vendors_repo 详细文档。
- 现象：overview 已总结 bmad-method、gstack、trellis 的核心机制与对 omni_powers 的建议；单篇仍完整保留安装、工具、状态、编排细节。重复本身合理，但单篇没有顶部链接回 overview 的“当前采纳判断”，overview 也只说“详细分析见 vendors_repo/{repo}.md”，没有标明哪些单篇是历史调研、哪些仍为活动参考。
- 影响：不构成设计冲突，但索引语义弱。维护者可能在单篇和 overview 间来回找最新判断，尤其当单篇旧对比表过期时，无法知道以 overview 还是单篇为准。
- 建议：在三篇顶部加状态横幅：`状态：历史调研资料；当前采纳/不采纳判断以 overview §6-§9 与 docs/omni_powers_design.md 为准`。在 overview 快速定位表加“当前用途”列：如“bmad=配置模型参考”“gstack=浏览器验证参考”“trellis=动态上下文注入参考”。
- 置信度：高。
- 优先级：中。

## 3. bmad-method 的“task 管理强度/状态管理”表述与 design 的 task:spec 1:1、无独立 plan 文档原则混用时需加边界

- 位置：`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/bmad-method.md:439-468`、`472-501`；`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/overview.md:64-70`、`220-224`；design §0 原则 8、§1.1、§2.3。
- 现象：bmad-method 被归为“memlog + manifest + sprint 状态”的中强 task 管理，并描述四阶段产物 brief/PRD/architecture/stories 逐步输入。design 已明确 omni_powers 不设独立 plan 文档，顺序依赖归 tasks_list/checkpoint，跨 task 技术决策复制进 spec，task:spec=1:1。
- 影响：bmad 的阶段产物适合方法论参考，但不应回流为 omni_powers 的新增 PRD/architecture/story 链条。当前单篇未标边界，可能诱发文档体系膨胀。
- 建议：把 bmad 的可借鉴点限定为“step-file 渐进加载”和“配置三层合并”，而非“多阶段产物链”；若引用 PRD/architecture/stories，应映射到 opspec 闸门 A 内联探索与 op_blueprint heavy 真相源，不新增 execution plan 文档。
- 置信度：中。
- 优先级：中。

## 4. gstack 的 E2E/LLM-judge 资料可用，但当前没有映射到 omni_powers evaluator baseline/P2 夜跑路线

- 位置：`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/gstack.md:506-567`；design §2.5、§2.7、§3.3、§4.2。
- 现象：gstack 详细记录了 hermetic local E2E、`claude -p` session runner、partial eval store、LLM-as-judge、gate/periodic 分层。design 的 evaluator 固化 PASS 测试、baseline、系统夜跑仍处 P2/P3 规划；单篇没有把 gstack 这部分标注为后续 P2/P3 可参考实现。
- 影响：不是冲突，但会错失维护价值。gstack 文档中最可转化为 omni_powers 的不是 router/auto-update，而是 E2E eval infra 的分层、partial 保存、diff-based test selection、hermetic env。
- 建议：在 gstack 文档末尾增加 P2/P3 映射：`session-runner` 对应系统层夜跑；`eval-store partial/finalize` 对应 acceptance 证据归档；`gate/periodic` 对应结构化硬门与定期体检；LLM-judge 只能 advisory，不应替代 evaluator hard-pass gate。
- 置信度：高。
- 优先级：中。

## 5. trellis 的跨平台适配和 channel/parent-child 能力与当前“严格串行”原则冲突，应标为非近期路线

- 位置：`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/trellis.md:486-514`；design §0 原则 9、§2.4、§3.4、§5.1。
- 现象：trellis 支持 16 个平台、Sub-agent/Inline 双模式、channel 多 agent 通信、parent/child task 树。design 当前明确 Claude Code only、task 严格串行、并行需先解决共享文件写入协议、多 task 分支回流协议。
- 影响：这些能力可作为远期参考，但若被当作近期实现目标，会直接冲突于“task 严格串行”和“共享流程文件单副本”安全模型。
- 建议：trellis 文档中标注：跨平台/Channel/Parent-child 为远期研究，不进入当前 P0-P2；当前只参考 hook 注入的“摘要压缩”与 task 状态文件化，不参考并行 worker 通信。
- 置信度：高。
- 优先级：中。

## 6. 三份 vendor 资料不应归档，但应降为“历史调研 + 参考索引”，避免进入运行时上下文

- 位置：`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/bmad-method.md`；`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/gstack.md`；`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/vendors_repo/trellis.md`；design 第 3 行定位说明。
- 现象：三份资料仍服务 design：bmad 支撑配置/step-file取舍，gstack 支撑浏览器验证/E2E infra取舍，trellis 支撑动态上下文注入/状态机取舍。它们不在运行时上下文内，也未被 CLAUDE.md 要求加载；overview 已作为总入口。
- 影响：无需移入 `docs/archive/`，否则会削弱 vendors_analyze 的横向索引完整性。但若不标状态，也容易被误作当前设计契约。
- 建议：保留在 `docs/vendors_analyze/vendors_repo/`，不归档；加状态横幅“非契约、非运行时，仅调研参考；现行契约以 design/RULES/skills/agents 为准”。若后续清理重复，优先把过期的 omni_powers 对比表更新，而不是删除单篇。
- 置信度：高。
- 优先级：低。

# 改进建议

1. 给 `docs/vendors_analyze/vendors_repo/*.md` 统一加 frontmatter 或状态块：`status: research-reference`、`contract: false`、`last_reviewed: 2026-07-08`、`current_use:`。
2. 在 overview 增加“采纳矩阵”：repo × {已吸收、可借鉴、明确不采纳、远期研究}，减少单篇长文重读成本。
3. 对所有 vendor 单篇的“与 omni_powers 对比”段设维护规则：凡 design 改 heavy/lite 安装、hook、安全模型、状态机，必须同步更新 vendor 对比表或删除该表改为指向 overview。
4. 将 gstack/Trellis 中可转化为 P2/P3 的技术点抽成单独 `spec_and_plan_comparison.md` 或 design backlog 小节，避免混在 repo 描述里被遗忘。
5. 保持 vendor 资料只读参考，不进入 `$OP_HOME/RULES.md`、agent prompt、skill runtime 文档，防历史调研污染运行时契约。

# 不确定项

1. 三份 vendor 资料采集时间为 2026-07-02 左右，外部 repo 可能已变化；本次按本地资料与当前 design 一致性审阅，未联网复核上游。
2. 是否已有其他分块负责统一更新 vendors_analyze/overview 未确认；本报告只提出报告级问题，不修改源资料。
3. `docs/vendors_analyze/spec_and_plan_comparison.md` 未纳入本分块目标，未判断其中是否已承接三份资料的采纳矩阵。
