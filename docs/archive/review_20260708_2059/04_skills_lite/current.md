# 当前模型判断依据

- 可观测来源：settings 顶层 model=default_model；env.ANTHROPIC_MODEL=default_model；默认档位 haiku=default_haiku[1m] / sonnet=default_sonnet[1m] / opus=default_opus[1m]；主会话 powered by default_model。
- current 路继承主会话。
- 未写入任何 secret。

# 审阅范围

核心参考：`/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md`

本次只读审阅：

- `/home/karon/karson_ubuntu/omni_powers/skills/oplinit/SKILL.md`
- `/home/karon/karson_ubuntu/omni_powers/skills/oplinit/scripts/op_check_env.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oplinit/scripts/oplinit_skeleton.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oplintake/SKILL.md`
- `/home/karon/karson_ubuntu/omni_powers/skills/oplintake/scripts/op_check_env.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/SKILL.md`
- `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/close_check.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/op_assemble_eval_brief.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/op_check_env.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/op_check_p0.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/op_close_post.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/op_coder_check.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/op_jq.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/op_read_verdict.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/op_status.sh`

# 高优先级问题

## 1. lite 状态机使用中文状态，破坏 design 规定的 ASCII 机读状态

- 位置：
  - `/home/karon/karson_ubuntu/omni_powers/skills/oplintake/SKILL.md:7,75-89,99-101`
  - `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/op_close_post.sh:55`
  - `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/op_status.sh:33-37`
  - `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/op_jq.sh:14-18,31`
- 现象：
  - design §1.1 明确 `tasks_list.json.status` 机读值必须统一为 ASCII：`pending|ready|in_progress|reviewing|closing|done|suspended|blocked|obsolete`，lite 仅删 `closing`。
  - `oplintake/SKILL.md` 示例和终点写 `status: "待开始"`。
  - `op_close_post.sh` 调用 `op_status.sh "$TID" 完成`，但 `op_status.sh` 只接受 `done`，会直接失败。
  - `op_jq.sh pending` 选择 `.status=="ready"`，无法选中 intake 写出的中文 `待开始`。
- 影响：
  - `/oplintake` 产物无法被 `/oplrun` 选中，task 循环空跑或误判无可跑 task。
  - 已通过 review/eval 的 task 在 `op_close_post.sh` 标完成阶段必失败，无法归档闭环。
  - 状态机与 design §5.6 “pending → ready → in_progress → reviewing → done” 不一致。
- 建议：
  - `oplintake/SKILL.md` 全部改为 `ready`，中文只作为渲染层说明。
  - `op_close_post.sh:55` 改为 `bash "$SCRIPT_DIR/op_status.sh" "$TID" done`。
  - 增加脚本自检或测试覆盖：中文状态写入应失败；`ready → in_progress → reviewing → done` 应可完整流转。
- 置信度：高
- 优先级：P0

## 2. `op_check_p0.sh` 与 design §5.8/A18 语义相反，且未被 `/oplrun` 调用

- 位置：
  - `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/op_check_p0.sh:1-44`
  - `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/SKILL.md:173-175,202-204,231-234`
- 现象：
  - design §5.8 明确：P0 issue 不事中阻断归档，进入 oplrun 结束报告，用户报告后处置。
  - `op_check_p0.sh` 注释和行为却定义为“发现 open P0 → 归档前必须处置 → exit 1”，并要求用户三选一。
  - `oplrun/SKILL.md` 当前流程已写“P0 不事中阻断”，但相关文件列表仍包含 `op_check_p0.sh`；实际流程没有调用它，导致脚本成为陈旧且危险入口。
- 影响：
  - 若后续维护者按脚本注释接入，会重新引入已被 A18 删除的事中阻断，破坏 autonomy-first 设计。
  - 若不接入，则文件名和注释误导审阅者，以为 lite 已有 P0 机械检查；实际只有结束报告汇总要求，缺少对应汇总脚本。
- 建议：
  - 删除 `op_check_p0.sh`，或改名/改语义为 `op_collect_open_issues.sh`：只汇总 open P0/P1 并返回 0，供结束报告使用。
  - `oplrun/SKILL.md` 相关文件表删除阻断式 P0 脚本，补充结束报告汇总命令或脚本。
- 置信度：高
- 优先级：P0

## 3. lite 收口没有归档工作 spec 与 acceptance，违背 design §1.2/§5.6 的归档要求

- 位置：
  - `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/op_close_post.sh:42-73`
  - `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/SKILL.md:176-200`
  - `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md:149-151,853-866`
- 现象：
  - design §1.2 写明 task 级验收后：工作 spec 原文入 `op_record/specs/`，task 目录入 `op_record/tasks/{TID}/`，验收工作区入 `op_record/acceptance/{TID}/`；lite 无 closer/blueprint，但仍“leader 直接归档 spec 原文”。
  - `op_close_post.sh` 只 `git mv docs/omni_powers/op_execution/tasks/$TID` 到 `op_record/tasks/$TID`，未移动 `op_execution/specs/${TID}_*.md`，也未移动 `op_execution/acceptance/$TID`。
  - stage 范围只包含 task 归档、progress、tasks_list，未 stage spec/acceptance/e2e 相关归档。
- 影响：
  - 已完成 task 的 spec 留在活区 `op_execution/specs/`，活区语义污染，compact 恢复/后续 intake 容易误判。
  - evaluator 产出的 `eval.md`、`eval_brief.md`、临时 baselines 未归档，验收证据链断裂。
  - 与 design 的“三态模型：op_execution 流动工作区 / op_record 冻结历史”不一致。
- 建议：
  - `op_close_post.sh` 在 review/eval PASS 后：
    - `git mv op_execution/specs/${TID}_*.md op_record/specs/`
    - `git mv op_execution/acceptance/${TID} op_record/acceptance/${TID}`
    - 同步 stage 这些路径。
  - 若 acceptance 不存在（免派 evaluator 或非行为型 task），需明确允许条件并记录 `eval: skip/eval_reason`。
- 置信度：高
- 优先级：P0

## 4. lite 脚本副本/共享寻址文档互相冲突，当前实现仍是 per-skill 副本

- 位置：
  - `/home/karon/karson_ubuntu/omni_powers/skills/oplintake/SKILL.md:12-18`
  - `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/SKILL.md:14-24`
  - `/home/karon/karson_ubuntu/omni_powers/skills/oplinit/scripts/op_check_env.sh`
  - `/home/karon/karson_ubuntu/omni_powers/skills/oplintake/scripts/op_check_env.sh`
  - `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/op_check_env.sh`
  - `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md:801-824`
- 现象：
  - design §5.5 前半要求 install.sh 统一装 `~/.claude/scripts/omni_powers/`，lite skill 不再各自带 `scripts/` 副本；后半又记录 D5 渐进状态：lite 副本暂保留，完整归并待重构。
  - `oplintake/SKILL.md:17` 称脚本走 `${OP_SCRIPT_ROOT:-$OP_HOME}` fallback 到共享 scripts，但本 skill 实际调用的是 `$SKILL_DIR/scripts/op_check_env.sh`。
  - `oplrun/SKILL.md:16-21` 称 lite 无 `$OP_HOME`，但把 `OP_SCRIPT_ROOT` 设置为 `<oplrun skill 目录>`，不是 design §5.5 描述的共享目录 `~/.claude/scripts/omni_powers/`。
  - 三份 `op_check_env.sh` 完全重复，说明副本同步尚未淘汰。
- 影响：
  - 维护者无法判断当前契约是“共享目录单源”还是“skill 内脚本副本”；安装路径、agent resolver、skill 示例三者不一致。
  - 后续修复某个脚本可能只改一份，lite 三入口行为漂移。
  - agent prompt 注入的 `OP_SCRIPT_ROOT` 与 agent 内 resolver 预期不匹配时，脚本查找会延迟失败。
- 建议：
  - 明确当前阶段：若仍保留副本，则删去“已消灭 per-skill 副本”的表述，所有 SKILL.md 统一说 `$SCRIPTS=$SKILL_DIR/scripts`。
  - 若已切共享目录，则移除 per-skill scripts 副本，`OP_SCRIPT_ROOT` 统一指向 `~/.claude/scripts/omni_powers/`，skill 入口也使用共享目录。
  - 对 `op_check_env.sh` 做单源化，或加副本一致性测试。
- 置信度：高
- 优先级：P1

## 5. `/oplrun` 缺少 design §5.9 要求的 spec 写保护机械校验与 dispatch 锚点落盘

- 位置：
  - `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/SKILL.md:70-118,176-184`
  - `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md:895-910`
- 现象：
  - design §5.9 要求 lite 无 hook/merge gate 时，收口前对 `op_execution/specs/**` 跑 `git diff <dispatch锚点sha> -- specs/` 非零即停，防 implementer 主分支直改 spec 同源污染。
  - design §5.9 同时要求 dispatch implementer 时记录 HEAD sha，reviewer diff 锚定该 sha。
  - `oplrun/SKILL.md` 只写 `git diff --stat` 和“定向读核心 hunk”，没有要求记录 dispatch 锚点，也没有收口前 spec diff 机械校验。
- 影响：
  - lite 最关键的无 hook 替代缺失：implementer 可修改 approved spec 后让实现/测试/验收共同对着污染后的 spec 变绿。
  - reviewer diff 可能使用当前 HEAD，若 implementer 自行 commit 或 leader误 commit，diff 为空或不完整。
- 建议：
  - 在 3.2 dispatch 前写入/记录 `dispatch_sha=$(git rev-parse HEAD)` 到 task 元数据或 checkpoint。
  - 在 3.3/3.4 review package 明确使用 `git diff "$dispatch_sha" -- ...`，新增文件先 `git add -N`。
  - 在 3.6 收口前增加 `git diff --quiet "$dispatch_sha" -- docs/omni_powers/op_execution/specs`，非零则停并走 spec 变更子流程。
- 置信度：高
- 优先级：P1

# 中低优先级问题

## 6. `op_close_post.sh` 未校验 evaluator PASS，只有 review PASS

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/op_close_post.sh:32-40`
- 现象：脚本只检查 `report.md`、`review.md` 和 review verdict PASS，没有检查 `op_execution/acceptance/{TID}/eval.md` 或末行 `verdict: PASS`。
- 影响：leader 若误跳过 evaluator 或 evaluator FAIL 后误调用 close_post，脚本仍可能归档并标 done（当前还会因中文“完成”失败，但修复状态后此漏洞会暴露）。
- 建议：在 close_post 中校验 `acceptance/{TID}/eval.md` 最新 verdict PASS；非行为型免派 task 需用 `eval: skip` + `eval_reason` 显式豁免。
- 置信度：中
- 优先级：P1

## 7. `close_check.sh` 要求 checkpoint 先包含 task，但 `/oplrun` 示例在 commit 后才让 leader 手动更新 checkpoint

- 位置：
  - `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/SKILL.md:193-199`
  - `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/close_check.sh:21-27`
- 现象：`oplrun/SKILL.md` 顺序为 `git commit` → 手动编辑 checkpoint 追加完成行 → `close_check.sh`。若按顺序执行，checkpoint 改动发生在 commit 之后，不在本 task commit 中；若先 commit 再检查，检查可以通过但 checkpoint 未随 commit 入库。
- 影响：task 即 commit 的审计粒度不完整，恢复点可能依赖未提交工作区改动。
- 建议：checkpoint 更新应在 commit 前完成并 stage；`close_check.sh` 应在 commit 前跑，或拆成 commit 前/后两种检查。
- 置信度：中
- 优先级：P2

## 8. `op_jq.sh pending` 名称与语义反直觉，容易误用

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/op_jq.sh:14-18`
- 现象：`pending` 查询返回 `status=="ready"`；`pending_plan` 返回 `status=="pending"`。历史命名可理解，但与 design ASCII 状态同名后易混淆。
- 影响：后续维护者可能写错查询或误以为 pending task 可执行。
- 建议：保留兼容别名但新增 `ready` / `planning` 查询；SKILL.md 改用 `op_jq.sh ready`。
- 置信度：中
- 优先级：P3

## 9. `op_assemble_eval_brief.sh` 未剥离 spec 中设计探索/已知坑段，弱化防同源污染

- 位置：
  - `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/op_assemble_eval_brief.sh:31-34`
  - `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md:337-340,880-885`
- 现象：design 对 evaluator brief 的核心要求是提供验收条件/可测性契约，heavy 明确剥“设计探索结论/已知坑”；lite §5.7 也写 brief 简化但仍应围绕工作 spec + 验收标准 + 启动方式。当前脚本直接 `cat "$WORK_SPEC"`，如果 spec 内含候选方案、实现思路、已知坑，evaluator 会读到实现侧污染信息。
- 影响：lite 已无文件系统隔离，brief 再携带实现探索会进一步降低独立性。
- 建议：规定 spec 模板中 evaluator 可读段落边界，脚本只抽取 AC/INV/边界/可测性契约/启动方式；或在 brief 中明确剥离“技术决策探索过程/已知实现坑”。
- 置信度：中
- 优先级：P2

# 改进建议

1. 为 lite 状态流转加最小 bats/shell 测试：`oplinit → 写 ready task → op_status in_progress/reviewing/done → op_jq all`。
2. 为 `op_close_post.sh` 加 dry-run 或 fixture 测试，覆盖 task/report/review/eval/spec/acceptance 全归档。
3. 将 “P0 结束报告汇总” 做成只读脚本，替代阻断式 `op_check_p0.sh`。
4. 统一 `OP_SCRIPT_ROOT` 语义：要么 skill 目录，要么共享脚本目录，不要混用；文档、agent resolver、install.sh 三处同步。
5. `/oplrun` 示例命令中避免 `head`/`sed -i` 这类跨平台或上下文污染高的命令，改为专用脚本输出 verdict/摘要。

# 不确定项

1. design §5.5 同时出现“共享脚本目录已统一”与“lite 副本暂保留，完整归并待重构”两种状态描述；本审阅按当前文件实现判断为“副本暂保留”，但需维护者确认最新决策。
2. 非行为型 task 是否允许 lite 跳过 evaluator：design §2.5/D9 有 `eval: skip`，但 `/oplrun` lite 流程当前未体现；若项目决定 lite 一律派 evaluator，则 `op_close_post.sh` 必须强校验 eval PASS。
3. `op_check_p0.sh` 可能是旧版本遗留未使用脚本；若确认为废弃，应删除以免误接入。
