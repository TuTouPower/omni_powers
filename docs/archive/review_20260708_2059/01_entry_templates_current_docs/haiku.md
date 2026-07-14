## 当前模型判断依据

- 可观测来源：`/home/karon/.claude/settings.json` 顶层 `model` = `default_model`；`env.ANTHROPIC_MODEL` = `default_model`；`env.ANTHROPIC_DEFAULT_HAIKU_MODEL` = `default_haiku[1m]`。
- 主会话环境提示显示本会话 powered by `default_haiku[1m]`，对应 haiku 档。
- 结论：当前 haiku 路，model_override_authorized 授权，符合调用预期。settings 中 secret 字段已省略，本报告不写入任何 secret。

## 审阅范围

以 `docs/omni_powers_design.md` 为核心规格，逐文件审阅：
- `.gitattributes`、`.gitignore`
- `CLAUDE.md`、`RULES.md`
- `docs/op_decisions.md`、`docs/op_first_run.md`、`docs/op_install.md`
- `docs_template/omni_powers/README.md`、`index.md`
- `docs_template/omni_powers/op_blueprint/` 全量（architecture/baselines_index/conventions/domain/prd/spec_index/test/specs）
- `docs_template/omni_powers/op_execution/` 全量（issues/checkpoint/tasks/{TID}/report.md、review.md/tasks_list.json）
- `docs_template/omni_powers/op_record/`（decisions.md、progress.md）

逐文件全量比对，不抽样。源文件只读，未做任何修改。

---

## 高优先级问题（CRITICAL / HIGH）

### H1: `docs_template/.../README.md` 命名约定 TID 示例与 design 不一致

- 位置：`docs_template/omni_powers/README.md:39`
- 现象：写「task 目录：`{TID}` 如 `T05`」。
- design 规格：design §1（行 113）明确「全局单调递增 `T0001/T0002/…`，固定四位数宽度」，D27 裁决 A5 已统一四位 `T0001`。
- 影响：模板用 `T05`（两位宽）与 design 强制四位不一致；agent 若照模板生成 TID 会破坏 TID 单调性校验与 baselines/e2e 路径键。
- 建议：改为 `T0001`。
- 置信度：高。
- 优先级：HIGH。

### H2: `docs_template/.../report.md` 模板注释引用已废弃 Round 结构

- 位置：`docs_template/omni_powers/op_execution/tasks/{TID}/report.md:22-28`
- 现象：模板含「Round 2（FAIL 修复，若有）」「## Round 1」等结构注释。
- design 规格：design §1.1（行 121）与 §2.4 步骤 1 明确「report.md 顶部总报告 + 分 Round 追加」「FAIL 轮 Fix-N 修复说明也追加到 report.md，不进 review.md」。模板结构本身与 design 一致，但模板未给 Fix-N 命名规范示例（仅写「Fix-1: ...」），而 design 多处（§2.4 步骤 1、§2.6 行 380、§2.4 review 循环上限）统一用「Fix-N」措辞。
- 影响：轻微，模板示例未误导，但缺少 FAIL 轮独立段落标注约定。
- 建议：可保留现状，非阻断性。本条降级为 LOW，见 L 区。
- 置信度：中。
- 优先级：降级 LOW（重述见 L 区，避免重复占用 HIGH 槽位）。

### H3: `docs_template/.../tasks_list.json` 模板 spec 字段值与 design 语义矛盾

- 位置：`docs_template/omni_powers/op_execution/tasks_list.json:7、17、27`
- 现象：三条 task 记录 `"spec": "{TID}"`——即 spec 字段值填 TID 本身（如 `T0001`）。
- design 规格：design §2.3（行 296-309）明确 `spec` 字段指向「该 task 的契约（验收标准/不变量/边界/技术决策全在 spec）」，例值为 `"spec": "specs/T0003_xxx.md"`——即 spec 字段是**路径**，不是 TID。
- 影响：模板让 agent 以为 spec 字段填 TID 字符串，真实部署时 spec 路径丢失，dispatch 指针无法定位 spec 文件。
- 建议：模板改为 `"spec": "specs/{TID}_{slug}.md"`。
- 置信度：高。
- 优先级：HIGH。

### H4: `docs_template/.../tasks_list.json` 模板 `type` 字段非 design 定义

- 位置：`docs_template/omni_powers/op_execution/tasks_list.json:8、19、29`
- 现象：模板每条 task 含 `"type": "实现"` 字段。
- design 规格：design §2.3（行 295-309）task 元数据字段只列 `id/title/status/spec/depends_on/workset`（加 D9 后 `eval/eval_reason`），**无 `type` 字段**。change type（feat/fix/refactor/perf）属 spec frontmatter（§2.2 模板 `type: feat`），不属 task 元数据。
- 影响：模板引入 design 未定义字段，agent 可能依赖它做 change type 分流（design §2.1/§3.1），导致测试规则判定错位。
- 建议：删除模板 `type` 行；change type 留 spec frontmatter。
- 置信度：高。
- 优先级：HIGH。

### H5: `docs_template/.../tasks_list.json` 模板 T0002 缺 `eval`/`eval_reason`，T0003 缺更甚

- 位置：`tasks_list.json:14-22（T0002）、23-32（T0003）`
- 现象：仅 T0001 示范了 `eval:"required"` + `eval_reason:null`，T0002/T0003 完全无这两个字段。
- design 规格：design §2.5（行 401）明确「task schema 字段 `eval: "required"|"skip"` + `eval_reason`，D9——oprun 机械判定免派，非临场判断」——**每条 task 都应有**，免派判据靠它机械判定。
- 影响：模板让 agent 误以为这两个字段可选；真实部署时 oprun 无法机械判定免派，退回临场判断违背 D9。
- 建议：T0002/T0003 补 `eval` 与 `eval_reason` 字段（可给 `skip` + eval_reason 示例示范免派）。
- 置信度：高。
- 优先级：HIGH。

### H6: `RULES.md` 状态机图与 design 机读 ASCII 状态不一致

- 位置：`RULES.md:20-25`
- 现象：状态机图用中文状态名「待规划 → 待开始 → 进行中 → 审阅中 → 收口中 → 完成」，状态表（行 28-37）也全中文。
- design 规格：design §1.1（行 133-147，D27 D-6 裁决）明确「status 枚举用机读值 ASCII（pending/ready/in_progress/reviewing/closing/done/suspended/blocked/obsolete）——跨平台 locale 无关」，「脚本/agent 不得自创状态串；脚本内 jq/grep 比较一律用左列 ASCII 值」。
- 影响：RULES.md 是 compact 恢复入口 + 运行时操作手册，状态名全中文与「机读 ASCII」裁决直接冲突；若 agent 照 RULES.md 写 status 会破坏 jq/grep 比较稳定性（尤其 Windows Git Bash/PowerShell）。
- 建议：RULES.md 状态机图与表统一改 ASCII 值（中文仅作「渲染中文」列注释）。
- 置信度：高。
- 优先级：HIGH。

### H7: `RULES.md` 状态表缺 `obsolete` 态

- 位置：`RULES.md:28-37`
- 现象：状态表列了 待规划/待开始/进行中/审阅中/收口中/完成/阻塞/跳过/挂起，**无「已废弃」态**。
- design 规格：design §1.1（行 145）明确有 `obsolete`（已废弃：方案调整放弃、未开始；spec 移 `op_record/specs/obsolete/`；tasks_list 保留）。
- 影响：obsolete 流程（spec 移废弃目录、TID 空洞不破坏单调性）在 RULES.md 无对应说明，compact 恢复后 leader 不知如何处理废弃 task。
- 建议：补「obsolete」行（含义 + blocked_by=null + 处置：spec 移 obsolete/）。
- 置信度：高。
- 优先级：HIGH。

### H8: `RULES.md` 状态表多出 `跳过` 态，与 design 矛盾

- 位置：`RULES.md:36`
- 现象：状态表有「跳过 | 因下游阻塞顺延」。
- design 规格：design §1.1（行 144）明确「下游因依赖未就绪不另设态，由调度器依 depends_on 不选中（§2.4）」——即 **design 故意不设 skipped 态**，下游阻塞时保持 ready，调度器不选中即可。
- 影响：RULES.md 引入 design 明确否决的状态，状态机膨胀；下游传播逻辑（RULES.md 行 50「task 阻塞后下游改 跳过」）与 design 调度逻辑冲突。
- 建议：删「跳过」态，下游传播逻辑改为「保持待开始，调度器依 depends_on 不选中」。
- 置信度：高。
- 优先级：HIGH。

### H9: `RULES.md` blocked_by 取值集与 design 不符

- 位置：`RULES.md:43-47`
- 现象：blocked_by 取值列 `resource`/`quality`/`spawn`。
- design 规格：design §1.1（行 144）blocked 行写「本 task 质量失败」，阻塞语义只有「两轮到顶（review）/ 三轮到顶（验收）」质量失败 + 外部依赖未就绪（调度不选中）。design 未定义 `resource`/`spawn` 这两个 blocked_by 值。
- 影响：RULES.md 的 resource/spawn 是旧版遗留（D17 前），与现行 design 阻塞语义不符；spawn 退避重试（行 47）属 subagent 重派协议（design §2.4 leader 上下文收敛段），不应占 task 状态。
- 建议：blocked_by 收敛为 `quality`（review/验收到顶）；外部资源缺失不标 blocked，走 issues 或挂起。
- 置信度：中高。
- 优先级：HIGH。

### H10: `docs_template/.../README.md` 归档路径注释与 design 目录结构不符

- 位置：`docs_template/omni_powers/README.md:8`
- 现象：写「task 工作区（闭环后归档到 `docs/omni_powers/op_record/tasks/{TID}/`）」——正确，但 `index.md` 与各模板需交叉核对。
- 实际问题：design §1（行 105-111）op_record 含 `decisions.md`/`progress.md`/`specs/`/`tasks/`/`acceptance/` 五项，README.md 模板索引表（行 8-34）**未列 `acceptance/` 归档**。
- 影响：design §2.6（行 508）明确 task 归档含「acceptance 工作区入 `op_record/acceptance/{TID}/`」，README.md 模板缺这一项会让 agent 归档时漏移 acceptance 目录。
- 建议：README.md 持久文件表补 `op_record/acceptance/{TID}/` 行（已归档 task 验收工作区）。
- 置信度：高。
- 优先级：HIGH。

### H11: `docs_template/.../index.md` op_record 段描述与 design 有偏差

- 位置：`docs_template/omni_powers/index.md:44-46`
- 现象：`decisions.md` 描述写「决策记录（spec 编写者设计探索 + closer 执行期自决，append-only）」；`tasks/` 写「已归档 task 的 brief/report/review」。
- design 规格：
  - decisions.md 内容源（design §1 行 106、§2.6 行 494）：spec 编写者设计探索 + 执行期 spec-delta（leader 变更子流程）+ 红灯归因（closer/red-attribution）+ 解锁（BUG-*）+ leader 降级 delta + closer 收口 + lite leader-close——**多写者**，不止「closer 执行期自决」。
  - tasks/ 归档（design §1.1 行 131）：「task 闭环后 git mv 到 `op_record/tasks/{TID}/` 归档」，每 task 两文件 **report/review**——**无 brief**（design §1.1 行 129 明确「无 brief 文件」）。
- 影响：
  - decisions.md 描述漏多写者协议，读者误以为 closer 唯一写者。
  - tasks/ 描述含 `brief` 与 design「无 brief 文件」裁决直接冲突。
- 建议：
  - decisions.md 描述改为「决策记录（设计探索 + spec-delta + 红灯归因 + closer/lite-leader 收口，多写者 append-only）」。
  - tasks/ 改为「已归档 task 的 report/review」。
- 置信度：高。
- 优先级：HIGH（brief 冲突）/ MEDIUM（decisions 描述）。

### H12: `docs_template/.../review.md` 模板 verdict 注释引用旧节号 §7.2

- 位置：`docs_template/omni_powers/op_execution/tasks/{TID}/review.md:30`
- 现象：注释写「review ≤ 2 轮（design §7.2 / RULES.md）」。
- design 规格：合并版 design 已无 §7.2，review 两轮上限在 §2.4「review 循环上限」段（行 345-349）。`baselines_index.md`、`architecture.md` 等模板引用的是现行合并版节号（如 architecture.md 行 2 写「design §3.3」——但合并版已无 §3.3，文档职责矩阵在 §1.3）。
- 影响：模板引用的 design 节号（§7.2、§3.3、§8.x 等）是**合并前旧版**节号，合并版（D20）节号已整体重排。agent 按节号查 design 会定位到错误章节。
- 建议：全模板扫一遍 design 节号引用，更新为合并版节号（§1.3 文档职责矩阵、§2.4 review 上限、§2.5 evaluator 等）。
- 置信度：高。
- 优先级：HIGH（节号漂移影响模板可信度）。

---

## 中低优先级问题（MEDIUM / LOW）

### M1: `CLAUDE.md` 卸载段提到 `docs/omni_powers/` 与 hook 清理

- 位置：`CLAUDE.md:86`
- 现象：「`--purge-project` 额外清理当前项目的 `docs/omni_powers/` 与已注册的 hook」。
- design 规格：design §5.3 lite 零侵入边界明确「禁止改用户项目已有文件」；heavy 的 `/opinit` 会重构 CLAUDE.md。卸载清理 hook 属 heavy 合理，但「清理 `docs/omni_powers/`」对 lite 项目（虽 lite 也建此目录，但归档 spec 是历史资产）可能误删。
- 影响：lite 项目跑卸载会删全部归档 spec/验收资产，不可逆。
- 建议：卸载默认只清全局 `~/.claude/`，项目内 `docs/omni_powers/` 需用户显式 `--purge-project` 且二次确认；文档应强调此点。当前措辞已含 `--purge-project` 标志，但未强调不可逆。
- 置信度：中。
- 优先级：MEDIUM。

### M2: `CLAUDE.md` 目录结构缺 `scripts/build_lite.sh` 之外的脚本说明

- 位置：`CLAUDE.md:45-46`
- 现象：只列 `install.sh` + `scripts/build_lite.sh`。
- design 规格：design §4.1（行 688-692）scripts/ 含工作集核算/review-package 生成/eval brief 组装/op_worktree_setup/op_merge_gate/op_close_pre+post/op_closer_gate 等多脚本。仓库实际有 `scripts/` 目录。
- 影响：CLAUDE.md 目录树不完整，读者不知 `scripts/` 含哪些确定性脚本。
- 建议：补 scripts/ 子项（op_merge_gate.sh/op_closer_gate.sh/op_worktree_setup.sh 等）或至少注明「见 scripts/ 目录」。
- 置信度：中。
- 优先级：MEDIUM。

### M3: `CLAUDE.md` 依赖段 `git（worktree 隔离，可选）` 与 design 定位不符

- 位置：`CLAUDE.md:91`
- 现象：写「`git`（worktree 隔离，可选）」。
- design 规格：design §0.2 能力矩阵中 worktree sparse-checkout 是「已落地」advisory 防线；merge gate（§3.4）是写入硬底线（P1）。git 对 heavy 是**核心依赖**（task 分支 + merge gate + squash-merge 全靠 git 拓扑）。
- 影响：标「可选」低估 heavy 对 git 的依赖；用户可能不装 git 致 heavy 核心机制失效。
- 建议：改为「`git`（heavy 必需：task 分支 + merge gate；lite 可选）」。
- 置信度：中高。
- 优先级：MEDIUM。

### M4: `RULES.md` compact 恢复段引用 `$OP_HOME`，lite 下该变量不存在

- 位置：`RULES.md:88-99`
- 现象：compact 恢复命令全用 `bash $OP_HOME/scripts/op_jq.sh ...`。
- design 规格：design §5.1/§5.4 明确 lite 无 `$OP_HOME`，脚本寻址用 `${OP_SCRIPT_ROOT:-$OP_HOME}` fallback；§5.2 profile 分叉段 RULES.md 行 140 已声明 lite 用 `$SCRIPTS`。
- 影响：RULES.md 主体（行 88-99）与 profile 分叉段（行 140）脚本寻址变量不一致，compact 恢复时 lite 项目按主体段跑会找不到脚本。
- 建议：主体段命令标注「heavy 用 `$OP_HOME`，lite 见 profile 分叉段」，或统一用 `${OP_SCRIPT_ROOT:-$OP_HOME}`。
- 置信度：中高。
- 优先级：MEDIUM。

### M5: `RULES.md` 「收口中」态描述与 design closer 时机有细微偏差

- 位置：`RULES.md:33`
- 现象：「双裁决 PASS + merge gate PASS 后，leader 跑 `op_close_pre.sh` 标此态，closer per-task 收口进行中」。
- design 规格：design §2.6（行 484）+ §2.4 步骤 5（行 342）顺序：验收 PASS → merge gate + squash-merge → Stage 4 closer 收口。即 merge gate PASS 后**先 squash-merge**，再 closer 收口。「收口中」应在 squash-merge 后、closer 介入时。
- 影响：RULES.md 措辞「merge gate PASS 后标收口中」漏了 squash-merge 这步，时序不精确。
- 建议：改为「双裁决 PASS + merge gate PASS + squash-merge 后，leader 跑 op_close_pre.sh 标此态」。
- 置信度：中。
- 优先级：MEDIUM。

### M6: `RULES.md` 「完成」态描述遗漏 evaluator 验收

- 位置：`RULES.md:34`
- 现象：「完成 = review PASS + merge gate PASS + closer append decisions.md 且 commit + leader 跑 op_close_post.sh」。
- design 规格：design §2.4 步骤 4-5 + §2.6 完整链：dispatch → review 双裁决 → **evaluator 验收 PASS** → merge gate → squash-merge → closer 收尾 → leader 闸门 C → 归档。evaluator 验收是完成的前置。
- 影响：RULES.md 完成定义缺 evaluator 验收，读者误以为 review PASS 即可完成。
- 建议：完成态补「+ evaluator 验收 PASS（非行为型 task 免派除外）」。
- 置信度：高。
- 优先级：MEDIUM。

### M7: `docs_template/.../leader_checkpoint.md` 引用 `close_check.sh` 路径与 design 不符

- 位置：`docs_template/omni_powers/op_execution/leader_checkpoint.md:4`
- 现象：「跑 `bash "$OP_HOME/skills/oprun/scripts/close_check.sh" {TID}`」。
- design 规格：design §4.1（行 690）脚本分两类——`scripts/`（共用，如 op_merge_gate）+ `skills/oprun/scripts/`（oprun 专属）。但 closer gate（design §2.6 行 492）是 `op_closer_gate.sh`，非 `close_check.sh`；且 close_check.sh 在 op_install.md 旧版（行 88-89）属 opstart 专属（已废弃 skill）。
- 影响：模板指向可能已不存在的脚本名（close_check.sh），且路径用 oprun skill 下，agent 跑会失败。
- 建议：核实仓库实际脚本名（closer 校验应是 `op_closer_gate.sh`，收口后校验另有可能）；更新模板引用。
- 置信度：中（需核实仓库脚本）。
- 优先级：MEDIUM。

### M8: `docs_template/.../leader_checkpoint.md` 缺 dispatch 锚点 sha 字段

- 位置：`docs_template/omni_powers/op_execution/leader_checkpoint.md:6-8`
- 现象：checkpoint 字段只有 `current_task/last_completed/next_step`。
- design 规格：design §3.4（行 630）+ §5.9 明确「记录 dispatch 锚点 sha」——reviewer diff 锚定它防 implementer 自行 commit 致 diff 空（A9/lite A8）。checkpoint 是机械断点，应记锚点 sha。
- 影响：模板缺此字段，leader 不记锚点 sha，reviewer diff 会因 implementer 自行 commit 而空。
- 建议：checkpoint 补 `dispatch_anchor_sha:` 字段（per-task 记录）。
- 置信度：高。
- 优先级：MEDIUM。

### M9: `docs_template/.../progress.md` 格式注释引用 §3 但合并版无 §3

- 位置：`docs_template/omni_powers/op_record/progress.md:4`
- 现象：写「（与 op_close_post.sh 一致，design §3）」。
- design 规格：合并版 design 目录结构在 §1（行 63-111），progress.md 定义在行 107「每 task 完成一行」。无 §3 定义此格式。
- 影响：节号引用错误（同 H12 旧节号问题）。
- 建议：改为 design §1（行 107）。
- 置信度：高。
- 优先级：MEDIUM（属 H12 节号漂移的具体实例）。

### M10: `docs_template/.../decisions.md` 模板缺 append 协议标识

- 位置：`docs_template/omni_powers/op_record/decisions.md:5`
- 现象：模板段头格式「## YYYY-MM-DD - {TID}: {决策标题}」，无来源标记。
- design 规格：design §2.6（行 494）明确「每个 append 块头部带机械标识 `[来源标记 | TID | Round-N | 日期]`」——来源标记含 red-attribution/spec-delta/leader-close/closer/lite-leader-close 等多类。
- 影响：模板格式无来源标记字段，多写者 append 时无法按标识判重（中断/重试/恢复场景）。
- 建议：模板段头加 `[来源标记 | TID | Round-N | YYYY-MM-DD]` 前缀约定说明。
- 置信度：高。
- 优先级：MEDIUM。

### M11: `docs_template/.../{feature}.md` specs 模板缺 baselines 引用说明

- 位置：`docs_template/omni_powers/op_blueprint/specs/{feature}.md:1-22`
- 现象：模板段有「接口/数据模型/行为/来源 task」，无 baselines 引用段。
- design 规格：design §1（行 90-91）+ index.md（行 33）明确 specs/{feature}.md「各功能当前生效规格（per-task 收尾时整理，含 baselines 引用）」。
- 影响：模板缺 baselines 引用段，closer 合入时不引导建 specs↔baselines 的同键引用。
- 建议：specs 模板补「## baselines 引用」段（指向 `baselines/{feature}/`）。
- 置信度：中高。
- 优先级：MEDIUM。

### M12: `docs_template/.../{TID}_quality.md` severity 取值与 design issue 协议不完全对齐

- 位置：`docs_template/omni_powers/op_execution/issues/{TID}_quality.md:9`
- 现象：severity 写 `P0 | P1`。
- design 规格：design §3.2（行 580）issue severity 是 `P0 | P1 | P2 | P3`（P2 排期/P3 可容忍）。质量阻塞（review 两轮到顶）属结构问题，design 未限定其 severity 范围。
- 影响：模板限定 P0/P1 可能过窄；review 到顶若只是 maintainability 问题（MEDIUM 级），强制 P0/P1 会膨胀阻断语义。
- 建议：severity 取全集 `P0|P1|P2|P3`，由 optriage 裁定。
- 置信度：中。
- 优先级：LOW。

### L1: `docs_template/.../baselines_index.md` 结构化信号类型注释含 DOM

- 位置：`docs_template/omni_powers/op_blueprint/baselines/baselines_index.md:19`
- 现象：「结构化信号（DOM/a11y/stdout/API 响应体/DB 查询/进程日志）」。
- design 规格：design §2.5（行 437-438）明确「DOM/a11y 除外，flaky 降 advisory」——DOM/a11y **不进**机械硬门，属视觉层 advisory。
- 影响：模板把 DOM/a11y 归入「结构化信号→进机械硬门」，与 design 降级裁决矛盾。
- 建议：模板类型注释把 DOM/a11y 移到「视觉锚点 advisory」行。
- 置信度：高。
- 优先级：LOW（注释级，但语义矛盾）。

### L2: `docs/op_first_run.md` 引用已废弃阶段划分

- 位置：`docs/op_first_run.md:67`
- 现象：闸门 C 描述写「批 closer 收尾提案 → 写入 op_blueprint + baselines 合入 + task 归档」。
- design 规格：design §2.6（D27 D-3 裁决）已改为「闸门 C 批量化 + leader 自审直接写入（无用户事中审批）」。first_run 描述「批」措辞仍暗示 per-task 人审。
- 影响：first_run 是历史执行计划（顶部声明「完成后移 archive」），非现行规格，影响有限；但措辞与现行 leader 自审模式有张力。
- 建议：若 first_run 仍留作参考，补注「闸门 C 现已批量化 + leader 自审，见 design §2.6 D27」。
- 置信度：中。
- 优先级：LOW。

### L3: `docs/op_decisions.md` D6 编号跳过（无 D11）

- 位置：`docs/op_decisions.md:59（D6 后直接 D7，无 D11 出现位置）`
- 现象：决策编号 D1-D10、D12-D27 连续，D11 缺失（D10 后是 D13，D12 插在 D14 后）。
- 影响：编号不连续，读者可能误以为遗漏决策。
- 建议：非阻断，可补注「D11 编号预留/合并」或保持现状（历史档案 append-only）。
- 置信度：高（事实）。
- 优先级：LOW。

### L4: `docs/op_decisions.md` 多条决策标「⚠️ 已被 Dx 取代」但正文未删

- 位置：`docs/op_decisions.md:7（D1）、29（D4）、43（D5）、83（D10）`
- 现象：D1/D4/D5/D10 标「已被 D15 取代」，正文保留。
- design 规格：decisions.md 是 append-only 历史，保留被取代决策合理。
- 影响：无（append-only 语义正确）。
- 建议：保持现状，无需改。
- 置信度：高。
- 优先级：LOW（信息项，非问题）。

### L5: `.gitignore` 忽略 `docs/review_*/` 但未忽略其他过程产物

- 位置：`.gitignore:1-2`
- 现象：只忽略 `/vendors/` + `docs/review_*/`。
- 观察：`docs/op_first_run.md` 顶部声明「完成后移 archive」，属过程产物但已入库；`docs/review.md`/`docs/review_response.md`（D27 提及）可能也属过程产物。
- 影响：轻微，过程产物入库增加仓库噪音。
- 建议：非阻断，按需补忽略规则（如 `docs/review.md`、`docs/review_response.md`）。
- 置信度：中。
- 优先级：LOW。

### L6: `docs_template/.../report.md` 未示范 Fix-N 命名

- 位置：`docs_template/omni_powers/op_execution/tasks/{TID}/report.md:24`
- 现象：模板写「### 修复内容（针对 review.md 哪条问题）」「- {Fix-1: ...}」。
- design 规格：design §2.4（行 326）「FAIL 轮 Fix-N 修复说明也追加到 report.md」。
- 影响：模板示例 `Fix-1` 措辞与 design 一致，非问题；仅缺多 Fix 编号递增示范。
- 置信度：高（非问题）。
- 优先级：LOW（H2 降级到此，确认非问题）。

---

## 改进建议

1. **模板 TID/spec 字段统一**（H1/H3/H4/H5）：`docs_template/` 全量扫一遍，TID 示例统一四位 `T0001`；tasks_list.json 的 `spec` 字段改路径 `specs/{TID}_{slug}.md`、删 `type` 字段、每条补 `eval`/`eval_reason`。
2. **RULES.md 状态机 ASCII 化**（H6/H7/H8/H9）：状态图与表统一 ASCII（pending/ready/...），补 obsolete、删 skipped、blocked_by 收敛 quality；这是 D27 D-6 裁决的落地，RULES.md 是 compact 恢复入口必须先行。
3. **design 节号全模板对齐**（H12/M9）：合并版 design 节号重排后，模板里所有 `design §X.Y` 引用需刷新（architecture.md/conventions.md/domain.md/prd.md/spec_index.md/test.md/baselines_index.md/review.md/progress.md 等）。
4. **decisions.md/progress.md/checkpoint 模板补机械字段**（M8/M10）：dispatch 锚点 sha、append 来源标记——多写者幂等与防 diff 空的机械依据。
5. **CLAUDE.md 依赖精度**（M3）：git 对 heavy 标必需，避免用户误判。
6. **模板 specs 补 baselines 引用**（M11）：specs↔baselines 同键零桥接是 design 核心设计，模板应引导。

---

## 不确定项 / 可能误报

1. **M7 close_check.sh 脚本名**：未实际核实仓库 `scripts/` 与 `skills/oprun/scripts/` 目录内容，close_check.sh 可能仍存在（旧版遗留）或已改名 op_closer_gate.sh。需交叉核对仓库脚本清单确认。若 close_check.sh 仍在用则 M7 误报。
2. **H9 blocked_by resource/spawn**：design 未显式枚举 blocked_by 取值集，resource/spawn 可能是 RULES.md 补充的运行时细化（spawn 退避重试有实用价值）。若用户认定这些细化合理，则 H9 的「收敛 quality」建议过激，可降级为 MEDIUM「补 design 说明」。
3. **L1 baselines DOM 归类**：baselines_index.md 注释把 DOM 列入结构化信号，但 design §2.5 明确 DOM/a11y 降 advisory。模板可能是 UI 项目场景的广义理解（a11y tree 规范化后可作锚点，design §2.5 行 438 有此语义）。若用户认可 baselines 模板保留 DOM 作「结构化候选」，L1 可不改。
4. **M2 scripts/ 目录内容**：CLAUDE.md 目录树精简是否刻意（只列入口脚本，详情交 RULES.md/design），若是则 M2 非问题。
5. **节号 §3.3 引用**（architecture.md/conventions.md/domain.md/prd.md/spec_index.md/test.md 模板头）：合并版 design 文档职责矩阵在 §1.3，但模板统一写 §3.3。若用户保留旧节号作「历史锚点」有意为之，则 H12 节号类降级。但合并版（D20）已无 §3.3，按规格应更新。

---

审阅完成。已逐文件全量比对 design，源文件未做任何修改。核心问题集中在：tasks_list.json 模板字段（H3/H4/H5）、RULES.md 状态机 ASCII 化（H6-H9）、design 节号漂移（H12/M9）、模板 TID 示例（H1）。
