## 当前模型判断依据

可观测来源：`/home/karon/.claude/settings.json` 顶层 `model=haiku`；`env.ANTHROPIC_MODEL=default_model`；`ANTHROPIC_DEFAULT_HAIKU_MODEL=default_haiku[1m]`；`ANTHROPIC_DEFAULT_SONNET_MODEL=default_sonnet[1m]`；`ANTHROPIC_DEFAULT_OPUS_MODEL=default_opus[1m]`；主会话环境提示当前由 `default_model` 驱动。不能读取运行时内部状态；current 路继承主会话。本报告按用户授权的 sonnet 视角独立审阅。

## 审阅范围

已按要求先完整阅读上下文设计文档：

- `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md`

本轮仅审阅以下 8 个目标文件，排除 `vendors/` 与 `docs/archive/`，未跑构建、未跑测试、未联网，源文件只读：

- `/home/karon/karson_ubuntu/omni_powers/skills/oprun/SKILL.md`
- `/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/close_check.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_assemble_eval_brief.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_checkpoint.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_close_post.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_close_pre.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_coder_check.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_read_verdict.sh`

## 高优先级问题（CRITICAL / HIGH）

### 1. `op_read_verdict.sh` 对 malformed verdict 返回成功，调用方可能误判为可继续

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_read_verdict.sh:21-36`，关联 `/home/karon/karson_ubuntu/omni_powers/skills/oprun/SKILL.md:178-181`
- 现象：脚本只要没有解析到 `PASS|FAIL`，就输出 `result: NONE` 并 `exit 0`。同时 `SKILL.md` 写明判定阶段 `exit 0 = PASS, exit 1 = FAIL`。若 `review.md` 中存在 malformed verdict（如 `verdict: pass`、`verdict: PASS ` 后有不可见字符、最后一行缺失但中间有非标准行），脚本会以成功码返回。
- 影响：leader 若按文档只看 exit code，会把 `NONE` 当作 PASS 路径，导致未完成或格式错误的 review 进入验收/merge 后续流程。此处是质量闸门读数点，属于假绿风险。
- 建议：判定阶段脚本应区分三态退出码，例如 `PASS=0`、`FAIL=1`、`NONE/INVALID=2`；或保留现有脚本输出，但 `SKILL.md` 必须要求读取 `result:` 字段而非只看 exit code。另建议校验最后一条非空行必须精确匹配 `verdict: PASS|FAIL`。
- 置信度：高
- 优先级：HIGH

### 2. `op_read_verdict.sh` 未强制 verdict 为文件最后一行，违反 reviewer 协议

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_read_verdict.sh:21-22`，关联 `/home/karon/karson_ubuntu/omni_powers/skills/oprun/SKILL.md:171`
- 现象：文档要求 `review.md` 文件最后一行必须写 `verdict: PASS` 或 `verdict: FAIL`，但脚本实现为扫描全文件所有匹配行后取最后一个匹配项。若 reviewer 在 verdict 后继续追加说明、日志或误写内容，脚本仍会接受前面的 verdict。
- 影响：末行协议失效，review 文件可能含未审结尾或补充风险，但仍被 gate 读成 PASS。`op_close_post.sh` 使用相同宽松逻辑读取 PASS，问题会贯穿收口。
- 建议：以 `tail` 取最后一条非空行，并精确匹配 `^verdict:[[:space:]]*(PASS|FAIL)$`。若不匹配，返回 INVALID，并阻断后续流程。
- 置信度：高
- 优先级：HIGH

### 3. `op_assemble_eval_brief.sh` 未按设计提供生效规格正文，仅 cat `spec_index.md`

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_assemble_eval_brief.sh:39-46`
- 现象：脚本标题与注释写「生效规格（开工前基线）」和「按 TID 定位对应 specs/{feature}.md」，但实际只输出 `op_blueprint/spec_index.md` 的全文，没有定位并嵌入对应 `op_blueprint/specs/{feature}.md` 生效规格正文。
- 影响：evaluator brief 缺失关键契约正文，只能看到索引，无法对照当前功能的生效规格、历史边界和不变量。设计文档 §2.5 要求 eval brief 包含「工作 spec / 生效规格开工前基线 / baselines 索引」，此实现削弱独立验收与回归判断，可能漏掉与既有规格冲突的行为。
- 建议：从 task spec frontmatter 或 `tasks_list.json` 中读取 `feature_key`/`feature`，再解析 `spec_index.md` 或直接拼出 `op_blueprint/specs/{feature}.md`，将该文件正文写入 brief；找不到时明确输出缺失并让 evaluator 标记相应 AC 为证据不足，而不是只给索引。
- 置信度：高
- 优先级：HIGH

### 4. `op_assemble_eval_brief.sh` 剥离设计探索结论的 awk 匹配层级错误

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_assemble_eval_brief.sh:33-36`
- 现象：脚本只匹配 `^## 设计探索结论`，但设计文档 spec 模板中该段是 `### 设计探索结论：命中方案先行信号时`，位于 `## 技术决策` 下。当前 awk 不会剥离模板中的实际段落。
- 影响：evaluator brief 仍会包含设计探索结论、候选方案、推荐方案、已知坑等过程性信息，违背「防 evaluator 被过程带偏」的隔离目标。evaluator 可能受实现方案暗示影响，降低裸评独立性。
- 建议：改为识别 `^#{2,3}[[:space:]]*设计探索结论`，并跳到下一个同级或更高级标题。若还需剥「已知坑」，需同步覆盖模板中的子项，而不是只剥单一标题。
- 置信度：高
- 优先级：HIGH

### 5. `op_close_post.sh` 文档声称校验 merge gate / decisions commit，实际未实现

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oprun/SKILL.md:261-264`，`/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_close_post.sh:31-48, 74-93`
- 现象：`SKILL.md` 注释写 `op_close_post.sh` 前置检查包含 `review verdict PASS + merge gate PASS + decisions.md 存在本 TID closer append 块且已 commit`，但脚本只校验 `report.md`、`review.md`、`eval.md` PASS，然后归档并更新状态。没有检查 merge gate PASS 证据，也没有检查 closer 是否追加 `decisions.md`，更没有检查该追加块是否已 commit。
- 影响：task 可在未确认 merge gate、未沉淀红灯归因/closer append 的情况下被标记 done 并归档。此处直接破坏设计 §2.6/§3.4 的写入硬底线与决策沉淀链路。
- 建议：若 merge gate 当前仍是 P1 未完全落地，文档需改为「未实现」。若已要求运行，则脚本应读取明确证据文件或 commit trailer；同时 grep `[来源标记 | {TID} | ...]` 类 block 并用 `git diff --quiet HEAD -- docs/omni_powers/op_record/decisions.md` 或 commit 范围校验其持久化状态。
- 置信度：高
- 优先级：HIGH

### 6. `op_close_post.sh` 的 stage 边界遗漏 blueprint / decisions / issues，容易提交不完整收口

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_close_post.sh:89-93`，关联 `/home/karon/karson_ubuntu/omni_powers/skills/oprun/SKILL.md:253-269`
- 现象：Stage 4 要求 leader 自审写入 `op_blueprint/`、合入 baselines、落 issues、追加 decisions、归档 acceptance。但 `op_close_post.sh` 最终只 `git add`：`op_record/tasks/{TID}`、`op_record/progress.md`、`op_execution/tasks_list.json`。虽然 `git mv` 对 task/spec/acceptance 的移动本身会进入 index，但 leader 在脚本前手动写入的 `op_blueprint/**`、`op_record/decisions.md`、`op_execution/issues/**` 不会被脚本纳入。
- 影响：按 `SKILL.md` 示例直接 `op_close_post.sh` 后 `git commit`，可能只提交归档和状态，不提交 blueprint 更新、决策记录和 issue 转存，造成「task done 但真相源未更新」或未提交残留。后续 task 读取旧 blueprint，状态与契约漂移。
- 建议：明确两段式 stage：要么 `op_close_post.sh` 只做归档并不承诺 stage 全量，`SKILL.md` 要求 leader 显式 `git add` 自审采纳的全部路径；要么脚本接收/推导 feature_key 后纳入 `op_blueprint/**`、`op_record/decisions.md`、`op_execution/issues/**`、`op_record/acceptance/{TID}` 等允许范围，并先跑 closer gate/路径白名单。
- 置信度：高
- 优先级：HIGH

### 7. `SKILL.md` 收尾顺序把 commit 放在 checkpoint 之前，导致 checkpoint 更新不会进入该 task commit

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oprun/SKILL.md:266-269`，`/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_checkpoint.sh:1-6, 20-55`，`/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/close_check.sh:42-50`
- 现象：`SKILL.md` 示例顺序是 `git commit` 后运行 `op_checkpoint.sh {TID}`，随后运行 `close_check.sh {TID}`。`op_checkpoint.sh` 会修改 `leader_checkpoint.md`，但之后没有第二次 commit。`close_check.sh` 对非本 task 残留只 WARN，不阻断。
- 影响：每个 task 闭环后 checkpoint 变更会以未提交 dirty 状态遗留，或被下个 task 混入后续 commit。恢复时依赖 checkpoint 的「已完成 task / tasks_list 状态」可能不在 Git 历史中对应当前 task commit，破坏可恢复性与 task 即 commit 追踪。
- 建议：调整顺序为 `op_close_post.sh` → `op_checkpoint.sh` → `close_check.sh` → `git status` → `git commit`；或保留 commit 后 checkpoint，但必须紧跟第二个 checkpoint commit，并在 close_check 中将 checkpoint dirty 设为 FAIL。
- 置信度：高
- 优先级：HIGH

### 8. `SKILL.md` 多处仍使用中文状态值，和设计的 ASCII 机读状态冲突

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oprun/SKILL.md:115, 121-131`，关联设计文档 §1.1 状态枚举
- 现象：设计明确 `tasks_list.json.status` 机读值为 ASCII：`ready/in_progress/reviewing/closing/done/...`，脚本也按 ASCII 处理。但 `SKILL.md` 子步骤 3.1 写「status=待开始」，而 `op_coder_check.sh` 说明和动作表混用中文语义与 ASCII 输出。
- 影响：leader 按文档执行 jq 选 task 时可能查中文 `待开始`，导致找不到可跑 task；或在状态切换、阻塞判断中混用中文状态。作为 skill 运行手册，这属于高概率操作偏差。
- 建议：所有机读条件统一改为 ASCII：`status=ready`，展示层可写「渲染为待开始」。检查整份 `SKILL.md`，避免中文状态出现在 jq 条件或脚本输入语境中。
- 置信度：高
- 优先级：HIGH

### 9. `SKILL.md` dispatch prompt 要求 implementer 自行 jq `tasks_list.json`，违反设计的 subagent 文件视图约束

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oprun/SKILL.md:135-151`，关联设计文档 §2.4、§3.4
- 现象：`SKILL.md` 派 implementer 前写「取元数据: jq 查 tasks_list.json」，prompt 也写「取元数据: jq 查 tasks_list.json 该 task」。但设计文档明确 `tasks_list.json` 不挂给任何 subagent，`workset/depends_on` 应由 dispatch 脚本提取注入 prompt/review-package。
- 影响：按当前 prompt 执行时，implementer 在隔离 worktree 中可能找不到 `tasks_list.json`，直接失败；若实际 worktree 挂载了该文件，又违反设计中流程文件单副本和 subagent 读权收敛目标。
- 建议：修改 SKILL.md：leader/dispatch 在派发前读取 task 元数据并注入纯文本摘要；implementer 只读 spec 与注入的 workset/depends_on，不自行 jq `tasks_list.json`。
- 置信度：高
- 优先级：HIGH

### 10. `op_close_pre.sh` 在 closer 返回后才标记 closing，无法支撑 closing 状态恢复

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oprun/SKILL.md:235-249`，`/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_close_pre.sh:1-14`
- 现象：流程先派 `op-closer`，closer 返回后才运行 `op_close_pre.sh` 将 task 状态标为 `closing`。但 `SKILL.md:61` 又声明存在 `status=closing` 时「从 checkpoint 恢复，跳到收口子步骤」。如果 closer 执行中会话中断，状态仍停留在前一阶段，无法通过 `closing` 恢复到收口。
- 影响：closing 状态失去表达「closer 正在收口」的主要价值；中断恢复可能回到错误阶段，重复派 reviewer/evaluator/closer 或漏处理 closer 半成品。
- 建议：在派 closer 前运行 `op_close_pre.sh`，或新增 `closing` 子状态/检查逻辑区分「closer 未派 / closer 已返回待自审」。若坚持当前顺序，应删除 `closing` 恢复语义，避免误导。
- 置信度：中高
- 优先级：HIGH

## 中低优先级问题（MEDIUM / LOW）

### 11. `op_close_post.sh` 归档 spec 时对缺失 glob 不耐受，部分重跑会被 `set -euo pipefail` 中断

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_close_post.sh:50-64`
- 现象：在 `ACTIVE_DIR=$TASK_DIR` 分支中，`SPEC_SRC="$(ls ... | head -1)"` 没有 `|| true`。脚本启用 `set -euo pipefail`，若 task 目录尚在但 spec 已被上一次部分执行移动或缺失，`ls` 失败会导致脚本直接退出，而不是走后续容错。
- 影响：归档过程不完全幂等。中断恢复时若 task 目录和 spec 归档状态不一致，脚本不能给出清晰业务错误，也无法继续完成剩余归档。
- 建议：改用 shell glob 数组并显式判断数量；缺失时输出 `WARN` 或 `die`，但不要由 `ls` 管道隐式退出。若目标是幂等重跑，应检测 `op_record/specs/{TID}_*.md` 是否已存在。
- 置信度：中高
- 优先级：MEDIUM

### 12. `op_assemble_eval_brief.sh` 对工作 spec glob 只取第一个，未校验唯一性

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_assemble_eval_brief.sh:19-21`
- 现象：脚本用 `ls specs/${TID}_*.md | head -1` 取工作 spec。若目录中存在重复 TID 文件（例如重命名残留、大小写差异、废弃副本），脚本会静默选择排序第一项。
- 影响：evaluator 可能基于错误 spec 验收，造成验收结论和实际 task 不一致。TID 全局唯一是系统不变量，脚本应在这里机械校验。
- 建议：使用数组收集匹配项，要求数量等于 1；数量为 0 或大于 1 均 `die` 并列出匹配路径。
- 置信度：高
- 优先级：MEDIUM

### 13. `op_checkpoint.sh` 对缺失 task title 未做强校验，可能写入 `null`

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_checkpoint.sh:17-25`
- 现象：`jq -r ".tasks[] | select(.id == \"$TID\") | .title"` 在找不到 task 时可能输出空或 `null`，脚本只判断 `-n "$TITLE"`。`null` 是非空字符串，会被写入 checkpoint。
- 影响：错误 TID 或损坏的 `tasks_list.json` 会污染 `leader_checkpoint.md`，后续恢复和 close_check 可能把不存在 task 当作完成记录。
- 建议：用 `jq -er` 强制匹配，并校验 title 不为空且不等于 `null`；找不到 task 直接 `die`。
- 置信度：中高
- 优先级：MEDIUM

### 14. `op_checkpoint.sh` 替换 tasks_list 状态段时缺少 header 存在性校验

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_checkpoint.sh:38-55`
- 现象：脚本用 awk 遇到 `## tasks_list 状态` 时替换整段；若 checkpoint 模板缺失该标题，awk 会原样输出文件并成功退出，脚本仍打印 OK。
- 影响：checkpoint 状态段可能没有更新，但脚本报告成功。compact 恢复依赖 checkpoint，人读状态会过期。
- 建议：替换前先 `grep -q '^## tasks_list 状态$'`，缺失则 `die` 或追加标准段；替换后可检查 `<!-- AUTO -->` 是否存在。
- 置信度：中
- 优先级：MEDIUM

### 15. `close_check.sh` 只检查 checkpoint 含 TID，不检查 checkpoint 已提交或状态段新鲜

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/close_check.sh:21-27, 42-50`
- 现象：脚本只 grep `leader_checkpoint.md` 是否有 `- {TID} `，不检查该变更是否已 staged/committed，也不检查 tasks_list 状态段是否包含当前 done 状态。git status 中非 task 改动仅 WARN。
- 影响：配合当前 SKILL.md 的 commit-before-checkpoint 顺序，会稳定留下未提交 checkpoint；close_check 不会拦住。
- 建议：close_check 应检查 `git diff --quiet -- docs/omni_powers/op_execution/leader_checkpoint.md` 或明确允许 checkpoint 后置但要求二次 commit。状态段可加对 `- 完成：` 中 TID 的检查。
- 置信度：高
- 优先级：MEDIUM

### 16. `close_check.sh` 的 git status 过滤过窄，可能把合法归档移动误报为非本 task 改动

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/close_check.sh:42-47`
- 现象：过滤只排除 `docs/omni_powers/op_record/tasks/${TID}`。同一收口还会涉及 `op_record/specs/{TID}_*.md`、`op_record/acceptance/{TID}`、`op_execution/tasks_list.json`、`op_record/progress.md`、checkpoint 等路径。
- 影响：如果 close_check 在 commit 前执行，会大量 WARN 合法收口路径，降低信号质量；如果按当前 commit 后执行，则主要暴露 checkpoint 未提交问题。
- 建议：根据预期执行时机调整：若 commit 前检查，白名单应包含完整收口路径；若 commit 后检查，应改为任何 dirty 都 FAIL 或至少 checkpoint dirty FAIL。
- 置信度：中
- 优先级：LOW

### 17. `op_coder_check.sh` 按 verdict 行数判断轮次，但不验证最新 verdict 是否 FAIL

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_coder_check.sh:13-33`
- 现象：只要 `review.md` 中有任意 `verdict:` 行且轮次未超过 2，就输出 `mode: fail`，不关心最新 verdict 是 PASS 还是 FAIL。
- 影响：正常流程中 PASS 后不会再派 implementer，因此影响有限；但在 compact 恢复、状态错乱或人工重跑脚本时，可能把已 PASS 的 review 误判为需要 FAIL 修复轮。
- 建议：读取最新 verdict；仅最新为 FAIL 时进入 `mode: fail`，最新为 PASS 时返回单独状态（如 `mode: reviewed_pass`）或 die 提示不应再派 implementer。
- 置信度：中
- 优先级：LOW

### 18. `op_close_post.sh` 使用本地时区 `date +%F`，与全局 UTC+8 约定未显式一致

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_close_post.sh:14`
- 现象：脚本直接使用系统本地时区。用户全局约定「时间用 UTC+8，除非另有说明」。若运行环境时区不是 UTC+8，progress 日期会偏移。
- 影响：归档记录日期可能和报告日期不一致，审计体验受影响。
- 建议：使用 `TZ=Asia/Shanghai date +%F`，或项目统一封装日期函数。
- 置信度：中
- 优先级：LOW

## 改进建议

1. 将 verdict 读取逻辑收敛成单一脚本契约：`PASS=0`、`FAIL=1`、`NONE/INVALID=2`，所有调用方按 `result:` 和退出码双重判断，避免 `NONE` 被当作成功。
2. 为所有 `{TID}_*.md` glob 建立统一 helper：0 个、多个都阻断，避免 `ls | head -1` 静默选错。
3. 将 `SKILL.md` 中所有机读状态统一为 ASCII，中文只出现在渲染说明中。
4. 明确 Stage 4 的 stage/commit 边界：blueprint、decisions、issues、acceptance、checkpoint 是否由 `op_close_post.sh` 负责纳入 commit，需要单一真相源。
5. 为收口流程增加「中断恢复矩阵」：closer 未开始、closer 进行中、closer 已返回待自审、已归档未 commit、已 commit 未 checkpoint，各状态对应脚本入口。
6. `op_assemble_eval_brief.sh` 建议改为严格 brief schema：工作 spec、剥离后工作 spec、生效规格正文、baseline 索引、启动方式、通道能力，每段缺失都写机器可读标记，便于 evaluator 判 `INSUFFICIENT_EVIDENCE`。
7. `op_close_post.sh` 可拆成两个脚本：`op_archive_task.sh` 只处理归档，`op_stage_close_artifacts.sh` 只根据白名单 stage 收口产物，职责更清晰。

## 不确定项 / 可能误报

1. merge gate 当前可能仍处 P1 过渡状态，若团队有外部证据文件或人工步骤记录 merge gate PASS，本报告关于 `op_close_post.sh` 未校验 merge gate 的问题仍成立，但优先级可从 HIGH 降为 MEDIUM。
2. `op_close_post.sh` stage 边界可能是刻意收窄，要求 leader 在脚本外手动 stage blueprint/decisions/issues；但 `SKILL.md` 示例没有写该步骤，因此按当前文档执行仍会漏提交。
3. `op_close_pre.sh` 在 closer 后运行可能是想表达「closer 提案完成，leader 正在收口」而非「closer 正在执行」。若如此，`SKILL.md` 的 `status=closing` 恢复说明需要更细分，否则仍有恢复歧义。
4. `op_assemble_eval_brief.sh` 只输出 `spec_index.md` 可能是为了避免 evaluator 读取过多 blueprint；但设计文档明确要求生效规格开工前基线，索引不能替代规格正文。
