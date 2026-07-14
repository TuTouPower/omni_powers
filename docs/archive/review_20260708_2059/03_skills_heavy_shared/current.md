# 当前模型判断依据

可观测来源：settings 顶层 model=default_model；env.ANTHROPIC_MODEL=default_model；默认档位 haiku=default_haiku[1m] / sonnet=default_sonnet[1m] / opus=default_opus[1m]；主会话 powered by default_model。current 路继承主会话。未写入任何 secret。

# 审阅范围

核心参考：`/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md`。

本次逐文件全量审阅：

- `/home/karon/karson_ubuntu/omni_powers/skills/opinit/SKILL.md`
- `/home/karon/karson_ubuntu/omni_powers/skills/opinit/scripts/opinit_register_hooks.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/opinit/scripts/opinit_skeleton.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/opintake/SKILL.md`
- `/home/karon/karson_ubuntu/omni_powers/skills/oprun/SKILL.md`
- `/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/close_check.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_assemble_eval_brief.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_checkpoint.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_close_post.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_close_pre.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_coder_check.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oprun/scripts/op_read_verdict.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/opspec/SKILL.md`
- `/home/karon/karson_ubuntu/omni_powers/skills/opstatus/SKILL.md`
- `/home/karon/karson_ubuntu/omni_powers/skills/opred/SKILL.md`
- `/home/karon/karson_ubuntu/omni_powers/skills/optriage/SKILL.md`

审阅重点：heavy 流程、opspec、oprun、opstatus、opred/optriage、状态机、权限边界、交付状态一致性。

# 高优先级问题

## H1. 状态机仍大量使用中文状态值，与 design 的 ASCII 机读状态冲突

- 位置：
  - `skills/opintake/SKILL.md:6,63-73,83-85`
  - `skills/oprun/SKILL.md:115,142-145,162-187,247-249,262-269`
  - `skills/oprun/scripts/op_close_pre.sh:2-14`
  - `skills/oprun/scripts/op_close_post.sh:54`
  - `skills/oprun/scripts/op_checkpoint.sh:31-36,42-47`
  - `skills/opstatus/SKILL.md:28-57`
  - `skills/optriage/SKILL.md:69-82`
- 现象：design §1.1 明确 `tasks_list.json.status` 机读值为 `pending|ready|in_progress|reviewing|closing|done|suspended|blocked|obsolete`，脚本/agent 不得自创状态串；但本分块仍写 `待开始/进行中/审阅中/收口中/完成/阻塞/跳过/挂起/待规划`。部分脚本直接用中文值查询或写入，例如 `op_close_post.sh` 调 `op_status.sh "$TID" 完成`，`op_checkpoint.sh` 用 jq 过滤 `.status == "完成"`。
- 影响：heavy 主循环选 task、checkpoint 渲染、close post 标完成、opstatus 读状态、triage 转 task 都可能与新 schema 互不识别。`oprun` 可能认为没有可跑 task，或归档后仍无法显示 done；跨平台 locale 稳定性目标也失效。
- 建议：统一替换为 ASCII 状态：`待规划→pending`、`待开始→ready`、`进行中→in_progress`、`审阅中→reviewing`、`收口中→closing`、`完成→done`、`阻塞→blocked`、`挂起→suspended`、`废弃→obsolete`。删除 `跳过/skipped` 终态语义；下游阻塞由调度器依 `depends_on` 不选中。opstatus 仅在渲染层映射中文。
- 置信度：高
- 优先级：高

## H2. oprun 流程和图示仍残留旧顺序与旧 worktree 模型，和 design 的 per-task 分支 + merge 前验收冲突

- 位置：`skills/oprun/SKILL.md:27-40,90-110,189-231,277-288`
- 现象：
  - 步骤 1.1 仍让用户选择 `worktree/主分支/当前分支`，并创建单 session 复用 `.claude/worktrees/op-dev feat/op-dev`。
  - 循环图写成 `双裁决 PASS ──▶ merge gate + squash-merge ──▶ per-task 验收`，与后文 `3.5 per-task 验收（merge 前验）` 自相矛盾。
  - 收尾段仍保留 P0 session worktree `git merge feat/op-dev --ff-only`。
- 影响：design §2.4/§3.4 要求每 task 从主分支头切 `op/task/{TID}`，双裁决 PASS 后先在 task 分支验收，验收 PASS 才 merge gate + squash-merge。旧单 worktree / 先 merge 后验收会让未验收代码进主分支，并削弱 merge gate 生效点。
- 建议：重写 `oprun` 步骤一和循环图：删除用户分支模式选择与 `feat/op-dev` session 模式；明确每 task dispatch 时创建/复用 `op/task/{TID}` dev worktree，记录 dispatch 锚点 sha；流程为 implementer → reviewer → evaluator（若 required）→ merge gate → squash-merge → closer → leader 自审归档。
- 置信度：高
- 优先级：高

## H3. reviewer 被要求直接写 `review.md`，违反 design 的 review.md 单写者边界

- 位置：
  - `skills/oprun/SKILL.md:160-172`
  - `skills/oprun/scripts/op_read_verdict.sh:10-22`
  - `skills/oprun/scripts/op_coder_check.sh:9-22`
  - `skills/oprun/scripts/op_close_post.sh:31-39`
- 现象：`oprun` dispatch prompt 要求 reviewer 输出 `tasks/{TID}/review.md`，脚本默认从 `op_execution/tasks/{TID}/review.md` 读取 verdict。design §2.4/§3.4 明确 reviewer 只在返回文本末行给 verdict，leader 落盘到主分支 `review.md`；task 分支对 review.md 任何变更被 merge gate 白名单 REJECT。
- 影响：review verdict 落入被监督者/分支可写域，破坏“监督者之外的证据”原则；merge gate 从主分支 review.md 末行读 PASS 的前提不成立。后续 `op_coder_check`、`op_read_verdict`、`op_close_post` 可能读取 task 分支或归档目录中的非权威 verdict。
- 建议：调整 `oprun` prompt：reviewer 只返回文本，末行 `verdict: PASS|FAIL`，范围外发现写暂存段；leader 捕获返回并 append 到主分支 `docs/omni_powers/op_execution/tasks/{TID}/review.md`。脚本注明只读主 worktree review.md；merge gate 前不得接受 task 分支 review.md。
- 置信度：高
- 优先级：高

## H4. op_close_post 未执行 design 要求的完整归档，且缺关键前置校验

- 位置：`skills/oprun/scripts/op_close_post.sh:1-75`，`skills/oprun/SKILL.md:259-270`
- 现象：脚本只校验 report/review、归档 task 目录、追加 progress、标中文“完成”、stage task/progress/tasks_list。未归档 `op_execution/specs/{TID}_*.md` 到 `op_record/specs/`，未归档 `op_execution/acceptance/{TID}/` 到 `op_record/acceptance/{TID}/`，未 stage blueprint/baselines 合入结果；也未校验 merge gate PASS、closer append decisions 块、`blueprint_update.md` 存在/已采纳。
- 影响：Stage 4 后工作 spec 和 acceptance 工作区会残留在活区，task “done” 不符合 design §1.2/§2.6；progress 与 blueprint/baseline 状态可能不同步；缺少 merge gate/closer append 证据会让未完整闭环的 task 被标完成。
- 建议：`op_close_post.sh` 改为：前置校验主分支 review verdict PASS、merge gate PASS 证据、`acceptance/{TID}/blueprint_update.md` 存在且 leader 已处理、decisions.md 存在对应 `[red-attribution|blocked-attribution/closer...]` 块（按实际协议）；归档 spec/task/acceptance 三类目录；状态写 `done`；stage progress、tasks_list、checkpoint、op_record/specs、op_record/tasks、op_record/acceptance，以及 leader 已实际修改的 op_blueprint/baselines。
- 置信度：高
- 优先级：高

## H5. opinit_skeleton 固定创建顶层 `e2e/`，未落实 design 的 e2e 路径配置与既有 e2e 探测

- 位置：`skills/opinit/scripts/opinit_skeleton.sh:25-32`，`skills/opinit/SKILL.md:48-55,101-109`
- 现象：初始化直接 `mkdir -p ... e2e`，未创建 `docs/omni_powers/config`，未写 `OP_E2E_DIR=...`，也未探测用户项目已有顶层 `e2e/` 并提示迁移/豁免/换路径。
- 影响：design §1 规定 e2e 路径由项目级 config 决定，用户项目已有顶层 e2e 时 init 要探测提示，避免既有测试被误锁。当前行为会静默创建或混用顶层 e2e，使 merge gate/evaluator 所谓行为层资产边界不清。
- 建议：opinit 步骤零加入 e2e 路径决策；脚本写 `docs/omni_powers/config`（如 `OP_E2E_DIR=e2e`）并在已有 `e2e/` 时 die 或提示选择。当前 config parser 设计标注规划中时，文档需诚实说明脚本仍硬编码；不要无提示创建顶层 e2e。
- 置信度：高
- 优先级：高

## H6. opspec 模板 frontmatter 与可测性契约落后于 design

- 位置：`skills/opspec/SKILL.md:41-93`
- 现象：模板写 `status: draft → approved → in_progress → done / cancelled`，但 design §2.2 明确 spec frontmatter 只 `draft|approved`，approved 后冻结，状态推进走 tasks_list；design §1.1 不引入 `cancelled`。模板未包含 `feature` 功能名锚点；“预期失败模式”写成每条 AC 至少 1 条反例，但 design §2.2/D13 已改为 best effort，建议每条 AC 1 条，非硬门槛。验收信号仍把 DOM/a11y 放在“结构化优先”中，design §2.2/§2.5 已明确 DOM/a11y 降 advisory。
- 影响：闸门 A 产物会携带错误生命周期字段和过强反例硬门，执行期可能试图改 approved spec 状态；feature_key/baselines 合入锚点缺失；evaluator hard-pass 与 baseline 硬门信号选择会偏离 design。
- 建议：模板改为 design §2.2 原文：frontmatter `status: draft`、`type`、必要时加 `feature: {功能名锚点}` 与 `eval: required|skip`/`eval_reason`（若 schema 已决定）；删除 `in_progress/done/cancelled`；预期失败模式改 best effort；验收信号写“结构化优先（CLI/API/DB/进程健康；DOM/a11y advisory）”。
- 置信度：高
- 优先级：高

## H7. opintake 的 tasks_list schema 示例与终点仍是旧模型

- 位置：`skills/opintake/SKILL.md:57-85`
- 现象：示例 task 写 `status: "待开始"`、`spec: "T0001"`、`type: "实现"`。design §2.3 task 元数据要求 `status: "ready"`，`spec: "specs/T0003_xxx.md"`，无 `type` 字段；可选/规划中的 eval 字段也未体现。终点写 `status=待开始`。
- 影响：oprun/merge gate/eval brief 依赖 spec 路径和 ASCII 状态会失败或需要猜测；spec 字段一会儿 TID、一会儿路径，脚本只能靠 glob 兜底，无法成为稳定机读契约。
- 建议：opintake 示例与实际写入改为 design schema：`id/title/status/spec/depends_on/workset`，`status=ready`，`spec="specs/{TID}_{slug}.md"`。删除 `type` 或明确 change type 归 spec frontmatter；若采用 D9 eval 字段，补 `eval/eval_reason`。
- 置信度：高
- 优先级：高

## H8. op_assemble_eval_brief 未剥离“设计探索结论/已知坑”，且未真正提供生效规格基线

- 位置：`skills/oprun/scripts/op_assemble_eval_brief.sh:26-75`
- 现象：脚本直接 `cat "$WORK_SPEC"`，会把 `### 设计探索结论`、候选、推荐、已知坑完整给 evaluator。生效规格部分只 cat `spec_index.md`，没有按 feature/spec 取 `op_blueprint/specs/{feature}.md` 或相关生效规格全文。
- 影响：违反 design §2.5/A16 “eval_brief 剥探索结论，保留条件强制 + 可测性契约”，evaluator 可能受实现路径/已知坑污染；缺少生效规格全文会削弱基线对照，无法验证与既有功能契约的兼容。
- 建议：脚本解析工作 spec，过滤 `### 设计探索结论` 到下一同级标题之间内容；保留条件强制、可测性契约、AC/INV/边界。根据 tasks_list/spec frontmatter feature 锚点与 `spec_index.md` 定位相关 `op_blueprint/specs/*.md`，至少纳入 feature 对应生效规格；若无法定位，明确输出 `INSUFFICIENT_BASELINE` 提示。
- 置信度：高
- 优先级：高

## H9. optriage 仍把 P0 描述为闸门 C/本 spec 阻断，违背 A18 事后报告策略

- 位置：`skills/optriage/SKILL.md:54-61,109-112`
- 现象：P0 规则写“必须转 task，本 spec 收尾前必修，默认阻断闸门 C”，step 5 写“P0 默认阻断”。design §2.6/§3.2/A18 明确 P0/P1 issue 记录不阻断执行，P0 进结束报告，由用户事后处置；P0 只能由人或 optriage 复核确认，但不事中阻断归档。
- 影响：oprun 收尾可能在每 task 中途停下要求处理 P0，破坏“无用户事中审批”和 A18 批量事后报告；也与 `oprun` 自身 `P0/P1 issue 不阻断` 文案冲突。
- 建议：optriage 改为：P0/P1 复核并标注，P0 写入结束报告 `blocks_merge` 语义和处置选项，不在 per-task 收尾阻断；若用户显式中断/要求立即修，才转 task。
- 置信度：高
- 优先级：高

# 中低优先级问题

## M1. opinit 仍大量派 Agent 生成 blueprint/CLAUDE/index，和本次审阅“全线 Sub Agent”机制本身不冲突，但与 opinit 设计的 leader/agent职责边界不够精确

- 位置：`skills/opinit/SKILL.md:70-99`
- 现象：opinit 派普通 Agent 直接生成 blueprint、重构 CLAUDE.md、生成 index/README；但描述未限定写权限、未要求生成后 leader 自审，且第 72 行引用 design §3.3 文档职责矩阵，当前矩阵在 design §1.3。
- 影响：opinit 是初始化流程，风险低于运行期，但 Agent 可能越界改旧文档或生成不符合职责矩阵的内容；章节引用过期会误导维护者。
- 建议：补“leader 审 diff 后保留/回滚”；更新引用到 design §1.3；明确 blueprint-generator 不改 `op_execution` 状态与不生成 task。
- 置信度：中
- 优先级：中

## M2. approved spec 漂移复查扫错目录与状态

- 位置：`skills/oprun/SKILL.md:68-84`
- 现象：脚本扫 `op_blueprint/specs/*.md` 的 `status=approved/in_progress`。design 的 approved 工作 spec 在 `op_execution/specs/{TID}_*.md`，生效规格 `op_blueprint/specs/` 不一定有 frontmatter status；spec frontmatter 也不应有 `in_progress`。
- 影响：真正受写保护的工作 spec 漂移可能漏查；对生效规格误报。
- 建议：漂移复查改扫 `docs/omni_powers/op_execution/specs/*.md` 中 `status: approved` 的文件；生效规格改动走 closer/leader 自审，不用此检查。
- 置信度：高
- 优先级：中

## M3. close_check 只检查 task 二件与 checkpoint，未覆盖 acceptance/spec 归档和 done 状态

- 位置：`skills/oprun/scripts/close_check.sh:1-53`
- 现象：收口检查只看 checkpoint 是否含 TID、`op_record/tasks/{TID}/report.md|review.md` 是否存在，git status 提醒不拦。
- 影响：即使 spec 未归档、acceptance 未归档、tasks_list 未 done、blueprint_update 缺失，也会 PASS。
- 建议：补查 `op_record/specs/{TID}_*.md`、`op_record/acceptance/{TID}/`（若有）、tasks_list 对应 `.status == "done"`、progress 行、`blueprint_update.md` 已归档或被明确标记不适用。
- 置信度：高
- 优先级：中

## M4. op_checkpoint 使用中文状态并记录 emoji，不利于机读与极简日志

- 位置：`skills/oprun/scripts/op_checkpoint.sh:21-47`
- 现象：checkpoint 追加 `✅`，状态汇总中文过滤。
- 影响：与 ASCII 状态机冲突；emoji 对跨终端/grep 不友好。checkpoint 是人扫文件，可渲染中文，但来源判断应基于 ASCII。
- 建议：jq 按 ASCII 取值，输出可保留中文标签但去 emoji，或只在 opstatus 渲染图标。
- 置信度：中
- 优先级：中

## M5. opred 的 spec 变更子流程仍写“人批/重拆”，与 design 执行期 leader 自主 delta 不一致

- 位置：`skills/opred/SKILL.md:28-36,50-58`
- 现象：归因 (c) 写“agent 提 delta → 人批 → 重新 commit → 受影响 task 失效重拆”。design §2.4 规定执行期 spec-delta 由 leader 自主记录、改 spec、更新当前/后续 tasks_list，同 TID 从当前 task 重跑，不引入取消/重拆，不等待用户事中审批。
- 影响：implementer/reviewer 参考 opred 时可能错误要求人工审批或重拆 TID，打断流水线。
- 建议：改为“发现者提 delta → leader 记录 spec-delta + 受影响清单 → leader 改 spec + 更新 tasks_list → 同 TID 重跑；事后报告呈现”。
- 置信度：高
- 优先级：中

## M6. opstatus 示例 TID 宽度不一致，状态值与 profile 分叉仍旧

- 位置：`skills/opstatus/SKILL.md:36-57`
- 现象：示例含 `T04/T05`，不是 `T0004/T0005`；异常提示使用中文状态；profile 感知只说共享 scripts，但命令仍写 `$OP_HOME/scripts/op_jq.sh`。
- 影响：轻微误导，但会影响用户识别 TID 与脚本迁移。
- 建议：示例统一 `T0001` 风格；命令块显示 `SCRIPTS=${OP_SCRIPT_ROOT:-$OP_HOME}/scripts` 或说明 heavy/lite 分支实际命令；状态读取 ASCII 后渲染中文。
- 置信度：高
- 优先级：中

## M7. opinit_register_hooks 可能重复 concat hooks，幂等性不足

- 位置：`skills/opinit/scripts/opinit_register_hooks.sh:54-65`
- 现象：每次运行将 template hooks concat 到已有 hooks，没有去重。opinit_skeleton 幂等，但 hook 注册重跑会重复同一 hook。
- 影响：重跑 `/opinit` 后 hook 重复执行，可能造成重复警告、重复测试或性能下降。
- 建议：jq 合并时按 `matcher+command` 去重；或检测已有 omni_powers hook 后替换对应块。
- 置信度：中
- 优先级：中

## M8. op_assemble_eval_brief 的 cua 探测执行 `cua do status`，可能引入副作用/阻塞

- 位置：`skills/oprun/scripts/op_assemble_eval_brief.sh:66-70`
- 现象：brief 组装阶段除了 `command -v cua` 和 `cua --version`，还执行 `cua do status`。
- 影响：设计强调 brief 机械组装固定路径 cat + 环境事实探测；调用 CUA 运行态命令可能依赖 GUI 权限、阻塞或改变焦点。风险较低，但会让 brief 组装不再是纯文件组装。
- 建议：只记录 `command -v` 和版本；把 `cua do status` 留给 evaluator 执行后端初始化。
- 置信度：中
- 优先级：中

# 改进建议

1. 先做一次“状态机机械迁移”：所有 skill 文档、脚本、模板统一 ASCII 状态；opstatus 作为唯一中文渲染层。
2. 以 design §2.4/§3.4 为准重写 `skills/oprun/SKILL.md`：per-task 分支、dispatch 锚点、review-package、leader 落盘 review、merge 前 evaluator、merge gate、closer、归档顺序一次性闭合。
3. 为 `tasks_list.json` 建一个最小 schema 文档或 jq validator，覆盖 `id/title/status/spec/depends_on/workset/eval/eval_reason/feature` 当前约定，避免 opintake/opspec/oprun/optriage 各写一套。
4. 将 eval brief 组装做成可测试脚本：输入一个含“设计探索结论”的 spec，断言输出不含候选/推荐/已知坑，且包含可测性契约与对应生效规格。
5. op_close_post/close_check 加 fixtures 测试，覆盖幂等重跑、缺 spec 归档、缺 acceptance、未 done、无 closer append、review 非 PASS 等失败分支。
6. opinit 增加 e2e config 初始化检查：已有顶层 e2e 时停止并输出三选一，避免静默污染用户测试目录。

# 不确定项

1. `op_merge_gate.sh`、`op_status.sh`、`op_jq.sh`、`op_worktree_setup.sh` 不在本分块审阅范围；本报告仅基于当前分块中对这些脚本的调用方式判断一致性，未验证这些脚本是否已部分兼容 ASCII 状态或白名单 gate。
2. design §1 中 `OP_E2E_DIR` 标注 config parser 规划中、当前部分规则仍硬编码；因此 H5 的“应写 config”属于 design 目标一致性问题，若当前阶段刻意接受硬编码，需要在 opinit 文档中显式写明交付状态与风险。
3. D23 说明 `feature` 是功能名锚点而非生效规格硬映射；但 design §2.6 baselines 仍需要 feature_key 落点。当前 opspec/tasks_list 是否最终采用 `feature` 字段或只由 closer 判断，需统一 schema 后再落脚本。
4. RULES.md 本身仍有中文状态/跳过态/旧 lite 顺序残留，但本次用户未列入审阅目标；报告只在影响本分块引用处指出。
