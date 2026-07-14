# 当前模型判断依据

- 可观测来源：settings 顶层 model=default_model；env.ANTHROPIC_MODEL=default_model；默认档位 haiku=default_haiku[1m] / sonnet=default_sonnet[1m] / opus=default_opus[1m]；主会话 powered by default_model。
- current 路继承主会话。
- 未写入任何 secret。

# 审阅范围

核心参考：`/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md`

本次只读审阅：

- `/home/karon/karson_ubuntu/omni_powers/tests/README.md`
- `/home/karon/karson_ubuntu/omni_powers/tests/scripts/close_check.bats`
- `/home/karon/karson_ubuntu/omni_powers/tests/scripts/helpers.bash`
- `/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_check_env.bats`
- `/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_check_p0.bats`
- `/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_checkpoint.bats`
- `/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_ci_local.bats`
- `/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_close_post.bats`
- `/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_mutation_check.bats`
- `/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_read_verdict.bats`
- `/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_status.bats`
- `/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_trailer_unlock.bats`
- `/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_worktree_setup.bats`
- `/home/karon/karson_ubuntu/omni_powers/tests/scripts/opinit_register_hooks.bats`
- `/home/karon/karson_ubuntu/omni_powers/tests/scripts/opinit_skeleton.bats`
- `/home/karon/karson_ubuntu/omni_powers/tests/scripts/pre_tool_use.bats`
- `/home/karon/karson_ubuntu/omni_powers/tests/scripts/run-hook.bats`

# 高优先级问题

## 1. 测试 fixtures 仍使用旧中文状态和旧 schema，无法锁住 design §1.1 ASCII 状态机

- 位置：
  - `/home/karon/karson_ubuntu/omni_powers/tests/scripts/helpers.bash:21-24`
  - `/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_status.bats:5-45`
  - `/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_checkpoint.bats:23-31`
  - `/home/karon/karson_ubuntu/omni_powers/tests/README.md:30-40`
- 现象：
  - design §1.1 明确 `tasks_list.json.status` 机读值必须为 ASCII：`pending|ready|in_progress|reviewing|closing|done|suspended|blocked|obsolete`，中文只在渲染层使用。
  - `helpers.bash` 默认 task 写 `status:"收口中"`，且仍保留旧字段 `type:"实现"`、`covers_ac`、`touches_inv`、`risk_probe`；design §2.3 当前 schema 已只保留 `id/title/status/spec/depends_on/workset`，并另有 `eval/eval_reason` 规划。
  - `op_status.bats` 直接用 `阻塞`、`完成`、`无效状态` 调脚本，并断言 jq 中 status 为中文。
  - `op_checkpoint.bats:25` 追加 `status:"完成"`，继续强化旧状态。
- 影响：
  - 这些测试即使全绿，也是在保护旧状态机；无法发现脚本仍写中文、lite/heavy 状态流转无法互通等 P0 问题。
  - helpers 作为共享 fixture，会把旧 schema 传播到 `close_check`、`op_close_post`、`op_read_verdict` 等测试，导致测试样本与真实 `opintake/oplrun` 产物偏离。
  - README 覆盖矩阵没有提示 ASCII 状态是必须锁住的核心契约，测试目标与 design 单一真相源脱节。
- 建议：
  - 将 `helpers.bash` 默认 task 改为 design 当前 schema：`T0001`/`status:"closing"` 或按测试场景显式设置 `ready/in_progress/reviewing/done/blocked`。
  - `op_status.bats` 改为测试 ASCII 输入和输出；中文只测试 `opstatus` 渲染层，不测试机读层。
  - 增加负例：写入 `收口中/完成/阻塞` 应失败或被迁移脚本拒绝。
  - README 测试范围补上 “ASCII 状态枚举与旧中文状态拒绝”。
- 置信度：高
- 优先级：P0

## 2. lite P0 测试固化了已废弃的“事中阻断”语义，和 design §5.8/A18 相反

- 位置：
  - `/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_check_p0.bats:1-46`
  - `/home/karon/karson_ubuntu/omni_powers/tests/README.md:28-42`（未列该测试覆盖）
  - `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md:891-894`
- 现象：
  - design §5.8 明确：heavy/lite 都是 P0 issue 不事中阻断归档，进 oprun/oplrun 结束报告标注，用户报告后处置。
  - `op_check_p0.bats:30-38` 断言 open P0 时 `exit 1`，注释称“lite P0 阻断检查（代闸门 C 的 P0 阻断语义）”。
  - README 的测试范围表没有列 `op_check_p0.bats`，导致这个与 A18 冲突的保护目标不透明。
- 影响：
  - 后续若脚本按测试修复，会重新引入已被 design 明确移除的事中阻断。
  - 测试绿会误导维护者，以为 P0 机制符合 lite 状态机，实际与 autonomy-first/事后报告设计冲突。
- 建议：
  - 将该测试改为结束报告汇总语义：open P0 返回 0，但输出 P0 清单；或删除 `op_check_p0` 阻断脚本与测试。
  - README 覆盖矩阵明确 “P0 只汇总不阻断”。
  - 增加测试：open P0 + task 收口仍允许归档，结束报告必须包含 issue id/title/source。
- 置信度：高
- 优先级：P0

## 3. tests 覆盖矩阵缺少 merge gate 白名单核心能力，无法保护 design §0.2/§3.4 的写入硬底线

- 位置：
  - `/home/karon/karson_ubuntu/omni_powers/tests/README.md:28-42`
  - `/home/karon/karson_ubuntu/omni_powers/tests/scripts/` 全目录未包含 `op_merge_gate.bats`
  - `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md:43-49,612-638`
- 现象：
  - design §0.2 将 merge gate 定义为 P1 写入硬底线：task 分支允许触碰 = workset ∪ report.md ∪ 结构层测试路径，其余 REJECT；review verdict 从主分支 review.md 末行读取。
  - 当前 tests 只测 hook、worktree、trailer、close/status/checkpoint，未测 `op_merge_gate.sh` 白名单。
  - 缺少以下关键用例：task 分支改 `e2e/**`、`op_blueprint/**`、`op_record/**`、`tasks_list.json`、`review.md` 必须 REJECT；workset 内文件、report.md、结构层测试应 PASS；review.md 末行非 PASS 应 REJECT；主分支 review.md 与 task 分支 review.md 冲突时必须读主分支。
- 影响：
  - 项目最核心安全断言无 bats 回归。hook/subagent 失效、sparse-checkout advisory 的前提下，merge gate 是唯一硬防线；缺测试会让未来改动静默削弱安全模型。
  - 已有 `pre_tool_use.bats` 容易制造“hook 已保护”的错觉，但 design 明确 hook 仅 leader 主会话 advisory。
- 建议：
  - 新增 `tests/scripts/op_merge_gate.bats`，建立主分支 + task 分支 fixture，逐项覆盖白名单/黑名单/主分支 verdict。
  - README 测试范围将 merge gate 标为最高优先级覆盖项。
  - 将 `helpers.bash` 扩展为可创建 workset、主分支 review、task 分支 diff 的 fixture，避免每个测试重复搭建。
- 置信度：高
- 优先级：P0

## 4. lite 状态机与 profile 分支测试缺口大，无法验证 design §5.5/§5.6 的 heavy/lite 分叉

- 位置：
  - `/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_check_env.bats:1-22`
  - `/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_close_post.bats:1-40`
  - `/home/karon/karson_ubuntu/omni_powers/tests/scripts/close_check.bats:1-20`
  - `/home/karon/karson_ubuntu/omni_powers/tests/scripts/opinit_skeleton.bats:47-59`
  - `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md:801-824,828-867`
- 现象：
  - design §5.5 要求共用脚本按 `OP_PROFILE=heavy|lite` 显式分支，未知值 die；lite 无 `closing` 状态，不调 `op_close_pre`，`op_close_post` 跳过 `status=closing` 前置。
  - 当前 tests 基本只走 heavy 路径或旧中文状态路径，没有系统性设置 `OP_PROFILE=lite` 与 `OP_PROFILE=heavy` 对照。
  - `op_check_env.bats` 只测 `$OP_HOME` 必填；未测 lite 应跳过 OP_HOME、仅校验 jq/git，也未测 `OP_SCRIPT_ROOT` fallback。
  - `opinit_skeleton.bats` 只测 heavy profile 与 lite 冲突；没有对应 `oplinit_skeleton.bats`，无法验证 lite 首跑写 `profile=lite`、不改 CLAUDE.md、op_blueprint 空壳 README、docs/omni_powers/.gitignore。
- 影响：
  - heavy/lite 共享脚本最易漂移的 profile 分支没有回归网。
  - lite “零侵入”和“无 closing 状态”是 design 的核心差异，但当前测试不能防止误把 heavy 行为带回 lite。
- 建议：
  - 为每个 profile-aware 脚本增加 heavy/lite/unknown profile 三类测试。
  - 新增 `oplinit_skeleton.bats` 覆盖 lite 零侵入边界：不写项目 `.claude/settings.json`、不改已有 `CLAUDE.md/README/docs/*`、写 `profile=lite`、op_blueprint README 明确非契约源。
  - `op_check_env.bats` 拆成 heavy 与 lite 两组：heavy 要 OP_HOME，lite 要 OP_SCRIPT_ROOT 或共享脚本根。
  - `op_close_post.bats` 加 lite 用例：ready/reviewing → done 可归档；closing 在 lite 下应不可作为必需前置。
- 置信度：高
- 优先级：P1

## 5. hook 测试断言与 design “subagent deny 失效，仅主会话 advisory” 表述不一致

- 位置：
  - `/home/karon/karson_ubuntu/omni_powers/tests/scripts/pre_tool_use.bats:24-47`
  - `/home/karon/karson_ubuntu/omni_powers/tests/scripts/run-hook.bats:8-24`
  - `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md:590-610,680-686`
- 现象：
  - design 多处强调 PreToolUse 对 subagent deny 整体失效，hook 仅主会话 leader 场景 advisory；subagent 写入强制靠 merge gate/worktree 结构。
  - `pre_tool_use.bats:40-47` 仍用 `agent_type:"op-closer"` 断言 baselines subagent 写会被 exit 2 拦截。
  - 该测试在直接调用 shell hook 时当然能绿，但它验证的是脚本本身返回 2，不是 Claude Code subagent 场景真实能 deny。
- 影响：
  - 测试名称和断言会误导维护者，把 hook 当成 subagent 硬防线。
  - 与 design 信任模型冲突：真正需要测试的是 closer gate 或 merge gate，而不是 subagent PreToolUse 能否拦截。
- 建议：
  - 将测试名改为 “pre_tool_use: agent_type 输入时脚本给出 advisory/REJECT 结果（不代表 subagent 真实拦截）”。
  - 增加/强化 `op_closer_gate.bats`：closer 触碰 `op_blueprint/**`、`src/**`、`e2e/**` 时 leader 侧 gate 必须撤销/失败。
  - README hook 覆盖说明加注：hook 测试只验证主会话脚本逻辑，不证明 subagent deny 生效。
- 置信度：高
- 优先级：P1

## 6. trailer 测试只覆盖 e2e 存在性和 staged 清单变化，未覆盖 design §2.5 的合法入口边界

- 位置：
  - `/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_trailer_unlock.bats:28-73`
  - `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md:471-480`
- 现象：
  - design §2.5 规定 e2e/BUG-* 合法写入三条路径统一到 leader 主会话唯一入口：evaluator 固化 PASS、leader 落盘 BUG-* patch、closer 提案后改跨功能既有 e2e；主分支提交需 trailer + 解锁脚本配对。
  - 当前测试只覆盖“有 staged e2e → 输出 trailer + commit 成功”、“无 trailer 被拦”、“staged 变化旧 trailer 失效”。
  - 未区分 BUG-* 回归测试、普通 e2e、非 e2e 文件混合提交、仅 docs/omni_powers/e2e（lite 默认路径）等场景。
  - 未覆盖 trailer 只能由解锁脚本生成这一语义的边界：例如手写格式相同 trailer 是否会因缺少绑定信息失败。
- 影响：
  - 可能出现 e2e+src 混合提交被 trailer 一并放行，绕开 “e2e 入口只处理行为层资产” 的预期。
  - lite 默认 `docs/omni_powers/e2e/` 是否应纳入 trailer 保护没有测试表达，路径策略容易漂移。
- 建议：
  - 增加混合 staged 用例：e2e + src/spec/op_blueprint 同 commit 时应按设计明确放行或拒绝；若放行，需文档说明风险。
  - 增加 BUG-* 路径用例：`e2e/regression/BUG-{id}_*.spec` 需 trailer；非 e2e 的 BUG-* 应被拒或不视为行为层。
  - 增加 lite 路径策略用例：`docs/omni_powers/e2e/` 是否需要 trailer，应与 config/OP_E2E_DIR 决策一致。
  - 增加伪造 trailer 负例，确认校验依赖解锁脚本生成的绑定状态，而非仅字符串存在。
- 置信度：中
- 优先级：P1

# 中低优先级问题

## 7. worktree 隔离测试只验证顶层目录缺失，未覆盖 design §3.4 的流程文件挂载例外

- 位置：
  - `/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_worktree_setup.bats:17-43`
  - `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md:616-627`
- 现象：
  - design §3.4 明确：implementer 不挂 `tasks_list.json`，只读挂 `op_execution/specs/{TID}`，可写 task 目录仅 report.md（不含 review.md）；evaluator 不挂 src/task/decisions，但挂 `e2e/` 与 `op_execution/acceptance/{TID}/`。
  - 当前测试只断言 dev 无 `e2e` 且有 `src`，eval 无 `src/tasks/decisions` 且有 `e2e`。
  - 未测 `tasks_list.json`、`leader_checkpoint.md`、`review.md`、`specs/{TID}`、`acceptance/{TID}` 等更关键流程路径。
- 影响：
  - sparse-checkout 规则若误挂载 `tasks_list.json` 或 `review.md`，现有测试不会发现；这会破坏“流程文件主 worktree 单一物理副本”和 review.md 单写者约束。
  - evaluator 若缺 `acceptance/{TID}`，固化验收报告/baselines 会失败；现有测试也不会发现。
- 建议：
  - 扩展 fixture：创建 `op_execution/specs/T0001_x.md`、`tasks/T0001/report.md/review.md`、`tasks_list.json`、`leader_checkpoint.md`、`acceptance/T0001`。
  - dev 测试：spec 可读、report 路径可写、review/tasks_list/checkpoint/e2e 不物化。
  - eval 测试：e2e 与 acceptance 可写，src/tasks/decisions/tasks_list/checkpoint 不物化。
- 置信度：高
- 优先级：P2

## 8. close/checkpoint 测试未覆盖 spec 与 acceptance 归档，和 design 三态模型不完整

- 位置：
  - `/home/karon/karson_ubuntu/omni_powers/tests/scripts/close_check.bats:5-20`
  - `/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_close_post.bats:13-20`
  - `/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_checkpoint.bats:5-31`
  - `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md:149-151,506-509,853-866`
- 现象：
  - design 要求 task 完成后：工作 spec 入 `op_record/specs/`，task 目录入 `op_record/tasks/{TID}/`，acceptance 工作区入 `op_record/acceptance/{TID}/`，tasks_list 标 done，progress/checkpoint 更新。
  - 当前 tests 只检查 task 目录移动、current_task 清空、checkpoint 有完成行；fixture 中甚至没有 `op_execution/specs/` 与 `op_execution/acceptance/{TID}`。
- 影响：
  - close_post 缺 spec/acceptance 归档时测试仍绿，无法保护 op_execution “只放活的东西” 语义。
  - 验收证据链可能留在活区或丢失，审计与 compact 恢复变弱。
- 建议：
  - helpers 增加 spec 和 acceptance fixture。
  - `op_close_post.bats` 断言 spec/acceptance 均进入 op_record，且活区对应路径清空。
  - `close_check.bats` 增加检查：done task 不应仍有 active spec/acceptance。
- 置信度：高
- 优先级：P2

## 9. op_ci_local 测试覆盖了本地 CI 脚本，但该能力未在 design 能力矩阵中对应明确状态

- 位置：
  - `/home/karon/karson_ubuntu/omni_powers/tests/scripts/op_ci_local.bats:1-49`
  - `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md:53-55,538-542,590-610`
- 现象：
  - design §0.2/§2.7 将系统层夜跑回归列为 P2+/P3，当前不可用；§3.3 也将定期体检列为 P3。
  - `op_ci_local.bats` 测 `scripts/op_ci_local.sh` 生成 `.ci-results/$SHA/result.json` 与 artifacts，但 README 未列该测试，也未说明它对应 design 的哪条能力。
- 影响：
  - 测试可能保护一个未被 design 正式纳入当前能力矩阵的接口；维护者难以判断失败时应修脚本还是删测试。
  - “本地 CI 等价物” 容易被误读为系统层夜跑已落地，与 design “当前不可用” 状态冲突。
- 建议：
  - 在 README 中标注 `op_ci_local.bats` 为实验/辅助脚本，或在 design §0.2 增加 “本地 CI 证据采集脚本” 状态。
  - 若它属于 P2+/P3 夜跑前置，测试名与注释改为 “artifact capture smoke”，避免称等价物。
- 置信度：中
- 优先级：P3

## 10. README 测试范围陈旧，漏列多个现有测试并保留旧 P0/P1 修复口径

- 位置：`/home/karon/karson_ubuntu/omni_powers/tests/README.md:28-43`
- 现象：
  - README 列了 `op_close_post/op_status/op_checkpoint/op_read_verdict/close_check/pre_tool_use/op_check_env/opinit_register_hooks/opinit_skeleton/run-hook`。
  - 实际目标文件还包含 `op_check_p0.bats`、`op_ci_local.bats`、`op_mutation_check.bats`、`op_trailer_unlock.bats`、`op_worktree_setup.bats`，README 未列。
  - “对应审阅 P0/P1 修复” 是历史修复口径，不再反映 design 能力矩阵。
- 影响：
  - 新增关键测试缺少说明，审阅者无法从 README 判断覆盖完整性。
  - 能力矩阵、heavy/lite 状态机、P0/trailer/worktree/hook 这些当前审阅核心没有被系统映射。
- 建议：
  - README 改成按 design 能力矩阵分组：状态机、close/checkpoint、worktree、merge gate、trailer、hook advisory、lite profile/P0、mutation/CI。
  - 每行标注 design 章节与交付阶段（已落地/P1/P2/P3/实验）。
  - 对未覆盖能力列 “缺口” 表，尤其 merge gate、closer gate、eval brief、lite profile。
- 置信度：高
- 优先级：P2

# 改进建议

1. 先修 `helpers.bash`：统一 TID、ASCII status、当前 `tasks_list.json` schema；否则所有下游测试都在旧世界运行。
2. 按 design 能力矩阵补测试清单：`op_merge_gate.bats`、`op_closer_gate.bats`、`op_assemble_eval_brief.bats`、`oplinit_skeleton.bats`、profile-aware 脚本测试。
3. 所有 hook 测试名称加 “主会话/advisory” 边界；subagent 强制效果改测 leader 侧 gate。
4. lite P0 测试改为结束报告汇总，不再断言阻断 exit 1。
5. README 从“历史 P0/P1 修复列表”升级为“design 能力矩阵覆盖表”。

# 不确定项

1. `op_ci_local.sh` 是准备纳入 P2+/P3 夜跑，还是仅供开发本地调试；design 当前未给明确能力位。
2. lite 默认 `docs/omni_powers/e2e/` 是否也应纳入 trailer 保护；design §5.3 写 lite 默认验收资产在该目录，但 trailer 章节仍以顶层 `e2e/**` 为主。
3. 当前是否已有未列入本分块的 `op_merge_gate`/`op_closer_gate` 测试；目标清单内没有，故按缺口报告。
