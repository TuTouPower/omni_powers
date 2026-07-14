# agents/ 分块审阅（haiku 视角）

## 当前模型判断依据

- 可观测来源：`~/.claude/settings.json` 顶层 `model=default_model`，`env.ANTHROPIC_MODEL=default_model`，默认档位映射 haiku=`default_haiku[1m]` / sonnet=`default_sonnet[1m]` / opus=`default_opus[1m]`；主会话环境提示 powered by `default_model`。
- 结论：current 路不设 model 覆盖，继承主会话；可观测上应为 `default_model`。
- 未在报告中写入任何 secret。

## 审阅范围

核心参考：`docs/omni_powers_design.md`（已全文通读）。

本分块文件（逐段审阅）：
- `agents/op-closer.md`
- `agents/op-evaluator.md`
- `agents/op-implementer.md`
- `agents/op-reviewer.md`

---

## 高优先级问题（CRITICAL / HIGH）

### CRITICAL-1：implementer 写 review.md 直接违反 design 的单写者约束

- 位置：`agents/op-implementer.md` frontmatter description（line 3）、核心规则 4（line 23）、FAIL 轮流程步骤 5（line 54-57）、report.md 格式说明、禁止段（line 168 附近）
- 现象：多处指示 implementer 在 FAIL 轮「在 review.md 末尾追加修改记录（Fix-N 段）」「读 review.md 正文」「只改 review.md 的 Fix-N 段」。
- 影响：与 design §1.1（review.md 单写者 = leader，task 分支不许碰）、§2.4（review.md 单写者化，reviewer 返回末行 verdict 由 leader 落盘）、§3.4（review.md 在 merge gate 白名单黑名单侧，task 分支变更一律 REJECT）三处硬约束直接冲突。若 implementer 真去写 review.md：(a) 实际写不进（worktree 不挂 review.md，design §3.4 仅 task 目录挂 report.md）；(b) merge gate 会 REJECT；(c) 破坏单写者审计链。
- 建议：删除 implementer 所有"写/改 review.md"的指示。FAIL 轮修复记录全部进 report.md（顶部总报告覆盖 + Round-N 追加），design §1.1 已明确「Fix-N 并入 report.md」。frontmatter description 第 3 行的"FAIL 轮修复后在 review.md 追加修改记录"必须改为"在 report.md 追加 Round-N 修复记录"。
- 置信度：高
- 优先级：CRITICAL

### CRITICAL-2：implementer/reviewer 用 jq 查 tasks_list.json 与 design 的"不挂给 subagent"冲突

- 位置：`agents/op-implementer.md` 正向开发步骤 1（line 40：「jq 查 tasks_list.json 取该 task 元数据」）；`agents/op-reviewer.md` Review Process 步骤 1（line 63：「jq 查 tasks_list.json 取 workset」）
- 现象：两个 agent 自行 jq 读 tasks_list.json 取 workset/depends_on。
- 影响：与 design §1.1（无 brief 文件——dispatch 时 leader 在 prompt 给指针，workset/depends_on 由 dispatch 脚本从 tasks_list.json 提取注入）、§2.4（dispatch 指针：workset/depends_on 由 dispatch 脚本从 tasks_list.json 提取注入，agent 不自行 jq 现读——tasks_list.json 不挂给 implementer worktree）、§3.4（tasks_list.json 不挂给任何 subagent）三处冲突。implementer/reviewer worktree 物理上没有 tasks_list.json，jq 会失败。
- 建议：删除两个 agent 的"jq 查 tasks_list.json"步骤，改为"workset/depends_on 从 dispatch prompt 注入读取"。reviewer 的 workset 对照改为"读 review-package 中的 workset 对照表（脚本生成注入）"。
- 置信度：高
- 优先级：CRITICAL

### CRITICAL-3：implementer FAIL 轮读 review.md 但 worktree 不挂该文件

- 位置：`agents/op-implementer.md` FAIL 轮步骤 1（line 50：「读 review.md 正文 + git diff 了解当前改动」）
- 现象：FAIL 轮第一步要读 review.md，但 implementer worktree 只挂 task 目录的 report.md，不挂 review.md（design §3.4）。
- 影响：implementer 读不到 review.md，流程卡死或走偏。结合 CRITICAL-1，整个 FAIL 轮流程描述与 design 的文件系统视图脱节。
- 建议：FAIL 轮 review 反馈应从 leader dispatch prompt 注入（reviewer verdict + 范围内问题清单），implementer 不直接读 review.md 文件。
- 置信度：高
- 优先级：CRITICAL

### HIGH-1：evaluator 步骤 0/步骤 2 引导读/写对照评 baseline，但对照评是 P2 未交付能力

- 位置：`agents/op-evaluator.md` 步骤 0（line 72-80，完整描述重验对照评 + 读 baseline 路径）、步骤 2（line 127："重验时对照基准..."）
- 现象：evaluator 工作流把"重验对照评"作为完整流程描述，未标注"P2 阶段交付，当前不可用"。
- 影响：design §0.2 能力矩阵明确"evaluator baseline 对照评 = P2，当前不可用"；§2.5"系统化对照评延后至 P2 阶段"。当前 evaluator 按步骤 0 去读 `op_blueprint/baselines/baselines_index.md` 会读到空目录（per-task 阶段 op_blueprint/baselines 为空），步骤 0 的判定逻辑会混乱。虽然"首次评退化为裸评"逻辑能兜，但 agent 提示词没声明这一退化，evaluator 可能尝试读不存在路径后误判 INSUFFICIENT_EVIDENCE。
- 建议：步骤 0 加显式标注"P2 对照评能力未交付，当前一律走首次裸评分支"；或 lite 分支已有的"跳过步骤 0"模式推广到 heavy P0/P1 阶段（baseline 目录为空时强制裸评）。
- 置信度：中（实际 baseline 为空会退化，但提示词引导与能力现状不一致）
- 优先级：HIGH

### HIGH-2：closer 自行判断 feature 归属与 design D10 冲突

- 位置：`agents/op-closer.md` blueprint 更新提案模板（line 57："feature 归属：{closer 从 task spec 内容判断的功能名}"）、注意段（line 129："不确定 feature 归属时写'不确定'，leader 补充"）、dispatch prompt 输入格式（line 121："specs 归属：{closer 从 task spec 判断的功能名}"）
- 现象：closer 被指示"从 task spec 内容判断功能名"。
- 影响：design §2.6 baselines 合入流程明确"feature_key 闸门 A 阶段确定，入 task spec frontmatter / tasks_list，closer 只能引用不能重新判断（D10）"。closer 重新判断 feature_key 违反 D10，且不同 closer 实例可能判出不同功能名，破坏 specs/ 与 baselines/ 的同键一致性。
- 建议：closer 从 task spec frontmatter / tasks_list 记录的 feature_key 字段直接读取，不重新判断。改 dispatch prompt 为"specs 归属：{leader 注入 feature_key}"，模板改为"feature 归属：{从 task spec frontmatter feature_key 读取}"。
- 置信度：高
- 优先级：HIGH

### HIGH-3：reviewer "写 issue 时直接赋 P 级"与 reviewer 无 checkout 不直写 issues 矛盾

- 位置：`agents/op-reviewer.md` omni_powers 协议适配（line 24："范围外问题标【暂存】落 issue，写 issue 时直接赋 P 级（design §3.2，P0 除外）"）
- 现象：指示 reviewer "写 issue 时直接赋 P 级"，暗示 reviewer 直写 issues/ 文件。
- 影响：design §3.2 明确"reviewer 无 checkout，不直写 issues/，范围外发现写进返回文本暂存段 → leader 收口时落盘 issues/ 并赋 P"。reviewer.md 同段前后矛盾：既说"标【暂存】"又说"写 issue"。reviewer 物理上无 checkout 写不了 issue 文件（design §3.4 文件系统视图：reviewer 只读，不需要 checkout）。
- 建议：line 24 改为"范围外问题标【暂存】写进返回文本末行暂存段，由 leader 收口时落 issues/ 并赋 P（reviewer 无 checkout 不直写）"。
- 置信度：高
- 优先级：HIGH

---

## 中低优先级问题（MEDIUM / LOW）

### MEDIUM-1：closer 脚本名 close_check.sh 与 design op_closer_gate.sh 漂移

- 位置：`agents/op-closer.md` "你不管"段（line 112："close_check.sh（leader 跑）"）
- 现象：closer 引用 `close_check.sh`，但 design §0.2 能力矩阵与 §2.6 都叫 `op_closer_gate.sh`（D3 已落地）。
- 影响：命名不一致，维护时找错脚本；closer 报告"不管 close_check.sh"但 leader 实际跑的是 op_closer_gate.sh，职责描述失真。
- 建议：统一为 `op_closer_gate.sh`。
- 置信度：高
- 优先级：MEDIUM

### MEDIUM-2：closer "闸门 C 审批后写入"残留旧语义

- 位置：`agents/op-closer.md` "你不管"段（line 109："op_blueprint/ 无权限，提案给 leader，leader 闸门 C 审批后写入"）
- 现象：closer 描述 leader 写 op_blueprint 需"闸门 C 审批"。
- 影响：design §2.6 已重构为"无用户事中审批，closer 提案由 leader 自审直接写入（A18）"；commit `e59cb3c`/`5c464bb` 显示闸门 C 人审语义已清除（closer_gate 取代）。closer.md frontmatter（line 3）已正确写"不经用户事中审批"，但正文 line 109 还残留"闸门 C 审批"旧表述，前后矛盾。
- 建议：line 109 改为"op_blueprint/ 无权限，提案给 leader，leader 自审后直接写入（A18，无用户事中审批）"。
- 置信度：高
- 优先级：MEDIUM

### MEDIUM-3：closer 环境检查硬编码 $OP_HOME 缺少 lite 兜底说明

- 位置：`agents/op-closer.md` 顶部（line 8：`bash "$OP_HOME/scripts/op_check_env.sh"`）
- 现象：closer 用裸 `$OP_HOME`，其他三角色已改 `${OP_SCRIPT_ROOT:-$OP_HOME}` fallback。
- 影响：design §5.4 明确"仅 closer 保留硬编码 $OP_HOME（heavy 独有，OP_SCRIPT_ROOT 不注入 closer 正确）"——所以这是 design 预期的（closer heavy 独有，lite 不派）。但 closer.md 本身没声明"heavy 独有"，若未来 lite 误派 closer 会直接失败（$OP_HOME 未设）。属设计自洽但缺防御性注释。
- 建议：closer.md 顶部加注释"# heavy 独有，lite 不派发（design §5.4）；$OP_HOME 由 install.sh --set-ophome 写入"。
- 置信度：中（design 已声明预期，非 bug）
- 优先级：MEDIUM

### MEDIUM-4：evaluator 重验轮数上限缺失

- 位置：`agents/op-evaluator.md` 工作流全文
- 现象：evaluator.md 未提"验收回流上限 ≤3 轮"。
- 影响：design §2.5 明确"验收回流上限 3 轮（evaluator 发现验收标准不通过后的修复重验），与 review 上限 2 轮独立设定"。evaluator 不知道上限会无限重验，或到顶不标 blocked。
- 建议：evaluator.md 加协议适配段（对齐 reviewer 的"上限：同一 task 最多 X 轮"）："验收回流上限 3 轮，到顶 leader 标 blocked + 记 issue + 下一个 task"。
- 置信度：中（轮数实际由 leader 控，但 agent 应知情）
- 优先级：MEDIUM

### MEDIUM-5：closer 路径前缀省略 docs/omni_powers/ 与其他 agent 不统一

- 位置：`agents/op-closer.md` 全文（line 16-18 写权限范围用 `op_record/decisions.md`、`op_execution/acceptance/`，而 implementer/reviewer/evaluator 用 `docs/omni_powers/op_execution/...`）
- 现象：closer 省略 `docs/omni_powers/` 前缀，line 127 注"所有路径相对于 leader 指定的工作目录"。
- 影响：closer 在主 worktree 工作（design §3.4），相对项目根的路径应是 `docs/omni_powers/op_record/...`。省略前缀与其他三 agent 不统一，closer 实际执行时若 cd 到项目根会找不到 `op_record/`（真实路径在 `docs/omni_powers/op_record/`）。
- 建议：统一加 `docs/omni_powers/` 前缀，或显式声明"相对 docs/omni_powers/"。
- 置信度：中（line 127 的"工作目录"若指 docs/omni_powers/ 则 OK，但未明说）
- 优先级：MEDIUM

### LOW-1：implementer report.md 格式缺 FAIL 轮与 design §1.1 的"FAIL 轮 Fix-N 不进 review.md"呼应

- 位置：`agents/op-implementer.md` report.md 格式段（line 150-155）
- 现象：report.md 格式里有 Round 2 FAIL 修复段，但没显式写"FAIL 轮 Fix-N 只进 report.md，不进 review.md"。
- 影响：结合 CRITICAL-1，implementer 会同时写 review.md 和 report.md。格式段缺一句反向强调。
- 建议：report.md 格式段加注"FAIL 轮 Fix-N 修复记录只追加到本文件 Round-N，不写 review.md（review.md 单写者 = leader）"。
- 置信度：高（与 CRITICAL-1 同源，此处降级为 LOW 因属补充强调）
- 优先级：LOW

### LOW-2：evaluator "禁止单项"未列 reviewer 同款的 spec-delta 契约边界复核

- 位置：`agents/op-evaluator.md` 禁止段（line 196-202）
- 现象：evaluator 禁止段未提"发现需进 spec 的决策时走变更子流程上报 leader，不擅自改 spec"。
- 影响：design §2.4 执行期决策规则对所有 agent 适用。evaluator 验收发现 spec 问题时应走变更子流程（design §2.4），但 evaluator.md 没明说。reviewer.md（line 42）和 implementer.md（line 24）都有契约边界规则，evaluator 缺。
- 建议：evaluator.md 加协议条"验收中发现需改 spec 的，上报 leader 走变更子流程，不擅自改 spec"。
- 置信度：中
- 优先级：LOW

### LOW-3：reviewer 输出格式 verdict 行与 design"末行"表述一致性

- 位置：`agents/op-reviewer.md` 输出格式（line 103：`verdict: PASS`）+ 协议适配（line 20："文件最后一行必须是 verdict: PASS 或 verdict: FAIL"）
- 现象：reviewer.md 一致地要求末行 verdict，与 design §2.4"merge gate 从主分支 review.md 末行读 verdict"一致。
- 影响：无冲突，但需注意 reviewer.md line 21 说"由 leader 落盘 review.md（你一般不直接 Write）"——"一般不直接 Write"的"一般"留了口子，design §3.4 是"reviewer 无 checkout"，物理上 Write 不了。建议删"一般"。
- 置信度：高
- 优先级：LOW

---

## 改进建议

1. **统一文件系统视图声明**：四个 agent 对"我能读什么、写什么、worktree 挂什么"的描述详略不一。建议每个 agent 顶部加一张"文件系统视图"表（对齐 design §3.4 角色 × 文件系统视图矩阵），消除 CRITICAL-1/2/3 这类 worktree 挂载与 agent 指令脱节的问题。

2. **closer feature_key 读取机制显式化**：closer.md 把 feature_key 判断工作交给 closer，与 D10 冲突。应在 task spec frontmatter 定 `feature_key` 字段（design §5.7 已提"功能归属闸门 A 阶段入 task spec frontmatter"），closer 读 frontmatter 不判断。

3. **evaluator 能力现状标注**：evaluator.md 步骤 0/2 的对照评逻辑应标注"P2 未交付"，与 design §0.2 能力矩阵对齐，避免 agent 按未交付能力执行。

4. **reviewer/implementer 的 review.md 单写者约束贯穿**：两处 agent.md 的 FAIL 轮流程描述需重写——reviewer 返回末行 verdict + 范围内问题清单（leader 落盘 review.md），implementer 从 dispatch prompt 读 review 反馈 + 修复记录只进 report.md。

5. **closer 脚本名/闸门语义同步**：close_check.sh → op_closer_gate.sh；"闸门 C 审批" → "leader 自审直接写入（A18）"。

---

## 不确定项 / 可能误报

1. **CRITICAL-1/3 的 worktree 挂载**：审阅基于 design §3.4"task 目录只挂 report.md 不挂 review.md"。若实际 `op_worktree_setup.sh dev` 实现挂了 review.md（脚本未在本分块审阅范围），则 implementer 物理能读能写 review.md，但 merge gate 仍会 REJECT（design §3.4 白名单黑名单侧）。即使能写，CRITICAL-1 的 merge gate 冲突依然成立，故优先级不变。需交叉核 `scripts/op_worktree_setup.sh` 确认挂载范围。

2. **HIGH-1 对照评能力**：若 `op_assemble_eval_brief.sh` 实际在 baseline 为空时不组装对照段（脚本未在本分块），evaluator 读不到对照信息会自然退化，HIGH-1 影响降级。但提示词引导与能力现状仍不一致，建议加标注。

3. **MEDIUM-3 closer $OP_HOME**：design §5.4 明说"仅 closer 保留硬编码 $OP_HOME 正确"，所以这不是 bug，是 design 预期。MEDIUM-3 的"建议加注释"是防御性改进，非修 bug。

4. **MEDIUM-5 路径前缀**：若 closer 的"工作目录"约定就是 `docs/omni_powers/`（line 127 未明说），则路径正确。需核 dispatch prompt 的 work_dir 注入约定。

5. **evaluator 步骤 2 存基准**：evaluator.md 步骤 2 说首次评存基准到 `acceptance/{TID}/baselines/`，design §2.5 一致。但 design §2.5 又说"per-task 阶段不写 op_blueprint，验收时生效规格天然是开工前版本"——evaluator 存基准到 acceptance 不碰 op_blueprint，OK，无冲突。可能误报项，保留待交叉核。

6. **closer dispatch prompt line 121 "specs 归属"**：这是 leader 给 closer 的输入格式示例，若 leader 实际从 tasks_list/feature_key 注入而非让 closer 判断，则与 HIGH-2 冲突缓解。但 closer.md 模板 line 57 又让 closer 判断，内部矛盾，HIGH-2 优先级不变。
