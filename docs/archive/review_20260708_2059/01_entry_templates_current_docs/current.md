## 当前模型判断依据

- 仅基于可观测来源判断，不读取运行时内部状态。
- 已知 `/home/karon/.claude/settings.json` 顶层 `model` 为 `default_model`，`env.ANTHROPIC_MODEL` 为 `default_model`。
- 已知同文件 `env.ANTHROPIC_DEFAULT_HAIKU_MODEL` 为 `default_haiku[1m]`，`env.ANTHROPIC_DEFAULT_SONNET_MODEL` 为 `default_sonnet[1m]`，`env.ANTHROPIC_DEFAULT_OPUS_MODEL` 为 `default_opus[1m]`。
- 主会话环境提示显示当前会话 powered by `default_model`。
- 结论：current 路不设置 model 覆盖，继承主会话；可观测上应为 `default_model`。settings 中 secret 已省略，报告未写入 secret。

## 审阅范围

核心规格：
- `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md`

本分块逐文件审阅：
- `/home/karon/karson_ubuntu/omni_powers/.gitattributes`
- `/home/karon/karson_ubuntu/omni_powers/.gitignore`
- `/home/karon/karson_ubuntu/omni_powers/CLAUDE.md`
- `/home/karon/karson_ubuntu/omni_powers/RULES.md`
- `/home/karon/karson_ubuntu/omni_powers/docs/op_decisions.md`
- `/home/karon/karson_ubuntu/omni_powers/docs/op_first_run.md`
- `/home/karon/karson_ubuntu/omni_powers/docs/op_install.md`
- `/home/karon/karson_ubuntu/omni_powers/docs_template/omni_powers/README.md`
- `/home/karon/karson_ubuntu/omni_powers/docs_template/omni_powers/index.md`
- `/home/karon/karson_ubuntu/omni_powers/docs_template/omni_powers/op_blueprint/architecture.md`
- `/home/karon/karson_ubuntu/omni_powers/docs_template/omni_powers/op_blueprint/baselines/baselines_index.md`
- `/home/karon/karson_ubuntu/omni_powers/docs_template/omni_powers/op_blueprint/conventions.md`
- `/home/karon/karson_ubuntu/omni_powers/docs_template/omni_powers/op_blueprint/domain.md`
- `/home/karon/karson_ubuntu/omni_powers/docs_template/omni_powers/op_blueprint/prd.md`
- `/home/karon/karson_ubuntu/omni_powers/docs_template/omni_powers/op_blueprint/spec_index.md`
- `/home/karon/karson_ubuntu/omni_powers/docs_template/omni_powers/op_blueprint/specs/{feature}.md`
- `/home/karon/karson_ubuntu/omni_powers/docs_template/omni_powers/op_blueprint/test.md`
- `/home/karon/karson_ubuntu/omni_powers/docs_template/omni_powers/op_execution/issues/I-{YYYYMMDD}-{NN}.md`
- `/home/karon/karson_ubuntu/omni_powers/docs_template/omni_powers/op_execution/issues/{TID}_quality.md`
- `/home/karon/karson_ubuntu/omni_powers/docs_template/omni_powers/op_execution/leader_checkpoint.md`
- `/home/karon/karson_ubuntu/omni_powers/docs_template/omni_powers/op_execution/tasks/{TID}/report.md`
- `/home/karon/karson_ubuntu/omni_powers/docs_template/omni_powers/op_execution/tasks/{TID}/review.md`
- `/home/karon/karson_ubuntu/omni_powers/docs_template/omni_powers/op_execution/tasks_list.json`
- `/home/karon/karson_ubuntu/omni_powers/docs_template/omni_powers/op_record/decisions.md`
- `/home/karon/karson_ubuntu/omni_powers/docs_template/omni_powers/op_record/progress.md`

审阅方式：逐文件、逐段读取；源文件只读；仅写入本报告。

## 高优先级问题（CRITICAL / HIGH）

1. 位置：`docs_template/omni_powers/op_execution/tasks_list.json:6`, `docs_template/omni_powers/op_execution/tasks_list.json:17`, `docs_template/omni_powers/op_execution/tasks_list.json:26`
   - 现象：模板中 task `status` 使用英文值 `ready` / `blocked`，而运行时状态机在 `RULES.md:21-37` 使用中文状态：`待规划`、`待开始`、`进行中`、`审阅中`、`收口中`、`完成`、`阻塞`、`跳过`、`挂起`。design 也强调 `tasks_list.json` 是机读状态源，状态判断交脚本。
   - 影响：新项目由模板初始化后，`op_status.sh`、`op_jq.sh`、`opstatus`、leader checkpoint 等若按中文状态查询，会把模板生成任务识别为未知或不可调度状态；这属于入口模板与运行状态机不一致，可能直接破坏首轮执行。
   - 建议：把模板状态改为 canonical 中文状态。例如待执行 task 用 `待开始`，阻塞示例用 `阻塞`，并补齐 `blocked_by` 取值说明；若实际脚本支持英文别名，则在 `RULES.md` 和 design 明示映射，避免双真相。
   - 置信度：高
   - 优先级：HIGH

2. 位置：`docs_template/omni_powers/op_execution/tasks/{TID}/report.md:17-18`
   - 现象：模板要求测试输出填写“hook 自动跑的受影响测试结果”。但 design 明确指出 Claude Code subagent 不触发 PreToolUse/PostToolUse，hook 自动跑测试对 subagent 已失效；可信度靠 reviewer 双裁决、evaluator 独立验收、merge gate 兜底（`docs/omni_powers_design.md:18-19`）。
   - 影响：implementer 按模板可能等待不存在的 hook 输出，或把自跑测试误标成 hook 产物；reviewer 也可能错误评估证据来源，削弱“机器证据须在被监督者控制之外”这一核心边界。
   - 建议：改为“贴 implementer 本轮自行运行的测试命令与关键输出；不得声称 hook 自动产出。可信性由 reviewer/evaluator/leader 独立验证”。如 heavy 仍有主会话 advisory hook，应明确“仅主会话 advisory，不作为 subagent 证据来源”。
   - 置信度：高
   - 优先级：HIGH

3. 位置：`docs/op_first_run.md:23-32`
   - 现象：首跑文档写“主会话当前为 haiku，不设则全线继承——必须设”，并给出 OP_IMPLEMENTER_MODEL/OP_REVIEWER_MODEL/OP_EVALUATOR_MODEL/OP_CLOSER_MODEL 固定建议。当前可观测模型为 `default_model`，设计与 README 均描述未设模型变量时继承主会话当前模型；且当前模型路由约定已使用 `default_haiku[1m]` / `default_sonnet[1m]` / `default_opus[1m]` 这类默认模型别名。
   - 影响：首跑文档保留旧模型判断，会导致 current 路审阅或首跑操作者误以为必须覆盖模型，破坏“current 继承主会话”的可观测结论，也可能与 settings 中默认模型别名策略冲突。
   - 建议：把该段改成“若不设置角色模型变量，则继承主会话当前模型；是否设置取决于本轮 profile/成本/质量策略”。不要写死“当前为 haiku”。如保留建议档位，应标明是历史首跑建议，不是当前必需条件。
   - 置信度：高
   - 优先级：HIGH

## 中低优先级问题（MEDIUM / LOW）

1. 位置：`docs_template/omni_powers/index.md:14-24`, `docs_template/omni_powers/README.md:27-34`
   - 现象：模板导航与 README 将 `op_blueprint/` 描述为稳定真相和持久文件，但没有在这些入口表格中同步标注 design 的关键限制：`op_blueprint/` 各文档 heavy only；lite 下 `op_blueprint` 为空壳、一律不读，lite 规格读 `op_execution/specs/`（design 文档职责矩阵明确此点）。
   - 影响：lite 项目初始化后，agent 看到 `index.md` / README 容易误读 blueprint 为有效真相源，与 lite “无 blueprint 真相源、工作 spec 兼任生效规格”的差异冲突。
   - 建议：在 `index.md` 的 `op_blueprint/` 标题或表格前加一句“heavy only；lite 下为空壳，不作为读取入口”。README 持久文件表中也给 blueprint 行加 heavy-only 备注。
   - 置信度：中高
   - 优先级：MEDIUM

2. 位置：`docs_template/omni_powers/op_execution/issues/{TID}_quality.md:20-21`
   - 现象：质量阻塞模板写“该 task 标 `status=阻塞, blocked_by=quality`”。但同一模板集的 `tasks_list.json` 用英文 `blocked`，`RULES.md` 用中文 `阻塞`。
   - 影响：模板内部对状态值也出现中英混用。虽然此处中文与 RULES 一致，但与 tasks_list 模板不一致，会放大初始化后手工修复成本。
   - 建议：统一整个模板集状态枚举，以 `RULES.md` 的中文状态机为准；若保留英文 JSON 值，则全套文档统一映射表。
   - 置信度：高
   - 优先级：MEDIUM

3. 位置：`docs/op_install.md`（整体定位）与 `CLAUDE.md:96-101`
   - 现象：`CLAUDE.md` 明确 `docs/op_install.md` 是“历史安装方案（已废弃，留作档案）”。但 `docs/op_install.md` 文件自身前部仍以可执行安装方案口吻组织，若用户直接打开该文件，废弃状态不够显眼。
   - 影响：安装入口可能被误用，尤其设计要求安装统一走 `install.sh`，不再使用手动 `export OP_HOME` 方式。
   - 建议：在 `docs/op_install.md` 顶部增加醒目废弃声明，指向 `install.sh` 与 `CLAUDE.md` 快速开始；历史内容保留为档案即可。
   - 置信度：中
   - 优先级：MEDIUM

4. 位置：`docs_template/omni_powers/op_execution/leader_checkpoint.md:3-4`
   - 现象：模板写每 task 闭环后由 `op_checkpoint.sh {TID}` 自动生成机械部分，并要求跑 `skills/oprun/scripts/close_check.sh`。对 heavy 成立，但 lite 也有独立 `skills/oplrun/scripts/close_check.sh`，且 lite 闭环无 closer、无“收口中”态。
   - 影响：同一 docs_template 用于 heavy/lite 共用时，lite 项目可能被引导调用 heavy 脚本路径，降低“lite 脚本自包含、零侵入”的清晰度。
   - 建议：模板中区分 profile：heavy 用 `$OP_HOME/skills/oprun/scripts/close_check.sh`，lite 用 `$OP_HOME/skills/oplrun/scripts/close_check.sh`；或写成“由当前 profile 对应脚本执行”。
   - 置信度：中
   - 优先级：MEDIUM

5. 位置：`docs_template/omni_powers/op_record/progress.md:3-4`
   - 现象：模板写“每 task 闭环后机械追加一行（`op_close_post.sh` 写）”，未说明 heavy/lite 分别有 `skills/oprun/scripts/op_close_post.sh` 与 `skills/oplrun/scripts/op_close_post.sh`。
   - 影响：小概率引导读者认为只有 heavy 脚本入口；与 lite 自包含脚本边界略不一致。
   - 建议：改为“当前 profile 的 `op_close_post.sh` 写”。
   - 置信度：中
   - 优先级：LOW

6. 位置：`docs_template/omni_powers/op_blueprint/baselines/baselines_index.md:4-5`
   - 现象：模板说明 baselines 与 `specs/{feature}.md` 同键，符合 heavy；但没有标注 lite 无 blueprint/baselines 真相源。
   - 影响：lite 下若 agent 误读该模板，可能把 baseline 更新提案落向 blueprint，而 design 要求 lite 无 blueprint 提炼。
   - 建议：增加“heavy only；lite 不维护此索引”的提示。
   - 置信度：中
   - 优先级：LOW

## 改进建议

1. 建议新增一处 canonical 状态枚举表，供 `RULES.md`、`tasks_list.json` 模板、issue 模板、脚本帮助文本共同引用；避免中英状态混用。
2. 建议在 docs_template 顶层 README 增加 profile 差异短表：heavy 读取 `op_blueprint/`，lite 不读；heavy 用 closer + 闸门 C + blueprint_update，lite leader 机械收口 + 裸评 + P0 检查。
3. 建议清理历史文档口吻：`docs/op_first_run.md`、`docs/op_install.md` 若作为档案保留，顶部都应声明“历史/一次性/可能过期”，避免与当前 design/RULES 竞争。
4. 建议 report/review 模板明确证据来源层级：implementer 自证、reviewer 双裁决、evaluator 独立验收、merge gate 硬拦，各自不要互相冒名。

## 不确定项 / 可能误报

1. `tasks_list.json` 模板英文状态可能只是示意数据，实际初始化脚本可能会重写为中文状态；本次仅审文档与模板，未把脚本行为作为放行依据。若脚本强制转换，问题优先级可下调，但模板仍建议统一。
2. `docs/op_first_run.md` 标题已表明“首跑计划”，可能本来就是历史执行记录；若项目约定 archive 前仍保留旧现场信息，则模型档位问题可视为历史记录而非当前操作指引。但文件未归档，且用户指定审阅当前交付一致性，因此仍列为 HIGH。
3. `leader_checkpoint.md` 与 `progress.md` 引用脚本名未写 profile 路径，实际运行时可能通过当前 skill 工作目录解析；文档层面仍建议显式区分 heavy/lite，避免误导。
