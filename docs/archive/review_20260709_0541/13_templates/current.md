## 当前模型判断依据

可观测来源：`/home/karon/.claude/settings.json` 顶层 `model=haiku`；`env.ANTHROPIC_MODEL=default_model`；`ANTHROPIC_DEFAULT_HAIKU_MODEL=default_haiku[1m]`；`ANTHROPIC_DEFAULT_SONNET_MODEL=default_sonnet[1m]`；`ANTHROPIC_DEFAULT_OPUS_MODEL=default_opus[1m]`；主会话环境提示当前由 `default_model` 驱动。不能读取运行时内部状态；current 路继承主会话。

## 审阅范围

已完整阅读上下文：`/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md`。

本次逐文件、逐段审阅以下模板，排除 `vendors/` 与 `docs/archive/`：

- `docs_template/omni_powers/README.md`
- `docs_template/omni_powers/index.md`
- `docs_template/omni_powers/op_blueprint/architecture.md`
- `docs_template/omni_powers/op_blueprint/baselines/baselines_index.md`
- `docs_template/omni_powers/op_blueprint/conventions.md`
- `docs_template/omni_powers/op_blueprint/domain.md`
- `docs_template/omni_powers/op_blueprint/prd.md`
- `docs_template/omni_powers/op_blueprint/spec_index.md`
- `docs_template/omni_powers/op_blueprint/specs/{feature}.md`
- `docs_template/omni_powers/op_blueprint/test.md`
- `docs_template/omni_powers/op_execution/issues/I-{YYYYMMDD}-{NN}.md`
- `docs_template/omni_powers/op_execution/issues/{TID}_quality.md`
- `docs_template/omni_powers/op_execution/leader_checkpoint.md`
- `docs_template/omni_powers/op_execution/tasks/{TID}/report.md`
- `docs_template/omni_powers/op_execution/tasks/{TID}/review.md`
- `docs_template/omni_powers/op_execution/tasks_list.json`
- `docs_template/omni_powers/op_record/decisions.md`
- `docs_template/omni_powers/op_record/progress.md`

约束已遵守：源文件只读；未跑构建、测试；未联网；未使用 TaskCreate/TaskUpdate/TaskList/TaskGet；仅写本报告文件。

## 高优先级问题（CRITICAL / HIGH）

### 1. issue 模板 frontmatter 不在文件首行，质量阻塞模板还缺少 YAML 边界

- 位置：
  - `docs_template/omni_powers/op_execution/issues/I-{YYYYMMDD}-{NN}.md:1-14`
  - `docs_template/omni_powers/op_execution/issues/{TID}_quality.md:1-12`
- 现象：泛 issue 模板先写 `# I-{YYYYMMDD}-{NN}: {标题}`，再写 `---` frontmatter；多数 frontmatter 解析器要求 `---` 位于文件首行。质量阻塞模板没有 `---` 边界，字段也只是普通正文。
- 影响：若 optriage、状态渲染、issue 扫描脚本按 YAML frontmatter 读取，泛 issue 可能读不到元数据，质量阻塞 issue 基本无法结构化解析。P0/P1 汇总、converted_to、blocks_merge 等流程可能漏报。
- 建议：所有 issue 模板统一以 YAML frontmatter 开头：第 1 行 `---`，字段完整后 `---`，标题放 frontmatter 之后。
- 置信度：高
- 优先级：HIGH

### 2. `{TID}_quality.md` schema 与设计中的 issue schema 不一致

- 位置：`docs_template/omni_powers/op_execution/issues/{TID}_quality.md:5-12,20-22`
- 现象：质量阻塞模板使用 `issue_id`，缺 `id`、`title`、`converted_to`、`blocks_merge`；`severity` 只列 `P0 | P1`；正文写 `status=阻塞, blocked_by=quality`。
- 影响：设计 §3.2 规定 issue 元数据统一包含 `id/title/source/spec/severity/tags/status/converted_to/blocks_merge`。当前质量阻塞模板会形成第二套 issue 协议；脚本和人工分诊需兼容两种格式，容易漏掉阻塞来源。`status=阻塞` 还与 tasks_list 机读 ASCII 状态约定冲突。
- 建议：质量阻塞也复用泛 issue schema；可通过 `source: review 两轮到顶`、`tags: [quality, blocker]`、`blocks_merge` 表达差异。正文改为 `tasks_list.status=blocked`，不要出现中文机读状态或未定义 `blocked_by` 字段。
- 置信度：高
- 优先级：HIGH

### 3. `tasks_list.json` 示例使用 `depends_on: null`，破坏依赖字段数组约定

- 位置：`docs_template/omni_powers/op_execution/tasks_list.json:7-9`
- 现象：T0001 示例写 `"depends_on": null`，设计 §2.3 task 元数据示例和调度语义均按数组处理：`"depends_on": ["T0001"]`；无依赖应为空数组。
- 影响：调度器、状态渲染、jq 查询若按数组迭代，`null` 会触发类型分支或报错。模板会被复制到真实项目，核心状态文件一开始就可能不符合脚本预期。
- 建议：无依赖统一写 `"depends_on": []`。在 README 或模板注释补一句：字段永远为数组，禁止 `null`。
- 置信度：高
- 优先级：HIGH

### 4. `tasks_list.json` 示例引入未定义 `blocked_by` 字段和值

- 位置：`docs_template/omni_powers/op_execution/tasks_list.json:24-33`
- 现象：T0003 示例写 `"status": "blocked"` 且 `"blocked_by": "resource"`。设计 §1.1 只定义 `blocked` 状态；下游阻塞由 `depends_on` 推导，不另设状态；task 元数据字段清单不含 `blocked_by`。
- 影响：模板给出非规范字段，会诱导实现脚本或人工把阻塞原因写入 tasks_list，制造 schema 漂移。若后续 schema 校验严格化，示例本身会不通过。
- 建议：删除示例中的 `blocked_by`；阻塞原因写 issue 文件，tasks_list 只保留 `status: "blocked"` 与依赖数组。若确实需要机器字段，应先更新设计和脚本 schema。
- 置信度：高
- 优先级：HIGH

### 5. `decisions.md` 模板把决策记录范围缩窄为“架构决策”

- 位置：`docs_template/omni_powers/op_record/decisions.md:3-13`
- 现象：模板说明“有架构决策才追加”，但设计 §2.4、§2.6、§3.4 要求 decisions.md 承载 spec-delta、red-attribution、blocked-attribution、leader-close、closer 收口等 append-only 记录。
- 影响：执行期需要审计的 spec 变更和红灯归因可能被误认为“不属于架构决策”而不写入，破坏契约边界规则和事后报告追溯。
- 建议：改为“记录需审计的设计探索、spec-delta、红灯归因、阻塞归因、leader-close/closer 收口结论；小决策不记录”。保留 `[来源标记 | TID | Round-N | 日期]` 幂等块头。
- 置信度：高
- 优先级：HIGH

## 中低优先级问题（MEDIUM / LOW）

### 6. baselines 索引把验收标准定义指向 op_execution 工作 spec

- 位置：`docs_template/omni_powers/op_blueprint/baselines/baselines_index.md:3-5`
- 现象：模板写“验收标准的文字定义在 `op_execution/specs/{TID}_{slug}.md`”。但 baselines_index 位于 op_blueprint 稳定真相区；task 闭环后工作 spec 会归档，长期生效规格应在 `op_blueprint/specs/{feature}.md`。
- 影响：后续重验或跨 task 对照评可能引用已归档/非当前版本工作 spec，造成 baseline 与生效规格脱节。
- 建议：改为“验收标准当前定义在 `op_blueprint/specs/{feature}.md`；验收工作区临时 baseline 可追溯来源 task spec”。保留 feature_key 与 specs 同键说明。
- 置信度：高
- 优先级：MEDIUM

### 7. spec_index 模板允许未实现功能进入 op_blueprint

- 位置：`docs_template/omni_powers/op_blueprint/spec_index.md:8-13`
- 现象：模板写“新增功能 /opintake 拆分时补”，状态列含“待 opintake”。op_blueprint/spec_index 设计定位是生效规格索引，收经验收淬炼的当前事实。
- 影响：未实现功能进入稳定真相区后，implementer/reviewer/evaluator 可能把“计划”误读成“当前系统契约”。这会污染 baseline、验收 brief 和后续 task 的生效规格基线。
- 建议：spec_index 只列已实现/已验收闭环功能。新增需求在 `op_execution/specs/` 工作 spec 中表达，验收 PASS + closer 收尾后再补入 op_blueprint。
- 置信度：中
- 优先级：MEDIUM

### 8. leader_checkpoint 模板硬编码 heavy 路径与 `$OP_HOME`

- 位置：`docs_template/omni_powers/op_execution/leader_checkpoint.md:3-4`
- 现象：模板要求运行 `bash "$OP_HOME/skills/oprun/scripts/close_check.sh" {TID}`。设计 §5.4/§5.5 要求 heavy/lite 通过 profile 和 `${OP_SCRIPT_ROOT:-$OP_HOME}` fallback 寻址，lite 不依赖 OP_HOME。
- 影响：lite 项目使用同一模板时会得到不可用命令；compact 恢复/收口检查容易沿 heavy 路径失败。
- 建议：改为 profile 感知说明，例如“由对应 skill 调用 close_check；手动检查用脚本 resolver，不直接硬编码 `$OP_HOME`”。或给 heavy/lite 两条命令。
- 置信度：高
- 优先级：MEDIUM

### 9. index.md 未区分 heavy/lite，且把 SessionStart 注入说成通用行为

- 位置：`docs_template/omni_powers/index.md:3-5,14-25`
- 现象：模板写“SessionStart hook 注入其摘要”，并完整列出 op_blueprint 为稳定真相。设计 §5.3/§5.7 明确 lite 无 SessionStart 注入，op_blueprint 只是空壳且一律不读。
- 影响：lite 项目中该模板会误导 agent 期待 hook 自动发现，或把空 op_blueprint 当契约源读取，削弱 lite 零侵入/profile 驱动语义。
- 建议：在顶部增加 profile 分叉说明：heavy 下 index 可被注入摘要，op_blueprint 为稳定真相；lite 下无 SessionStart，op_blueprint 仅占位，规格读 `op_execution/specs/`。
- 置信度：高
- 优先级：MEDIUM

### 10. progress.md 模板缺少设计要求的 commit 区间、review 结论、验收标准覆盖

- 位置：`docs_template/omni_powers/op_record/progress.md:3-6`
- 现象：模板格式只有 `TID | feature | date | 完成`。设计 §1 目录说明要求 progress 每 task 完成一行包含“commit 区间 + review 结论 + 验收标准覆盖”。
- 影响：事后审计和结束报告无法从 progress 快速追溯变更范围、review verdict、AC 覆盖情况，只能回读 report/review/commit。
- 建议：扩展格式为 `TID | feature | date | commit_range | review | AC覆盖 | 状态`，并与 `op_close_post.sh` 保持一致；若脚本当前只写简版，应同步修脚本或模板不要承诺不一致。
- 置信度：高
- 优先级：MEDIUM

### 11. 泛 issue 模板默认 `tags: [tech-debt]`，会误标所有 issue

- 位置：`docs_template/omni_powers/op_execution/issues/I-{YYYYMMDD}-{NN}.md:8-10`
- 现象：设计 §3.2 中 `tags` 是可选字段，`tech-debt` 与 P 级正交。模板默认所有泛 issue 都带 `tech-debt`。
- 影响：范围外 bug、系统层夜跑失败、P0 阻断等非技术债问题会被误归类，optriage 统计和排期信号变脏。
- 建议：改为 `tags: []` 或 `tags: [{可选}]`，在注释中说明技术债才加 `tech-debt`。
- 置信度：高
- 优先级：LOW

### 12. index.md 把技术栈放进 conventions.md 职责

- 位置：`docs_template/omni_powers/index.md:21-24`
- 现象：index 表中 `conventions.md` 描述为“编码约定、命名、技术栈”。设计 §1.3 与 `architecture.md` 模板均规定技术栈属于 architecture，conventions 不放技术栈。
- 影响：文档职责边界轻微漂移，后续维护可能在 architecture/conventions 双写技术栈。
- 建议：把 `conventions.md` 描述改为“编码约定、命名、文件组织、日志/不可变性等”；技术栈只留 `architecture.md`。
- 置信度：高
- 优先级：LOW

### 13. report/review 模板含过期或不存在的设计引用

- 位置：
  - `docs_template/omni_powers/op_execution/tasks/{TID}/report.md:17-18`
  - `docs_template/omni_powers/op_execution/tasks/{TID}/review.md:25-32`
- 现象：report 写 `design A21`；review 写 `design §7.2 / RULES.md`。当前设计档无 §7.2，A21 也不是稳定章节引用。
- 影响：读者按引用查设计依据会失败；长期看会降低模板可信度。
- 建议：改为稳定章节引用，例如 report 指向 design §3.3/§0.1 的 subagent hook 失效与证据边界，review 指向 design §2.4 review 循环上限。
- 置信度：高
- 优先级：LOW

## 改进建议

1. 为 `tasks_list.json` 增加一段 JSON schema 注释或独立校验说明：`depends_on` 永远数组；`status` 只允许 ASCII 枚举；task 元数据字段以设计 §2.3 为准；阻塞原因写 issue，不写 tasks_list 扩展字段。
2. issue 模板统一一个 schema，质量阻塞只作为泛 issue 的预填变体，避免 optriage 兼容两套解析逻辑。
3. 所有 docs_template 中涉及 heavy/lite 差异的位置加 profile 提示，尤其 `index.md`、`leader_checkpoint.md`、op_blueprint 模板。
4. 把模板中的设计引用统一替换成稳定章节号或机制名，避免 Axx/Dxx 内部决策编号在模板中变成陈旧链接。
5. 对 op_blueprint 模板加一句“lite 模式下本目录仅占位，非契约源”，与设计 §5.7 对齐。

## 不确定项 / 可能误报

- `progress.md` 当前简版格式可能与 `op_close_post.sh` 已实现格式绑定；若脚本确实只支持简版，则该问题是“设计与实现/模板不一致”，不一定能只改模板。
- `tasks_list.json` 额外字段是否被脚本容忍未知；本审阅按设计文档中的 task 元数据唯一源和字段清单判断为 schema 漂移风险。
- `spec_index.md` 中“新增功能 /opintake 拆分时补”可能原意是“验收后由收口流程补入”，但模板文字更像 intake 阶段写入 op_blueprint，因此按误导风险记录。
