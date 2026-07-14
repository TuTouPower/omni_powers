## 当前模型判断依据

- 可观测来源：`/home/karon/.claude/settings.json` 顶层 `model=haiku`；`env.ANTHROPIC_MODEL=default_model`；`ANTHROPIC_DEFAULT_HAIKU_MODEL=default_haiku[1m]`；`ANTHROPIC_DEFAULT_SONNET_MODEL=default_sonnet[1m]`；`ANTHROPIC_DEFAULT_OPUS_MODEL=default_opus[1m]`；主会话环境提示当前由 `default_model` 驱动。
- 不能读取运行时内部状态；current 路继承主会话。

## 审阅范围

已完整阅读设计上下文：`/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md`。

本轮只读审阅以下文件，排除 `vendors/` 与 `docs/archive/`，未运行构建、测试、联网：

- `/home/karon/karson_ubuntu/omni_powers/skills/opinit/SKILL.md`
- `/home/karon/karson_ubuntu/omni_powers/skills/opinit/scripts/opinit_register_hooks.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/opinit/scripts/opinit_skeleton.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/opintake/SKILL.md`
- `/home/karon/karson_ubuntu/omni_powers/skills/opred/SKILL.md`
- `/home/karon/karson_ubuntu/omni_powers/skills/opspec/SKILL.md`
- `/home/karon/karson_ubuntu/omni_powers/skills/opstatus/SKILL.md`
- `/home/karon/karson_ubuntu/omni_powers/skills/optriage/SKILL.md`

## 高优先级问题（CRITICAL / HIGH）

### 1. `/opinit` 重跑会重复注册 Claude hooks

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/opinit/scripts/opinit_register_hooks.sh:54-62`
- 现象：已有 `.claude/settings.json` 时，脚本用 `(($u.hooks // {})[$k] // []) + ($t.hooks // {})[$k]` 直接拼接模板 hooks，没有去重或检测已有 omni_powers hook。
- 影响：`/opinit` 重跑会让同一 hook 重复执行，多次跑测试、多次拦截、多次写日志；Stop/SubagentStop 等 hook 被重复注册后，行为会指数式变吵，甚至误判状态。`opinit_skeleton.sh` 明确强调重跑幂等，但 hook 注册破坏整体幂等性。
- 建议：合并时按 `command` 或 `description + command` 去重；至少过滤已存在的 `$OP_HOME/hooks/run-hook.cmd` 同事件条目。重跑应输出“已存在，跳过”而不是追加。
- 置信度：高
- 优先级：HIGH

### 2. heavy 初始化无 e2e 既有目录探测，可能把用户已有顶层 e2e 纳入保护语义

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/opinit/scripts/opinit_skeleton.sh:25-30`，`/home/karon/karson_ubuntu/omni_powers/skills/opinit/SKILL.md:17-45`
- 现象：脚本无条件 `mkdir -p ... e2e`，步骤零也没有询问顶层 `e2e/` 是否已是用户项目测试目录。设计文档明确写到用户项目已有顶层 `e2e/` 时 init 应探测提示，避免用户既有测试被锁。
- 影响：已有项目若已有 `e2e/`，heavy 后续 hook/merge gate 会把其视为行为层受保护路径，导致用户原本正常维护的 E2E 测试突然进入 omni_powers 专属写入通道；这是初始化阶段的语义污染。
- 建议：步骤零增加 `e2e/` 探测与一次性问询；脚本在 `e2e/` 已存在且未见 omni_powers 标记时只提示，不改变语义。若暂不支持可配置 `OP_E2E_DIR`，至少在 `SKILL.md` 明确默认顶层 `e2e/` 会被纳入保护。
- 置信度：高
- 优先级：HIGH

### 3. `opintake` 仍指示写中文状态，违反 tasks_list ASCII 状态契约

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/opintake/SKILL.md:4-6`、`/home/karon/karson_ubuntu/omni_powers/skills/opintake/SKILL.md:84-86`
- 现象：文档写“task status=`待开始`”和“`tasks_list.json` 已写入 `status=待开始`”。设计文档 §1.1 规定 `tasks_list.json.status` 机读值必须是 ASCII，待开始对应 `ready`。
- 影响：leader 或 agent 按 skill 文本执行时，可能把 `tasks_list.json` 写成中文状态；`op_jq.sh`、`opstatus`、`oprun` 调度若按 ASCII 比较，会查不到 ready task，造成任务不可调度。
- 建议：所有 tasks_list 机读状态写法改为 `status="ready"`；中文“待开始”只允许出现在渲染说明中。
- 置信度：高
- 优先级：HIGH

### 4. `opspec` 把 tasks_list 的 `spec` 字段描述成 TID，和设计/其他 skill 冲突

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/opspec/SKILL.md:31-36`
- 现象：该段写“写进 tasks_list.json 的 `spec` 字段（值为 TID，如 `"T0001"`）”。但设计 §2.3 与 `opintake/SKILL.md:61-73` 规定 `spec` 应是相对路径，如 `specs/T0003_xxx.md` 或 `specs/{TID}_{slug}.md`。
- 影响：若按 `opspec` 写入，dispatch/review/evaluator 根据 `tasks_list.spec` 找工作 spec 时会得到 TID 而非路径，导致读取失败或必须另行猜路径，破坏“tasks_list 为 task 元数据唯一源”。
- 建议：改为“`spec` 字段写 `specs/{TID}_{slug}.md`”；TID 只放 `id` 字段。同步检查所有示例，避免 TID 与 spec path 混用。
- 置信度：高
- 优先级：HIGH

### 5. `optriage` 可把 issue 直接转为 ready task，可能绕过新工作 spec

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/optriage/SKILL.md:65-82`
- 现象：转 task 规则允许设置 `status: ready`，并把 `spec` 设为 issue 所属 spec。issue frontmatter 的 `spec` 是来源 spec/TID，不等于新修复 task 的自足工作 spec；该流程未要求创建 `op_execution/specs/{new_tid}_*.md`。
- 影响：P0/P1 issue 可能被直接塞进 `/oprun` 队列执行，缺少新 task 的验收标准、回归测试契约、workset 与不变量。尤其 fix 类型应“先红后绿”，但这里可能只复用旧 spec，形成免检通道。
- 建议：默认转为 `pending`，交 `/opintake` 生成新工作 spec；只有 issue 文件已明确附带完整工作 spec 路径、AC/INV、workset 且通过闸门 A，才允许 `ready`。`converted_to` 应指向新 TID，新 task 的 `spec` 必须是新 spec path。
- 置信度：高
- 优先级：HIGH

### 6. `optriage` 对 P0 处置前后矛盾

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/optriage/SKILL.md:56-61`、`/home/karon/karson_ubuntu/omni_powers/skills/optriage/SKILL.md:109-112`
- 现象：step 2 写 P0 “进结束报告标注”“不事中阻断归档”；step 5 又写“P0 默认阻断”“闸门 C 呈报”。设计 A18/§3.2 已改为 P0 进结束报告，不事中阻断归档。
- 影响：leader 收尾时可能按旧闸门 C 语义暂停，或把 P0 当成本 spec 必修，破坏 A18 的 autonomy-first 流程；heavy/lite 一致的事后报告语义被冲掉。
- 建议：删除“P0 默认阻断”“闸门 C 呈报”旧语义，统一为“结束报告显著标注，用户事后选择转修复 task / 显式豁免记 decisions / revert”。`blocks_merge` 若保留，应解释为报告语义，不作为当前归档硬阻断。
- 置信度：高
- 优先级：HIGH

## 中低优先级问题（MEDIUM / LOW）

### 7. `opred` 允许 implementer 在 `review.md` 写 Fix-N，违反 review.md 单写者规则

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/opred/SKILL.md:34-37`
- 现象：文本写“implementer 改测试前必须在 `report.md` 的归因段（或 `review.md` 的 Fix-N 段）写明归因”。设计 §1.1/§2.4 明确 `review.md` 单写者是 leader，FAIL 轮 Fix-N 修复说明追加到 `report.md`，不进 `review.md`。
- 影响：implementer 可能修改 `review.md`，在 heavy 下会被 merge gate REJECT；在 lite 下则会污染 reviewer verdict 单写者语义。
- 建议：删除“或 `review.md` 的 Fix-N 段”，统一为 `report.md` 归因段/Fix-N 段；reviewer 只在返回结论中审查归因，不让 implementer 写 review.md。
- 置信度：高
- 优先级：MEDIUM

### 8. `optriage` TID 示例与生成规则不符合四位固定宽度

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/optriage/SKILL.md:69`、`/home/karon/karson_ubuntu/omni_powers/skills/optriage/SKILL.md:96-100`
- 现象：规则写新 task 从 `T{NN+1}` 开始，示例使用 `T06`、`T07`。设计规定 TID 全局单调递增且固定四位宽度：`T0001/T0002/...`。
- 影响：TID 解析、排序、归档路径、baseline 映射可能出现混用；`T06` 与 `T0006` 是否同一任务会变得不确定。
- 建议：所有示例与生成规则统一为 `T%04d`，例如 `T0006`；明确扫描现有 TID 时规范化并拒绝非四位格式。
- 置信度：高
- 优先级：MEDIUM

### 9. `optriage` 给出的 `op_new_task.sh` 命令示例语法不完整

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/optriage/SKILL.md:83-85`
- 现象：代码块为 `bash "$OP_HOME/scripts/op_new_task.sh {TID}`，缺少闭合引号，且参数/用法不完整。
- 影响：leader 照抄会直接 shell 语法错误；更重要的是，该示例暗示转 task 可以只传 TID，和前文需要 title/status/spec/depends_on/workset 不匹配。
- 建议：改为真实可执行命令，或删除代码块，改写为“用 jq/helper 追加完整 task 对象”。若保留 helper，应给出完整参数格式。
- 置信度：高
- 优先级：MEDIUM

### 10. `opspec` 仍写“闸门 A 批准后 commit”，和 opintake 的 commit 授权边界不一致

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/opspec/SKILL.md:164-166`
- 现象：该段写“人批 → `status: approved` + commit + 写保护”。`opintake/SKILL.md:55` 则明确“是否立即 commit 需用户明确授权；闸门 A 批准本身不等于 commit 授权”。
- 影响：内部 skill 被直接调用或被 leader 当作权威时，可能在用户只批准 spec 内容后误以为也批准了 commit。
- 建议：统一为“人批 → status: approved + 写保护；是否 commit 由外层入口按用户授权处理”。
- 置信度：高
- 优先级：MEDIUM

### 11. `opstatus` lite 脚本寻址说明没有落实到命令块

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/opstatus/SKILL.md:11-14`、`/home/karon/karson_ubuntu/omni_powers/skills/opstatus/SKILL.md:25-32`
- 现象：profile 感知段说 lite 应使用 `$SCRIPTS=~/.claude/scripts/omni_powers/` 代替 `$OP_HOME/scripts`；但命令块仍全部写 `bash "$OP_HOME/scripts/op_jq.sh" ...`，没有给出 profile 分支后的实际命令。
- 影响：lite 项目按命令执行会依赖 OP_HOME；这与 lite “不需要 OP_HOME env”目标冲突。新会话/compact 后尤其容易失败。
- 建议：命令块改为先解析 `SCRIPTS`：heavy 用 `$OP_HOME/scripts`，lite 用 `${OP_SCRIPT_ROOT:-$HOME/.claude/scripts/omni_powers}` 或现行共享路径；后续命令统一 `bash "$SCRIPTS/op_jq.sh" ...`。
- 置信度：高
- 优先级：MEDIUM

### 12. `opinit_skeleton` checkpoint 模板残留“跳过”状态

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/opinit/scripts/opinit_skeleton.sh:67-72`
- 现象：模板注释写“完成/待开始/待规划/阻塞/跳过/挂起”。设计 §1.1 当前状态枚举为 `pending/ready/in_progress/reviewing/closing/done/suspended/blocked/obsolete`，没有 `skipped`；废弃态对应 `obsolete`。
- 影响：虽然只是注释，但 checkpoint 是 compact 恢复入口之一，残留“跳过”会诱导 leader/agent 自创状态或误解 obsolete。
- 建议：改为“完成/待开始/待规划/阻塞/废弃/挂起”，或同时标注 ASCII：`done/ready/pending/blocked/obsolete/suspended`。
- 置信度：高
- 优先级：LOW

### 13. `opred` 锁定文件解锁流程残留已删除 test_lock 语义

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/opred/SKILL.md:50-58`
- 现象：文本一方面说 `test_lock.sh 已删`、锁定靠 hook 硬编码；另一方面流程第 5 步仍写“重新锁定”。
- 影响：执行者会困惑是否存在某个锁状态需要恢复；在 hook/merge gate 已成为主防线后，“重新锁定”没有明确操作对象。
- 建议：改为“恢复正常流程：leader 完成修改并记录 decisions，后续由 pre-commit/merge gate 继续保护”。删除“重新锁定”。
- 置信度：中
- 优先级：LOW

### 14. `opinit` 设计章节引用错位

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/opinit/SKILL.md:70-78`
- 现象：文本写“按 `$OP_HOME/docs/omni_powers_design.md §3.3` 文档职责矩阵生成”，但当前设计中文档职责矩阵在 §1.3，§3.3 是机械护栏。
- 影响：blueprint-generator 若按错误章节找规范，会读到 hook/merge gate 内容，而非文档职责矩阵，生成职责边界可能跑偏。
- 建议：改为 `design §1.3`。
- 置信度：高
- 优先级：LOW

### 15. `opstatus` 示例使用非四位 TID 与图标，和机读/渲染边界不够清晰

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/opstatus/SKILL.md:36-49`
- 现象：示例包含 `T04/T05`，不符合 TID 固定四位；同时使用图标作为状态标识。opstatus 是人类渲染层，图标本身不影响机读，但和 ASCII 状态规则并列时容易弱化“机读值只能 ASCII”的边界。
- 影响：低概率诱导文档/issue/task 示例继续扩散 `T04` 短编号；状态图标复制到 checkpoint 或 task title 时会增加跨平台 grep/jq 处理噪声。
- 建议：示例统一 `T0004/T0005`；状态展示建议“中文 + ASCII”，如 `完成(done)`，图标可删。
- 置信度：中
- 优先级：LOW

## 改进建议

1. 建议新增一个“术语/字段单一真相”小表，被所有 core skills 引用：`tasks_list.status` ASCII 枚举、TID 格式、`tasks_list.spec` 必须是相对 spec path、issue `spec` 是来源字段而非新 task spec。
2. 建议给 `opinit_register_hooks.sh` 加 shell 层幂等测试用例：连续运行两次后 `.claude/settings.json` hook 数量不变。
3. 建议在 opinit 步骤零增加固定探测项：profile、顶层 `e2e/`、已有 `.claude/settings.json` hooks、已有 git hooks。初始化类 skill 的风险多来自“已有项目”状态。
4. 建议统一删除旧闸门 C/P0 阻断措辞。当前设计已转向 A18 事后报告，旧语义残留会让 leader 在长流程中分叉。
5. 建议把所有示例 TID 批量改为 `T0001` 形态，避免 `T05/T06/T{NN+1}` 扩散。

## 不确定项 / 可能误报

1. `opinit_register_hooks.sh` 的 hook 重复问题未通过实际运行验证；本轮按只读要求未执行脚本。判断基于 jq 合并表达式的静态行为。
2. `optriage` 是否已有外部脚本强制创建新 spec 未在本模块内体现；本轮只审目标文件。若 `op_new_task.sh` 内部会拒绝无 spec path 的 ready task，则第 5 条影响会降低，但当前 skill 文本仍会误导 leader。
3. `opstatus` 图标问题偏可维护性，不是功能错误；若项目刻意要求人类输出带图标，可忽略图标部分，但 TID 四位格式仍建议修正。
