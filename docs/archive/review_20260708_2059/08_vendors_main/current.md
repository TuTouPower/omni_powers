# 当前模型判断依据

可观测来源：settings 顶层 model=default_model；env.ANTHROPIC_MODEL=default_model；默认档位 haiku=default_haiku[1m] / sonnet=default_sonnet[1m] / opus=default_opus[1m]；主会话 powered by default_model。current 路继承主会话。未写入 secret。

# 审阅范围

核心参考：`/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md`

本次只读审阅：

- `/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/deep-discussion-notes.md`
- `/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/overview.md`
- `/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/spec_and_plan_comparison.md`

审阅重点：vendors_analyze 主文档是否作为参考资料定位清晰，是否与现行 design 冲突，是否有应归档/去重/补充索引问题。

# 高优先级问题

## 1. vendors_analyze 缺少“参考资料、非契约源”总声明，容易被误读为现行设计依据

- 位置：`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/overview.md:1-7`；`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/deep-discussion-notes.md:1-6`；`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/spec_and_plan_comparison.md:1-5`；design `docs/omni_powers_design.md:1-5`、`155-168`。
- 现象：三份 vendors 主文档均只说明“分析对象/日期/补充来源”，没有明确“仅为历史调研参考，不是 omni_powers 运行时契约/现行设计真相源”。design 明确自身是设计档案，运行时操作在 RULES/agents/skills，且文档职责矩阵强调单一职责和去重边界。
- 影响：后续 agent 或维护者可能把 vendors 中的 vendor 流程、命令、门禁、状态机描述当成 omni_powers 当前应实现能力，特别是 `overview.md` 第六章“对 omni_powers 的关键启示”和 `spec_and_plan_comparison.md` 各工具流程描述，容易与 design 的唯一契约、两层 spec、task 串行、merge gate 等现行规则混读。
- 建议：三份文档开头统一加定位块：`本文为 vendor 调研参考/历史材料，不是设计契约；现行设计以 docs/omni_powers_design.md 为准；采纳项必须已进入 design/RULES/agents/skills 才生效`。`overview.md` 作为入口还应列出“已采纳/未采纳/仅参考”的映射。
- 置信度：高。
- 优先级：高。

## 2. overview 对 hook 的建议与 design 的安全模型冲突

- 位置：`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/overview.md:184`；design `docs/omni_powers_design.md:19`、`28-35`、`47-51`、`590-610`、`612-615`、`680-684`。
- 现象：overview 建议“hooks 保持最小强约束：锁区、路径、敏感操作、防误删”。design 反复声明 Claude Code subagent 场景 hook deny 整体失效，hook 仅主会话 advisory；真正写入硬底线是 leader 回流时的 merge gate，访问隔离靠 worktree 结构，证据可信靠 reviewer/evaluator/merge gate 兜底。
- 影响：该句会把“hook 是强约束”的旧认知重新引入 vendors 总览，与 design 当前安全模型直接冲突。实现者可能继续把 e2e/spec/blueprint/decisions 保护押在 hook 上，削弱 merge gate、closer gate、worktree 隔离等主防线优先级。
- 建议：改为“主会话 hook 只保留最小 advisory 暴露；强约束应落在 merge gate、git 回流协议、closer gate、trailer/专属通道和独立 CI”。并在 vendors 对 gstack/trellis hook 能力引用处统一加“不可迁移为 omni_powers 的安全边界”。
- 置信度：高。
- 优先级：高。

## 3. deep-discussion-notes 与 overview 大段重复，且 raw notes 未归档

- 位置：`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/deep-discussion-notes.md:154-209`、`377-404`；`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/overview.md:23-88`、`203-228`；design `docs/omni_powers_design.md:155-168`。
- 现象：`deep-discussion-notes.md` 后半部分包含“十个 repo 类型总览”“更新后的七项目类型总览”等内容，`overview.md` 已合并为正式横向总览，并在第八章再次整理“已有背景/七个 repo 类型总览/三个共同点”。两份文档同时保留主文档位置，职责边界不清。
- 影响：同一 vendor 分类与 task 管理结论出现多处维护点。后续修正（例如 hook 安全模型、lite/heavy 借鉴边界、repo 星数/成熟度）容易只改 overview，deep notes 保留旧口径，造成漂移。也违背 design 的文档职责矩阵“重复内容只留一份，其他文档指向即可”。
- 建议：把 `deep-discussion-notes.md` 移入 `docs/archive/` 或在文件头标记“原始讨论笔记，已由 overview 吸收，不再维护”；删除/压缩其第六、十一章重复总览，只保留 overview 未覆盖的原始讨论细节；`overview.md` 保留唯一横向总览入口。
- 置信度：高。
- 优先级：高。

# 中低优先级问题

## 1. overview 的“对 omni_powers 的关键启示”未区分已采纳、待评估、明确不采纳

- 位置：`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/overview.md:175-188`；design `docs/omni_powers_design.md:9-24`、`240-276`、`280-289`、`392-423`、`710-735`。
- 现象：第六章以“对 omni_powers 的建议”呈现 vendor 能力映射，但每项未标明现行 design 是否已吸收。例如“spec 作为唯一契约”“tasks_list.json 作为执行唯一真相”已是设计原则；“三层模型配置”“动态摘要”是未来可选；“浏览器守护进程”明确暂不需要；“hook 自动补齐任务上下文”可借鉴但不可作为安全边界。
- 影响：读者难判断该表是历史启发、待办清单还是 design gap。可能导致重复提案或错误补实现，尤其是配置分层、hook 注入、浏览器能力这些 design 已有取舍的事项。
- 建议：把表增加一列“状态”：`已采纳并落入 design` / `可选待评估` / `明确不采纳` / `仅类比参考`；每行链接到 design 对应章节，例如 spec 契约→§0/§2.2，状态恢复→§1/§5.6，hook 注入边界→§0.1/§3.3。
- 置信度：高。
- 优先级：中。

## 2. spec_and_plan_comparison 缺少与 omni_powers spec/plan 设计的结论映射

- 位置：`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/spec_and_plan_comparison.md:8-22`、`503-531`；design `docs/omni_powers_design.md:13-20`、`240-276`、`278-309`。
- 现象：文档完整比较 10 个 vendor 的 SPEC/Plan 强制程度、格式和触发条件，但结尾只总结 vendor 差异，没有落到 omni_powers 现行选择：调 `/opintake` 即强制 task:spec 1:1；plan 不是独立文档，顺序/依赖进 tasks_list+checkpoint，跨 task 决策复制进 spec，接口契约以代码提交，工作集进 tasks_list。
- 影响：这份文档作为“SPEC 与 Plan”主参考时，读者需要自行回推 omni_powers 为什么不采用 spec-kit 独立 plan、superpowers 函数签名 plan、OpenSpec delta spec 目录等，容易重新引入 design 已否定的独立 plan 文档或过细文件/函数级人工审查。
- 建议：新增“对 omni_powers 的落点”小节：明确已采纳 spec-kit 的模板门禁/NEEDS CLARIFICATION 思路、OpenSpec 的 delta/decisions 记录思想、superpowers 的 TDD/双裁决纪律；明确不采用独立 plan 文档和函数级人工审查，原因引用 design §0 原则 8、§2.3 plan 信息四归宿。
- 置信度：高。
- 优先级：中。

## 3. overview 中 Star/成熟度数据缺少采集来源和过期策略

- 位置：`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/overview.md:10-21`；`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/deep-discussion-notes.md:329`。
- 现象：overview 记录 Star、版本、贡献者、commit 活跃度等量化信息，仅用“采集时量级/生成时间 2026-07-02”描述，没有来源链接、采集命令或“过期后不维护”的声明。deep notes 也含 benchmark/version 等易过期数据。
- 影响：vendors 文档作为参考材料可接受时点快照，但若没有过期策略，未来读者可能误信陈旧热度/成熟度，影响借鉴优先级判断。
- 建议：加“数据为 2026-07-02 快照，仅辅助背景；不作为当前选型依据”。若要保留量化判断，补采集来源或脚本；否则把 Star/贡献者等易变字段移到 archive 或降为“当时观察”。
- 置信度：高。
- 优先级：中。

## 4. vendor slash command 与 omni_powers 入口混杂，只在局部有提示

- 位置：`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/spec_and_plan_comparison.md:33`、`68`、`97`、`118`、`173`、`228`、`314`、`328`、`433`、`454`、`462-467`；`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/overview.md:91-139`。
- 现象：文档大量列出 vendor 命令（`/speckit.*`、`/opsx:propose`、`/spec`、`/autoplan`、`/to-prd` 等）。只有 mattpocock 的 `grill-me/grilling` 段明确说明“vendor 术语，不是 omni_powers 当前入口”。overview 对这些命令没有全局提示。
- 影响：对新维护者或 agent 来说，vendor 命令可能被误认为本仓库应提供或兼容的入口，增加 op skill 命名与外部命令混淆风险。
- 建议：在 `overview.md` 和 `spec_and_plan_comparison.md` 开头统一说明“文中 slash command 均为 vendor 原生命令，omni_powers 当前入口只有 /opinit /opintake /oprun /opstatus /oplinit /oplintake /oplrun 等，详见 README/RULES”。局部 mattpocock 提示可删除或改为全局提示后保留简短注释。
- 置信度：高。
- 优先级：低。

## 5. gstack 浏览器能力表与 design 的 evaluator 通道边界缺少对齐注释

- 位置：`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/deep-discussion-notes.md:55-72`、`95-106`；`/home/karon/karson_ubuntu/omni_powers/docs/vendors_analyze/overview.md:116-128`、`186`；design `docs/omni_powers_design.md:268-270`、`426-439`、`540-542`。
- 现象：vendors 文档强调 gstack “真正看到页面”“Web 强、扩展/Electron/Tauri 无法验证”，overview 建议“Web 项目可借鉴；本体暂不需要内置浏览器守护进程”。但 design 已有更细的通道模型：CDP 优先、cua 补齐、直驱垫后；OS 原生壳层/浏览器 chrome 走 cua；cua 通道无法固化为 CI 可重放测试时用 `.cua-manual` 占位。
- 影响：当前 overview 的“Web 可借鉴”过粗，可能让人误以为只需引入浏览器守护进程即可覆盖 evaluator 验收问题，忽略 design 已将 UI/原生壳层/结构化信号/CI 回放能力拆开处理。
- 建议：在 gstack 借鉴段补一句：omni_powers 不采用“常驻浏览器守护进程”作为内置能力；可借鉴的是“真实操作+截图/console/network 证据”思想，实际通道以 design §2.5 可测性契约和 CDP/cua/直驱决策树为准。
- 置信度：中。
- 优先级：低。

# 改进建议

1. 建立 `docs/vendors_analyze/README.md`：说明目录定位、维护状态、入口文档、已归档 raw notes、与 design 的关系。
2. 将 `overview.md` 设为唯一主索引；`deep-discussion-notes.md` 标 raw/archive；`spec_and_plan_comparison.md` 标专题分析并反链 overview。
3. 给所有 vendor 启示表增加“omni_powers 状态”列：已采纳 / 待评估 / 不采纳 / 仅参考，并链接 design 章节。
4. 对所有涉及 hook、安全、访问隔离、验收通道的 vendor 能力统一加边界注释：不可覆盖 design 的 merge gate/worktree/evaluator 模型。
5. 易过期数据（Star、版本、commit 数、benchmark）统一标快照时间与来源；若无维护计划，移入历史观察。

# 不确定项

1. `docs/vendors_analyze/README.md` 或更上层索引若存在于本分块外，可能已声明目录定位；本次目标只包含三份主文档。
2. 部分 vendor 事实（Star、版本、功能边界）未重新联网核验；本审阅只判断其作为参考资料与现行 design 的一致性。
3. `docs/README` 或项目 README 对 vendors 文档的索引方式未纳入本分块，是否已有“参考资料”标签需跨分块确认。
