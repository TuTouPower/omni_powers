## 当前模型判断依据

可观测来源：`~/.claude/settings.json` 顶层 `model=haiku`；`env.ANTHROPIC_MODEL=default_model`；`ANTHROPIC_DEFAULT_HAIKU_MODEL=default_haiku[1m]`；主会话环境提示当前由 `default_model` 驱动。不能读取运行时内部状态；current 路继承主会话，实际为 haiku 档。

## 审阅范围

`docs_template/omni_powers/` 下全部 18 个模板文件（相对仓库根）：

- README.md、index.md
- op_blueprint/: prd.md / architecture.md / domain.md / conventions.md / test.md / spec_index.md / specs/{feature}.md / baselines/baselines_index.md
- op_execution/: tasks_list.json / leader_checkpoint.md / tasks/{TID}/report.md / tasks/{TID}/review.md / issues/I-{YYYYMMDD}-{NN}.md / issues/{TID}_quality.md
- op_record/: decisions.md / progress.md

对照档案：`docs/omni_powers_design.md`（只作上下文核对，不审阅）。源文件只读。

## 高优先级问题（CRITICAL / HIGH）

### H1. 6 个 blueprint 模板章节号系统性错误（HIGH）

- **位置**：`op_blueprint/prd.md`(L3)、`architecture.md`(L3)、`domain.md`(L3)、`conventions.md`(L3)、`test.md`(L3)、`spec_index.md`(L3)
- **现象**：全部标 `> 职责（design §3.3）：...`，把"文档职责矩阵（去重边界）"指向 design §3.3
- **影响**：design §3.3 实际是"机械护栏"（L590），职责矩阵在 §1.3（L155）。模板给 agent/维护者的指路全部错位，agent 读模板想核对职责边界会被引到无关章节，破坏"单一真相源"原则
- **建议**：6 处统一改 `design §3.3` → `design §1.3`
- **置信度**：高（grep 确认 §1.3=职责矩阵、§3.3=机械护栏）
- **优先级**：HIGH

### H2. tasks_list.json 模板 status=blocked 与 blocked_by 字段偏离设计定义（HIGH）

- **位置**：`op_execution/tasks_list.json` L23-28（T0003 示例）
- **现象**：模板示例 `T0003` 标 `"status": "blocked", "blocked_by": "resource"`。但 design §1.1 状态枚举表里 `blocked` 的唯一含义是"两轮到顶（本 task 质量失败）"，阻塞原因固定是 quality；`resource` 不是设计定义的阻塞源
- **影响**：模板是复制起点，用户/agent 照抄会引入设计未定义的 `blocked_by: resource` 语义，污染状态机。design §2.3 tasks_list schema 字段列表（id/title/status/spec/depends_on/workset）也未定义 `blocked_by` 字段——schema 只在 §1.1 状态表描述里提到"下游因依赖未就绪不另设态，由调度器依 depends_on 不选中"，未把 blocked_by 物化为字段
- **建议**：两选一——(a) 删 `blocked_by` 字段，blocked 态由 status=blocked + 语义"质量失败两轮到顶"表达（最贴合设计）；(b) 若保留 blocked_by 作扩展字段，design §2.3 schema 须同步补定义且枚举值限定 `quality`（不收 resource）。推荐 (a)
- **置信度**：高（design §1.1/§2.3 明确）
- **优先级**：HIGH

### H3. review.md 模板默认 verdict: UNKNOWN 留在末行，与 merge gate"读末行"机制冲突（HIGH）

- **位置**：`op_execution/tasks/{TID}/review.md` L34
- **现象**：模板末行是 `verdict: UNKNOWN`，注释（L26-32）说"模板默认 UNKNOWN 不算裁决，避免空 review 被读成 PASS"。但 design §2.4/§3.4 明确 merge gate "从主分支 review.md 末行读 verdict"——若 leader 落盘时未删除/替换 UNKNOWN，merge gate 会读到 UNKNOWN
- **影响**：merge gate 对 UNKNOWN 的处置设计档案未定义（只说读末行）。若 gate 把 UNKNOWN 当非 PASS 直接 REJECT，流程卡死；若当 PASS 放行，则违背"避免空 review 被读成 PASS"的初衷。模板默认值与机制之间存在未定义行为
- **建议**：模板应在注释里明确"leader 落盘前必须把 UNKNOWN 替换为 PASS/FAIL，merge gate 见 UNKNOWN 即 REJECT"；或 design §3.4 补"verdict 非 PASS/FAIL 的末行判定为 REJECT"硬规则。两处择一补齐，消除未定义行为
- **置信度**：中高（机制明确，gate 对 UNKNOWN 的具体处置需看 op_merge_gate.sh 实现——当前未落地，design §0.2）
- **优先级**：HIGH

### H4. leader_checkpoint.md 脚本路径硬编码 $OP_HOME，lite 下失效（HIGH）

- **位置**：`op_execution/leader_checkpoint.md` L4
- **现象**：`> 写完应跑 bash "$OP_HOME/skills/oprun/scripts/close_check.sh" {TID} 验收`。lite 下 OP_HOME 不注入（design §5.2/§5.4，lite 禁写 settings.json env），脚本寻址走 `${OP_SCRIPT_ROOT:-$OP_HOME}` fallback 指向 `~/.claude/scripts/omni_powers/`
- **影响**：模板是 heavy/lite 共用骨架（design §1 两版共用布局），lite 用户照模板跑 close_check 会因 `$OP_HOME` 为空得到 `bash "/skills/..."` 报错。与 design §5.4 环境入口 profile 化方案直接冲突
- **建议**：路径改为 `${OP_SCRIPT_ROOT:-$OP_HOME}/skills/oprun/scripts/close_check.sh`（对齐 §5.4 fallback 写法）；或注释标明"heavy 路径，lite 见 oplrun SKILL.md"。推荐前者
- **置信度**：高（design §5.4/§5.5 明确 fallback 约定）
- **优先级**：HIGH

## 中低优先级问题（MEDIUM / LOW）

### M1. quality issue 模板 frontmatter 不规范，与泛 issue 模板不一致（MEDIUM）

- **位置**：`op_execution/issues/{TID}_quality.md` L5-12
- **现象**：用裸行 `key: value`（`issue_id: {TID}_quality` 等无 `---` 包裹），而泛 issue 模板（`I-{YYYYMMDD}-{NN}.md`）用标准 YAML frontmatter（`---` 包裹）。字段名也不同（`issue_id` vs `id`、`task` vs 泛模板无 task 字段）
- **影响**：两类 issue 同存 `issues/` 目录，解析器（jq/脚本）需两套逻辑，违反单一真相源。frontmatter 不规范也使机读解析失败
- **建议**：quality 模板改用标准 YAML frontmatter + 字段名对齐泛模板（`id`/`title`/`source`/`spec`/`severity`/`tags`/`status`/`blocks_merge`），`task` 作扩展字段统一加入两模板
- **置信度**：高
- **优先级**：MEDIUM

### M2. report.md 模板引用 design A21 标记不存在（MEDIUM）

- **位置**：`op_execution/tasks/{TID}/report.md` L18 注释 `{贴实现者自跑测试命令与关键输出——subagent 不触发 hook，无自动测试结果，design A21}`
- **现象**：design 档案无 A21 标记（grep 确认只有 A11/A16/A17/A18/A19/A20）
- **影响**：悬空引用，维护者按标记查不到依据。可能本意指 §0.1 或 §3.3 关于"subagent 不触发 hook"的论述，但标记编号错误
- **建议**：改为实际存在的章节引用（如 `design §3.3 第 3 层/§0.2 SubagentStop 行`）或删标记只留文字描述
- **置信度**：高（grep 确认无 A21）
- **优先级**：MEDIUM

### M3. issue 模板 frontmatter 新增 created_at 字段未进 design §3.2 schema（MEDIUM）

- **位置**：`op_execution/issues/I-{YYYYMMDD}-{NN}.md` L14、`{TID}_quality.md` L12
- **现象**：两模板都带 `created_at: {YYYY-MM-DD HH:mm UTC+8}`，但 design §3.2 issue frontmatter schema（L575-586）字段列表无 created_at
- **影响**：合理扩展（时序追踪有用）但偏离单一真相源，design 与模板不同步。长期会导致 schema 漂移
- **建议**：design §3.2 schema 补 created_at 字段（推荐，字段有用）；或模板删字段。推荐前者并两模板格式统一
- **置信度**：高
- **优先级**：MEDIUM

### M4. baselines_index.md 模板注释"TID 永不复用（op_execution 层）"语义错位（MEDIUM）

- **位置**：`op_blueprint/baselines/baselines_index.md` L6 注释
- **现象**：注释写 `baselines 按功能名存（与 specs/{feature}.md 同键，1:1 零桥接）；TID 永不复用（op_execution 层）`。baselines 按功能名（feature_key）存，不按 TID——"TID 永不复用"挂在 baselines 注释里语义错位，它是 op_execution/specs 的规则
- **影响**：baselines 模板读者误以为 baselines 与 TID 有索引关系，实际没有。概念混淆
- **建议**：删该句或改为"功能名 feature_key 闸门 A 阶段定（design §2.6 D10），与 TID 解耦"
- **置信度**：高
- **优先级**：MEDIUM

### M5. README.md 缺 acceptance/{TID}/blueprint_update.md 模板条目（MEDIUM）

- **位置**：`README.md` 持久文件表 L17-34
- **现象**：表里 `op_execution/acceptance/` 条目（L22）只写"evaluator 验收工作区（运行时生成）"，未列 closer 产的 `blueprint_update.md`（design §2.6 closer 一段式核心产出）。模板目录下也无该文件模板
- **影响**：blueprint_update.md 是 closer→leader 闸门 C 的关键交接物（design §2.6/§1 目录结构 L103），README 未指引、无模板，agent 生成时缺参考结构
- **建议**：两选——(a) README 补条目 + 新增 `op_execution/acceptance/{TID}/blueprint_update.md` 模板（覆盖 diff 段 + baselines 合入段 + task 归档提案段）；(b) 若刻意不设模板（closer 动态生成），README 显式注明"closer 动态生成，无固定模板"。推荐 (a)
- **置信度**：中高
- **优先级**：MEDIUM

### L1. index.md 引用规则文档路径 $OP_HOME 在 lite 下含糊（LOW）

- **位置**：`index.md` L4、L52-53
- **现象**：`> 设计理由见 $OP_HOME/docs/omni_powers_design.md；运行时操作见 $OP_HOME/RULES.md`。lite 下 OP_HOME 不注入（同 H4）
- **影响**：比 H4 轻——index.md 是给 agent 读的导航页，agent 若在 lite 下读不到 $OP_HOME 会找不到设计档案。但 design §5.7 明确 lite 不读 op_blueprint，index.md 是否在 lite 生效本身存疑（lite 入口是 profile + checkpoint，design §5.3 A17 已去 SessionStart 注入）
- **建议**：注释补"heavy 路径；lite 下 RULES.md/design 寻址见 oplrun SKILL.md"或统一改 fallback 写法
- **置信度**：中
- **优先级**：LOW

### L2. {feature}.md 模板"来源 task"段缺验收标准覆盖映射（LOW）

- **位置**：`op_blueprint/specs/{feature}.md` L18-21
- **现象**：来源 task 段只列 `{TID}：初始建立 / {TID}：追加 X`，未映射各 task 覆盖哪些验收标准。design §2.6 事后报告要求"验收标准追溯矩阵（closer 提案含）"
- **影响**：生效规格是事后报告追溯矩阵的数据源之一，模板未预留映射结构，closer 填写时缺规范
- **建议**：来源 task 段补可选子结构 `{TID}（AC-1, AC-3）` 或表格形态 `| TID | 覆盖 AC |`
- **置信度**：中
- **优先级**：LOW

### L3. decisions.md 模板未体现多来源标记枚举（LOW）

- **位置**：`op_record/decisions.md` L5
- **现象**：头部标记格式 `[来源标记 | {TID} | Round-{N} | YYYY-MM-DD]`，但 design §2.6/§3.4 定义了多种来源标记（red-attribution / spec-delta / blocked-attribution / leader-close 等），模板未列枚举
- **影响**：append-only 多写者文件，标记不统一会破坏"按标识判重"的幂等协议（design §2.6）
- **建议**：模板注释补来源标记枚举清单，对齐 design §2.6
- **置信度**：中
- **优先级**：LOW

### L4. progress.md 格式与 design §1 目录结构描述不一致（LOW）

- **位置**：`op_record/progress.md` L5
- **现象**：模板格式 `- {TID} | {feature} | YYYY-MM-DD | 完成`。design §1 目录结构 L107 描述 progress.md 为"每 task 完成一行（commit 区间+review 结论+验收标准覆盖）"——字段定义不同（模板是 feature+完成，design 是 commit 区间+review 结论+AC 覆盖）
- **影响**：模板与设计描述字段错位，实际生成的 progress 缺 review 结论与 AC 覆盖（这俩是事后报告与追溯的数据源）
- **建议**：统一——要么模板补 commit 区间/review 结论/AC 覆盖字段，要么 design §1 描述改为与模板一致。看哪个是真需求：事后报告（§2.6）确实需要 review 结论与 AC 覆盖，推荐模板补齐
- **置信度**：中高
- **优先级**：LOW

## 改进建议

1. **建立模板-设计交叉引用校验**：H1（章节号）、M2（A21）、L4（progress 字段）都是模板引用 design 失 sync。建议加一个 lint 脚本（grep 模板里的 `design §X.Y` / `design AXX` / `design DXX`，核对 design 档案实际章节/标记存在），CI 跑。一次性投入根治这类漂移
2. **frontmatter 规范统一**：M1（quality 裸行）+ M3（created_at）+ H2（blocked_by）本质是 issue/task schema 不统一。建议定一份 `docs_template/omni_powers/_schema.md` 或在 README 增"frontmatter schema 规范"段，所有模板对照
3. **lite 兼容性审查**：H4（checkpoint 路径）+ L1（index 路径）都是 `$OP_HOME` 硬编码在 heavy/lite 共用模板里。建议批量把模板里的 `$OP_HOME` 改 `${OP_SCRIPT_ROOT:-$OP_HOME}` fallback，对齐 design §5.4
4. **补 acceptance 模板**：M5 缺 blueprint_update.md，而它是 closer 核心产出。优先级应随 closer 稳定而补

## 不确定项 / 可能误报

1. **H3 review.md verdict UNKNOWN**：merge gate（op_merge_gate.sh）未落地（design §0.2 标 P1 未交付），实际对 UNKNOWN 的处置无法验证。若 gate 实现本就"非 PASS 即 REJECT"，则 H3 描述的"卡死"成立；若 gate "UNKNOWN 当 FAIL 但不卡流程"，影响降级。需 gate 落地后复核
2. **L4 progress.md 字段**：design §1 L107 描述与模板不一致，但也可能是 design 描述滞后（模板是后改的、更新的）。需确认哪个是当前意图——若 op_close_post.sh 实际写的就是模板格式，则 design §1 描述才是过期的，问题方向反转
3. **H2 blocked_by 字段**：`{TID}_quality.md` 模板 L21 写"status=阻塞, blocked_by=quality"，说明 quality 模板自己把 blocked_by 当字段用——可能 blocked_by 是已落地但未进 design schema 的实践字段。若是，H2 严重度降低（字段已用，只是 design schema 未补），但仍需 design §2.3 同步
4. **M5 blueprint_update.md**：可能项目刻意不设模板（closer 动态生成，设计档案 §2.6 描述其结构足够）。若如此 M5 不成立，仅需 README 注明。需确认 closer 实践
