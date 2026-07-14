# Sonnet 审阅报告：skills_heavy_shared 分块

## 当前模型判断依据

- 可观测来源：主会话 powered by `default_sonnet`（env.ANTHROPIC_MODEL=default_model，默认档位 haiku=default_haiku / sonnet=default_sonnet / opus=default_opus）。当前路继承主会话模型。
- 本报告独立判断，未参考其他路（haiku/opus/fable）报告。

## 审阅范围

共 16 个文件，覆盖 heavy 流程核心 skill + 内部 skill + 配套脚本：

- `skills/opinit/SKILL.md`
- `skills/opinit/scripts/opinit_register_hooks.sh`
- `skills/opinit/scripts/opinit_skeleton.sh`
- `skills/opintake/SKILL.md`
- `skills/oprun/SKILL.md`
- `skills/oprun/scripts/close_check.sh`
- `skills/oprun/scripts/op_assemble_eval_brief.sh`
- `skills/oprun/scripts/op_checkpoint.sh`
- `skills/oprun/scripts/op_close_post.sh`
- `skills/oprun/scripts/op_close_pre.sh`
- `skills/oprun/scripts/op_coder_check.sh`
- `skills/oprun/scripts/op_read_verdict.sh`
- `skills/opspec/SKILL.md`
- `skills/opstatus/SKILL.md`
- `skills/opred/SKILL.md`
- `skills/optriage/SKILL.md`

核心参照：`docs/omni_powers_design.md`（design）。

---

## 高优先级问题

### H1. tasks_list.json 状态值：全线使用中文 vs design §1.1 强制 ASCII（跨多文件）

**位置**：
- `skills/opintake/SKILL.md` 第 68 行：`"status": "待开始"`
- `skills/oprun/scripts/op_checkpoint.sh` 第 31-36 行：jq 过滤器用 `"完成"`、`"待开始"`、`"待规划"`、`"阻塞"`、`"跳过"`、`"挂起"`
- `skills/oprun/scripts/op_close_post.sh` 第 54 行：`bash "$OP_HOME_DIR/scripts/op_status.sh" "$TID" 完成`
- `skills/oprun/scripts/op_close_pre.sh` 第 12 行：`bash "$PLUGIN_ROOT/scripts/op_status.sh" "$TID" 收口中`

**现象**：design §1.1 状态机表格明确区分「机读 ASCII」（如 `ready`、`done`、`blocked`）与「渲染中文」（如 待开始、完成、阻塞），且强制要求"脚本/agent 不得自创状态串；脚本内 jq/grep 比较一律用左列 ASCII 值"。但以上四处均为脚本/SKILL.md 示例，使用了中文渲染值。

**影响**：
- 如果 tasks_list.json 实际存储的是中文值，则 design §1.1 的 ASCII 约束形同虚设，跨平台 locale 差异可导致 `jq` 比较失败（如 Windows Git Bash 中文编码问题）。
- 如果 tasks_list.json 存储的是 ASCII 值，则 op_checkpoint.sh 的 jq 过滤器（`select(.status == "完成")`）永远不会匹配，checkpoint 状态列表永远为空。
- 无论哪种情况，design 与实现之间存在根本性不一致。

**建议**：明确单一真相：要么修改 design §1.1 去掉 ASCII 强制（承认中文值在 JSON 中可行），要么全线脚本改用 ASCII 值。如果是后者，需同步修改 `op_checkpoint.sh`、`op_close_pre.sh`、`op_close_post.sh`、`opintake/SKILL.md` 示例。推荐后者——跨平台安全。

**置信度**：高。design §1.1 规定非常明确，且多处脚本与此冲突。

**优先级**：高。

---

### H2. opspec 模板"预期失败模式"强制数量 vs design §2.5 "best effort" 非硬门槛

**位置**：`skills/opspec/SKILL.md` 第 86 行。

**现象**：opspec 模板写"预期失败模式（每条验收标准至少 1 条反例——如果 xxx 没做好，验收标准应该 FAIL）"，使用了"至少 1 条"的强制性表述。但 design §2.5 明确写"best effort——建议每条 AC 1 条反例，非硬门槛——若 xxx 没做好，验收标准应该 FAIL；evaluator 验收对照此表逐条试反例；D13"，且进一步强调"强制数量反促成凑数，价值在'逼反向思考'而非条数"。

**影响**：opspec 的"至少 1 条"会迫使 spec 编写者（leader）为每条 AC 凑反例，即使某些 AC 难以构造反例。这与 design 的权衡结论直接冲突——design 认为强制数量会"促成凑数"。

**建议**：将 opspec 模板的"每条验收标准至少 1 条反例"改为"建议每条 AC 1 条反例（best effort，非硬门槛）"，与 design 对齐。

**置信度**：高。design D13 决策记录明确说明了权衡。

**优先级**：高。

---

### H3. opintake tasks_list.json 示例字段与 design §2.3 不一致

**位置**：`skills/opintake/SKILL.md` 第 64-73 行。

**现象**：
- `spec` 字段值为 `"T0001"`（仅 ID），但 design §2.3 定义 `spec` 为 `"specs/T0003_xxx.md"`（完整路径）。
- 多出 `"type": "实现"` 字段，design §2.3 的 task 元数据 schema 中无此字段。
- 缺少 D9 规划的 `eval` / `eval_reason` 字段（design §2.5 非行为型 task 免派判定依赖此字段）。

**影响**：
- `spec` 字段格式不一致会导致 implementer/reviewer dispatch 时从 tasks_list 提取 spec 路径的逻辑出错——如果存储值只是 `"T0001"`，dispatch 脚本需要额外拼接路径；如果存储完整路径 `"specs/T0001_xxx.md"`，则直接可用。
- 多余的 `type` 字段虽不造成故障，但增加了真相源分散风险（同一信息在 spec frontmatter 的 `type` 字段和 tasks_list 的 `type` 字段各存一份）。
- 缺少 `eval` 字段使 oprun 无法机械判定免派（需临场判断），与 design "机械判定免派，非临场判断"的设计意图矛盾。

**建议**：
1. 将 `spec` 字段改为完整路径 `"specs/T0003_xxx.md"`，与 design §2.3 对齐。
2. 删除 `type` 字段（spec frontmatter 已有 `type`），或在 design §2.3 中正式定义此字段。
3. 补充 `eval` / `eval_reason` 字段（D9 规划）。

**置信度**：高。design §2.3 的 schema 定义明确。

**优先级**：高。

---

### H4. optriage P0 阻断闸门 C vs design A18 "P0 不事中阻断"

**位置**：`skills/optriage/SKILL.md` 第 58 行。

**现象**：optriage 写"P0 阻断上线 → 必须转 task，本 spec 收尾前必修，默认阻断闸门 C"。但 design A18（§2.6 事后报告）明确写"P0 issue 记录不阻断执行（P0 进结束报告，用户事后处置）"；design §3.2 也写"P0 进结束报告标注（heavy/lite 同步，A18）：不事中阻断归档，用户报告后处置"。两者直接矛盾。

**影响**：如果 optriage 坚持阻断闸门 C，则与 closer 收尾 + leader 自审直接执行的 A18 设计冲突——A18 的整个点就是"执行中不打扰用户"，P0 不应阻断流水线。

**建议**：将 optriage 的 P0 处置改为"P0 不阻断当前收尾，进结束报告标注，用户事后处置（A18）"。保留"P0 默认阻断上线"的语义（不发生产），但去掉对闸门 C 的阻塞语义。

**置信度**：高。design A18 表述清晰且多处重复。

**优先级**：高。

---

### H5. opinit SKILL.md 引用 design 章节号错误

**位置**：`skills/opinit/SKILL.md` 第 73 行。

**现象**：写"按 `$OP_HOME/docs/omni_powers_design.md §3.3` 文档职责矩阵"，但 design 的文档职责矩阵在 §1.3。§3.3 是「机械护栏」。

**影响**：agent 读 SKILL.md 时若按 §3.3 去查 design 将找不到职责矩阵，导致 blueprint-generator 生成文档时职责划分错误（如技术栈写进 conventions.md 而非 architecture.md）。

**建议**：改为 `§1.3`。

**置信度**：高。design 章节号可机械验证。

**优先级**：高。

---

## 中低优先级问题

### M1. op_checkpoint.sh 状态值 jq 查询使用中文——确认 tasks_list 实际存储格式

**位置**：`skills/oprun/scripts/op_checkpoint.sh` 第 31-36 行。

**现象**：与 H1 同根。jq 过滤器如 `select(.status == "完成")` 假设 JSON 中存储中文值。若实际存储 ASCII（`done`），则这些查询全部失效。

**影响**：checkpoint 状态表格永远显示"无"，leader 无法通过 checkpoint 了解进度。

**建议**：与 H1 一并修复——确认 JSON 实际格式后统一。

**置信度**：高。

**优先级**：中（与 H1 同因，修复 H1 时一并处理）。

---

### M2. op_close_post.sh 缺少 spec 归档与 acceptance 归档步骤

**位置**：`skills/oprun/scripts/op_close_post.sh` 第 70-73 行（git add 段）。

**现象**：design §2.6 描述归档步骤含"spec 原文入 `op_record/specs/`"与"acceptance 工作区入 `op_record/acceptance/{TID}/`"。但 op_close_post.sh 的 git add 仅包含 `op_record/tasks/$TID`（task 目录归档）、`progress.md`、`tasks_list.json`。spec 和 acceptance 的归档（git mv）未在脚本中体现。

**影响**：spec 原文和 acceptance 产物可能留存在 `op_execution/` 下未被归档，导致活跃目录堆积历史数据。

**建议**：在 op_close_post.sh 中补充 spec 归档（`git mv op_execution/specs/{TID}_*.md op_record/specs/`）和 acceptance 归档（`git mv op_execution/acceptance/{TID}/ op_record/acceptance/{TID}/`）。

**置信度**：中。需确认 spec/acceptance 归档是否在其他步骤（如 oprun SKILL.md 的手动步骤）中完成。但从脚本职责单一性角度，归档逻辑应收敛进 op_close_post.sh。

**优先级**：中。

---

### M3. opspec 模板 spec frontmatter status 枚举超出 design 定义

**位置**：`skills/opspec/SKILL.md` 第 45 行。

**现象**：spec 模板 frontmatter 注释写 `status: draft → approved → in_progress → done / cancelled`。但 design §1.2 定义 spec frontmatter 只有 `draft` 和 `approved` 两态（"approved 后冻结"）。`in_progress`、`done`、`cancelled` 是 task 级状态（tasks_list.json.status），不是 spec 级状态。

**影响**：如果实现侧真的在 spec frontmatter 上写了 `in_progress` 或 `done`，会导致 oprun 的 approved spec 漂移复查（检查 `status: approved` 的 spec 有无未 commit 改动）失效——状态为 `in_progress` 的 spec 不会被复查到。

**建议**：spec frontmatter status 注释仅保留 `draft → approved`，与 design §1.2 一致。task 级流转归 tasks_list.json。

**置信度**：高。design §1.2 明确写"approved 后冻结"。

**优先级**：中。

---

### M4. op_close_post.sh / op_close_pre.sh 变量命名不一致

**位置**：
- `skills/oprun/scripts/op_close_pre.sh` 第 7 行：`PLUGIN_ROOT="${OP_HOME:-...}"`
- `skills/oprun/scripts/op_close_post.sh` 第 7 行：`OP_HOME_DIR="${OP_HOME:-...}"`

**现象**：两个脚本用了不同变量名引用 OP_HOME：`PLUGIN_ROOT` vs `OP_HOME_DIR`。而其他脚本（如 `op_assemble_eval_brief.sh`）直接使用 `$ROOT` 拼接路径，不设中间变量。

**影响**：维护者阅读时需额外理解两个变量是同一含义。且 `PLUGIN_ROOT` 命名暗示这是 plugin 机制，但 design §4.1 已废弃 `$CLAUDE_PLUGIN_ROOT` / plugin 机制。

**建议**：统一为 `OP_HOME_DIR` 或直接使用 `$OP_HOME`（带 fallback）。

**置信度**：中。

**优先级**：低。

---

### M5. opred SKILL.md 引用 test_lock.sh 但路径未在 design 脚本清单中

**位置**：`skills/opred/SKILL.md` 第 56 行。

**现象**：写 `scripts/test_lock.sh remove <file>`，但 design §4.1 的 scripts/ 清单中无 `test_lock.sh`。design 的锁定文件机制通过 `.test_locks` 文件 + leader 手动操作实现（opinit_skeleton.sh 建 `.test_locks`，但未提及 lock/unlock 脚本）。

**影响**：implementer 按 opred 协议请求 leader 解锁时，leader 找不到 `test_lock.sh` 脚本，解锁操作无标准化入口。

**建议**：如果 `test_lock.sh` 已实现，需在 design §4.1 脚本清单中注册；如果未实现，opred 应改为描述手动解锁步骤（编辑 `.test_locks` 文件）而非引用不存在的脚本。

**置信度**：中。

**优先级**：低。

---

### M6. oprun SKILL.md P0 ff-merge 残留 vs design P1 per-task 分支模型

**位置**：`skills/oprun/SKILL.md` 第 279-288 行（收尾段 worktree 模式）。

**现象**：收尾段含 P0 整 session worktree 模型的分支代码——`git merge feat/op-dev --ff-only`（第 284 行，注释"仅 P0 模式执行"）。design §3.4 和 §4.2 已明确当前是 P1 per-task 分支模型（每 task 独立分支 + squash-merge）。P0 模式的 ff-merge 路径是过渡期残留。

**影响**：虽然注释标注了"仅 P0 模式"，但如果 leader 误跑此段（worktree 模式 + 未正确识别 P1 模型），会导致整个 session 的 task 被合并为一个 ff-merge 而非分别 squash-merge，破坏"task 即 commit"原则。

**建议**：删除 P0 ff-merge 路径，或在条件判断前加显式的模式检测（如检查是否存在 per-task 分支结构）。如果 P0 模式已彻底废弃，直接删除相关代码块。

**置信度**：中。

**优先级**：低。

---

### M7. opstatus SKILL.md lite 脚本寻址不一致

**位置**：`skills/opstatus/SKILL.md` 第 13 行 vs 第 28-31 行。

**现象**：profile 感知段声明 lite 项目脚本寻址用 `$SCRIPTS`（指向 `~/.claude/scripts/omni_powers/`），但步骤 2 的实际命令仍写 `bash "$OP_HOME/scripts/op_jq.sh"`。lite 项目没有 `$OP_HOME`（未跑 `--set-ophome`），`$OP_HOME/scripts/op_jq.sh` 路径不存在。

**影响**：lite 用户跑 `/opstatus` 时 `op_jq.sh` 找不到，命令失败。

**建议**：步骤 2 的命令改为条件分支：`[ "$OP_PROFILE" = "lite" ] && SCRIPTS=~/.claude/scripts/omni_powers || SCRIPTS="$OP_HOME/scripts"`，然后用 `$SCRIPTS/op_jq.sh`。

**置信度**：中。

**优先级**：中。

---

### M8. op_assemble_eval_brief.sh 中对 DOM 信号的表述与 design §2.5 冲突

**位置**：`skills/oprun/scripts/op_assemble_eval_brief.sh` 第 59 行；`skills/opspec/SKILL.md` 第 83 行。

**现象**：
- op_assemble_eval_brief.sh 未直接在 brief 中标注 DOM 信号降 advisory（它通过 cat 工作 spec 传递，内容由 spec 控制，本身没问题）。
- 但 opspec 模板在"AC-1 验收信号"中写"结构化优先——DOM 文本/a11y tree/CLI stdout/..."，将 DOM/a11y 归入"结构化优先"类别。而 design §2.5 明确将 DOM/a11y 归入「视觉/DOM」层（不进机械硬门，advisory），与结构化信号（CLI stdout/API/DB/进程）分开。

**影响**：spec 编写者可能误以为 DOM 文本/a11y tree 属于硬门信号，从而在可测性契约中给 DOM 信号过高的权重，导致 evaluator 验收时产生 false positive（DOM 变化不一定是行为回归）。

**建议**：opspec 模板的验收信号描述改为"结构化优先——CLI stdout/API 响应/DB 查询/进程健康检查（DOM 文本/a11y tree 为辅助锚点，advisory）"，与 design §2.5 三层次分类一致。

**置信度**：高。

**优先级**：中。

---

## 改进建议

### S1. opinit_register_hooks.sh chmod 通配符无防护

**位置**：`skills/opinit/scripts/opinit_register_hooks.sh` 第 86 行。

**现象**：`chmod +x "$OP_HOME/hooks/"*.sh "$OP_HOME/hooks/run-hook.cmd" 2>/dev/null`。若 `hooks/` 下无 `.sh` 文件，通配符保留原样，chmod 报错被 `2>/dev/null` 吞掉；若 `run-hook.cmd` 不存在，同样静默失败。两个操作的结果均未被检查。

**建议**：拆分为两个独立 chmod 调用，或使用 `for f in ...; do [ -f "$f" ] && chmod +x "$f"; done` 模式，并对缺失给出 WARN 而非静默。

**置信度**：中。

**优先级**：低。

---

### S2. opinit SKILL.md 步骤零浏览命令依赖 OP_HOME 但未先校验

**位置**：`skills/opinit/SKILL.md` 第 21-30 行。

**现象**：步骤零的浏览命令全部是裸 bash 命令（`ls *.md`、`find docs/`、`git log`），未包含 `$OP_HOME/scripts/op_check_env.sh` 校验。SKILL.md 顶部虽有"运行前检查环境"提示，但步骤零本身未执行该校验。

**影响**：如果用户跳过了顶部校验直接执行步骤零命令，jq/git 缺失不会被提前发现。但由于步骤零命令本身不依赖 jq 和 OP_HOME，实际影响较小。

**建议**：在步骤零第一条命令前加 `bash "$OP_HOME/scripts/op_check_env.sh" || exit 1`，与环境校验提示对齐。

**置信度**：低。

**优先级**：低。

---

### S3. opintake SKILL.md 缺少 spec 漂移复查（已迁移到 oprun）

**位置**：`skills/opintake/SKILL.md` 全篇。

**现象**：design §3.3 第 4 道防线描述 spec 漂移复查在 `/oprun` 启动时跑（步骤 1.3）。opintake SKILL.md 不涉及此检查是合理的，但 compact 恢复段（第 88-91 行）也未提及。如果用户在 opintake 中途 compact，恢复后不会触发 spec 漂移复查（因为复查在 oprun 启动时）。

**影响**：小——compact 恢复通常在 oprun 阶段，此时复查会触发。仅当用户在 opintake 阶段 compact 后恢复继续写 spec 时，漂移检查不会跑。但此时 spec 尚未 approved，漂移检查的核心价值（防 approved spec 被静默修改）不适用。

**建议**：无需改动。当前设计合理。

**置信度**：低。

**优先级**：最低（建议不采纳，仅为完整性记录）。

---

### S4. close_check.sh 归档检查范围不足

**位置**：`skills/oprun/scripts/close_check.sh` 第 30-39 行。

**现象**：仅检查 `op_record/tasks/{TID}/` 下 `report.md` 和 `review.md` 两个文件。但 design §2.6 的归档包含三部分：task 目录（report+review）+ spec 原文 + acceptance 工作区。close_check 不检查 spec 和 acceptance 是否归档。

**影响**：如果 op_close_post.sh 未正确归档 spec/acceptance（见 M2），close_check 不会发现缺失。

**建议**：如果 M2 在 op_close_post.sh 中补齐了 spec/acceptance 归档步骤，close_check.sh 也应相应扩展检查范围。

**置信度**：中。

**优先级**：低。

---

### S5. op_coder_check.sh 注释引用已废弃的章节号

**位置**：`skills/oprun/scripts/op_coder_check.sh` 第 6 行。

**现象**：注释写"review ≤ 2 轮（第 3 轮 → blocked，design §7.2 / RULES.md）"。design 无 §7.2（当前 design 最大章节号为 §5.9）。此外 review 两轮上限在 design §2.4 定义，不是 §7.2。

**建议**：改为 `design §2.4`。

**置信度**：高。

**优先级**：低。

---

## 不确定项

### U1. tasks_list.json 实际存储的是中文还是 ASCII 状态值？

**背景**：H1 的核心前提是 design §1.1 要求 ASCII 值，但 opintake SKILL.md 示例用了中文，op_checkpoint.sh 也用中文查询。如果实际落地时所有 tasks_list.json 都存中文值，则 H1 的修复方向是改 design（去掉 ASCII 强制）；如果存的是 ASCII，则修复方向是改所有脚本。

**建议**：检查现有项目（如有）的 tasks_list.json 实际内容，确定修复方向。

**置信度**：低（需实证，仅从代码推断不可靠）。

---

### U2. op_close_post.sh 的 `OP_HOME_DIR` fallback 路径是否在 lite 场景下可用

**背景**：`op_close_post.sh` 的 `OP_HOME_DIR` fallback 为 `$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)`，即从脚本位置向上三级。在 heavy 安装下（脚本在 `$OP_HOME/skills/oprun/scripts/`），向上三级恰好是 `$OP_HOME`。但 design §5.5 提到 lite 共享脚本在 `~/.claude/scripts/omni_powers/`（平铺），此时三级回退路径可能不正确。不过 op_close_post 是 heavy 专属脚本（lite 无 closing 态），lite 不应调用此脚本，所以此问题可能不成立。

**建议**：确认 lite 路径下是否可能误调 op_close_post。如否，可在脚本开头加 `OP_PROFILE` 检查，`lite` 时 die。

**置信度**：低。

---

### U3. optriage 中 `TID_quality.md` 与 `I-YYYYMMDD-NN.md` 双格式是否需要统一

**背景**：design §3.2 定义 issue 格式为 `I-YYYYMMDD-NN.md`。optriage SKILL.md 额外引入了 `{TID}_quality.md` 格式（绑 review 2 轮 FAIL 的 task）。两种格式并存：前者的 `spec` 字段可指向任意 TID，后者文件名即包含 TID。这是否是有意设计（快速定位阻塞 task）还是历史残留，design 未明确说明。

**建议**：在 design §3.2 中补充说明 `{TID}_quality.md` 格式的语义和使用场景。

**置信度**：低。

---

## 总结

本分块共发现 **5 个高优先级问题**、**8 个中低优先级问题**、**5 个改进建议**、**3 个不确定项**。

核心矛盾集中在三个方面：
1. **状态枚举的 ASCII / 中文分歧**（H1、M1）：design §1.1 强制 ASCII，但全线脚本和示例使用中文。这是本分块最严重的不一致——涉及跨平台 locale 安全。
2. **spec 模板与 design 的强制程度分歧**（H2、M3、M8）：opspec 模板在多处比 design 更严格（预期失败模式强制数量、frontmatter 状态枚举超定义、DOM 信号归类不当）。
3. **A18 事后报告语义未传导到下游 skill**（H4）：optriage 仍持"阻断闸门 C"旧语义，与 A18 "不事中阻断"的新设计冲突。

建议优先处理 H1-H5，其余可在后续迭代中逐步收敛。
