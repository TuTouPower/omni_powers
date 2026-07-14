# Sonnet 视角审阅报告：模块 11_lite_skills

## 当前模型判断依据

`/home/karon/.claude/settings.json` 顶层 `model=haiku`；`env.ANTHROPIC_MODEL=default_model`；`ANTHROPIC_DEFAULT_SONNET_MODEL=default_sonnet`。Sonnet 视角审阅。

## 审阅范围

| 文件 | 行数（约） | 类型 |
|---|---|---|
| `skills/oplinit/SKILL.md` | 59 | SKILL 定义 |
| `skills/oplinit/scripts/op_check_env.sh` | 31 | 环境检查脚本 |
| `skills/oplinit/scripts/oplinit_skeleton.sh` | 98 | 骨架初始化 |
| `skills/oplintake/SKILL.md` | 116 | SKILL 定义 |
| `skills/oplintake/scripts/op_check_env.sh` | 31 | 环境检查脚本（与上同） |
| `skills/oplrun/SKILL.md` | 260 | SKILL 定义 |
| `skills/oplrun/scripts/close_check.sh` | 53 | 收口检查 |
| `skills/oplrun/scripts/op_assemble_eval_brief.sh` | 52 | evaluator brief 组装 |
| `skills/oplrun/scripts/op_check_env.sh` | 31 | 环境检查脚本（与上同） |
| `skills/oplrun/scripts/op_close_post.sh` | 93 | 收口机械步骤 |
| `skills/oplrun/scripts/op_coder_check.sh` | 33 | implementer 模式判定 |
| `skills/oplrun/scripts/op_collect_open_issues.sh` | 29 | issue 汇总 |
| `skills/oplrun/scripts/op_jq.sh` | 64 | tasks_list 查询 |
| `skills/oplrun/scripts/op_read_verdict.sh` | 36 | verdict 读取 |
| `skills/oplrun/scripts/op_status.sh` | 83 | 状态流转 |

设计文档 `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md` 已完整阅读，仅作上下文对照，不重复审阅。

---

## 高优先级问题（CRITICAL / HIGH）

### HIGH-1: `op_jq.sh` 子命令 `pending` 命名与实际语义矛盾

- **位置**: `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/op_jq.sh` 第14-16行
- **现象**: 子命令 `pending` 的 jq 过滤条件是 `.status=="ready"`，而非 `.status=="pending"`。真正返回 `pending` 状态 task 的子命令是 `pending_plan`。
- **影响**: SKILL.md 多处使用 `bash "$SCRIPTS/op_jq.sh" pending` 来"选可跑 task"（如 oplrun §3.1、§步骤一）。从名称看应返回待规划 task，实际返回待开始 task。功能上因 oplrun 确实选 `ready` 态 task，行为正确；但任何人在未读源码的情况下（包括 agent）会认为 `pending` 返回 `pending` 状态。与此对称的 `blocked`/`obsolete`/`suspended` 子命令均按状态名返回对应状态，唯独 `pending` 例外——命名一致性破窗。
- **建议**: 重命名子命令：`pending` → `ready`，`pending_plan` → `pending`。同时更新 SKILL.md 中所有引用（oplrun §3.1、§步骤一）。若为兼容暂不改，至少在对应用处加注释标明"此 pending 返回 ready"。
- **置信度**: 高
- **优先级**: HIGH（命名误导，已扩散到 SKILL.md 调用处，agent 可能误读）

### HIGH-2: `op_assemble_eval_brief.sh` "应用启动方式"段未从 spec 提取具体命令

- **位置**: `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/op_assemble_eval_brief.sh` 第36-39行
- **现象**: 脚本注释声称"只 cat 工作 spec + AC + 启动方式"，实际"应用启动方式"段仅输出固定文本"从上方工作 spec 的「可测性契约」段提取"——并未从 spec 中解析出具体启动命令注入 brief。evaluator 需要自己在 cat 出的完整 spec 文本中寻找启动方式。
- **影响**: evaluator 看到 brief 后需自行从 spec dump 中定位可测性契约段、提取启动命令。增加了 evaluator 遗漏关键信息的风险（evaluator 可能只读 brief 的"应用启动方式"段而跳过上方 spec 全文，以为该段已给出答案——实际上只是指针）。heavy 版 `op_assemble_eval_brief.sh` 在此段是从 spec 中机械提取的，lite 版退化不应退到"零提取"。
- **建议**: 用 `awk`/`sed` 从 spec 中提取可测性契约段的"应用启动方式"行（识别 `应用启动方式:` 前缀），填入该段。至少输出 spec 中存在的具体命令文本，而不是纯指针。
- **置信度**: 高
- **优先级**: HIGH（evaluator 是护栏，brief 是 evaluator 唯一入口，信息完整度直接影响验收质量）

### HIGH-3: `op_coder_check.sh` 轮次判定注释与实际行为存在歧义

- **位置**: `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/op_coder_check.sh` 第6行注释，第21-32行逻辑
- **现象**: 注释写 `review ≤ 2 轮（第 3 轮 → blocked）`，但代码逻辑为 `next_round > 2` 时 blocked。这意味着：首轮 `round=1` (normal)，1 个 verdict 后 `round=2` (fail)，2 个 verdict 后 `round=3 > 2` (blocked)。**实际 review 循环是 2 轮**（第一轮 review → fix → 第二轮 review → 到顶 block），与 design §2.4 一致。但注释"第 3 轮 → blocked"中的"第 3 轮"指的是 implementer 的第三次派发（而非 review 轮次），与 "review ≤ 2 轮"产生认知歧义。
- **影响**: 维护者可能误读为"允许 3 轮 review"而修改阈值。功能本身正确，注释需澄清。
- **建议**: 注释改为 `最多 2 轮 review-fix-re-review 循环（第 3 次派 implementer → blocked）` 或 `review ≤ 2 轮（即 implementer 最多被派 2 次，第 3 次进入 blocked）`。
- **置信度**: 中
- **优先级**: HIGH（虽然功能正确，但此脚本是 implementer 派发的前置判定点，注释歧义可能导致未来误改）

---

## 中低优先级问题（MEDIUM / LOW）

### MEDIUM-1: `op_check_env.sh` 三份副本内容相同，存在同步漂移风险

- **位置**: `skills/oplinit/scripts/op_check_env.sh`、`skills/oplintake/scripts/op_check_env.sh`、`skills/oplrun/scripts/op_check_env.sh`
- **现象**: 三份文件内容完全一致（diff 无输出）。design §5.5 将此标记为已知技术债（"lite 副本暂保留并与 heavy 同步内容"），等待共享目录方案落地后统一。
- **影响**: 任一文件修改后若不同步另两份，行为不一致，且难以被 `diff` 之外的机制发现（`build_lite.sh` 可能覆盖此检查，但 §5.5 明确说该工具"暂留维护副本同步"——说明已有同步机制）。当前三份一致，暂无实际损害。
- **建议**: 已知技术债，优先级取决于共享目录方案排期。短期可在 CI/build_lite.sh 加三份 op_check_env.sh 的 md5 比对。
- **置信度**: 高
- **优先级**: MEDIUM（设计文档已标记，短期有同步工具兜底）

### MEDIUM-2: `op_close_post.sh` 中 `SPEC_SRC` 的 `ls | head -1` 对多匹配情况静默丢弃

- **位置**: `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/op_close_post.sh` 第55行
- **现象**: `ls .../${TID}_*.md | head -1` 在存在多个匹配文件时只取第一个，其余静默丢弃不归档。
- **影响**: design §1 规定 task:spec 1:1、TID 全局唯一递增不复用，理论上不会出现多匹配。但若人工错误（手建同名 spec 副本）或脚本 bug 导致多文件，`head -1` 会静默丢弃其余 spec——不报错、不归档、不 WARN。与脚本其他位置的显式 die 风格不一致。
- **建议**: 多匹配时 die：`count=$(ls ... | wc -l); [ "$count" -gt 1 ] && die "多份 spec 匹配 ${TID}"`。
- **置信度**: 中
- **优先级**: MEDIUM（依赖 TID 唯一性约束，正常路径不触发；异常路径静默丢数据是隐患）

### MEDIUM-3: `op_collect_open_issues.sh` 的 awk 解析对 YAML frontmatter 变量健壮性有限

- **位置**: `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/op_collect_open_issues.sh` 第17-21行
- **现象**: 用 `awk -F': *'` 按冒号分隔提取 `severity`/`status`/`title`/`id` 字段。YAML frontmatter 内这些字段简单且格式可控，但以下 case 会误解析：(1) `title` 含冒号（如"修复: 登录 bug"）时 `$2` 只取第一个冒号后的部分、其余截断；(2) 多行 title 只读第一行。title 行使用了不同策略（`gsub` 去前缀而非 `$2`），一定程度缓解了问题，但 `severity`/`status` 仍按 `$2` 取。
- **影响**: 正常路径下 issue 文件由机器生成、格式受控，基本不会触发。但若手工编写 issue 时 title 含冒号，列表输出可能不完整。
- **建议**: 改用 `yq` 或 `jq` 解析更健壮；若保留 awk，统一用 `gsub(/^field: */, "")` 策略处理所有字段。
- **置信度**: 中
- **优先级**: MEDIUM（正常路径不触发，但汇总报告影响用户对 P0/P1 的感知）

### MEDIUM-4: `oplrun SKILL.md` 中 `DISPATCH_SHA` 跨步骤传递依赖 leader 记忆

- **位置**: `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/SKILL.md` §3.2 第77行设置、§3.4 第130行引用、§3.6 第184-186行引用
- **现象**: `DISPATCH_SHA=$(git rev-parse HEAD)` 在步骤 3.2 中作为 bash 变量设置，但步骤 3.4 和 3.6 是独立的命令块（agent dispatch 后的新 bash 调用），需要 leader 将 SHA 值记住并跨调用传递。SKILL.md 依赖 leader（LLM）记住此值并填入后续命令的 `${DISPATCH_SHA}` 占位符。
- **影响**: leader compact 后丢失 SHA → 3.4 reviewer diff 锚点丢失（退化为 `git diff` 而非 `git diff <sha>`）→ implementer 若自行 commit，diff 可能变空；3.6 spec 写保护检查失效（`git diff --quiet "$DISPATCH_SHA"` 拿不到正确 sha）。已通过 design D3 和 A19 意识到此问题，SKILL.md 中使用了占位符写法（要求 leader 注入），但无机械保障。
- **建议**: 将 `DISPATCH_SHA` 落盘到临时文件（如 `tasks/{TID}/.dispatch_sha`），脚本从文件读取。避免跨 compact 丢失。
- **置信度**: 高
- **优先级**: MEDIUM（design A19 已覆盖 spec 写保护的重检机制，但 reviewer diff 锚点仍受影响）

### LOW-1: `op_jq.sh` `deps` 子命令对 `depends_on: null` 的 jq 输出边界

- **位置**: `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/op_jq.sh` 第22行
- **现象**: `jq -r '.tasks[] | select(.id==$tid) | .depends_on[]?'`——`[]?` 迭代 `null` 时静默返回空。功能正确。但若 `depends_on` 是空数组 `[]`（而非 null），同样返回空，与 `null` 无法区分。当前设计规定 `depends_on` 无依赖时填 `null`（oplintake SKILL.md 步骤四：`"depends_on": null`），一致。
- **影响**: 功能正常，边界已覆盖。
- **建议**: 无需修改。留档备查。
- **置信度**: 高
- **优先级**: LOW

### LOW-2: `op_read_verdict.sh` 对无 verdict 文件返回 exit 0

- **位置**: `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/op_read_verdict.sh` 第14-19行
- **现象**: 当 review.md 不存在时，输出 `round: 0, verdict: NONE, result: NONE`，exit 0。调用方（oplrun §3.4 判定段）通过 exit code 区分 PASS/FAIL：0 = PASS 或 NONE，1 = FAIL。所以"无文件"和"PASS"同 exit code——逻辑上由 leader 先读 round 判断（round=0 vs round>0），不纯靠 exit code。行为与 SKILL.md 流程一致。
- **影响**: 功能正确，但 getter 脚本的语义是"无文件 = exit 0"——调用方需额外读输出才能区分 NONE vs PASS。设计上合理（没有 review 不等于 FAIL）。
- **建议**: 无需修改。留档备查。
- **置信度**: 高
- **优先级**: LOW

### LOW-3: `oplrun SKILL.md` 看进度段引用了不存在的 T04/T05 示例 ID

- **位置**: `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/SKILL.md` 第230-233行
- **现象**: 渲染格式示例中 TID 格式不一致：`T0001`/`T0002`/`T0003` 是标准四位数宽度，但 `T04`/`T05` 只有三位数。按 design §1 编码规则，TID 固定四位数宽度。
- **影响**: 纯文档示例不一致，不影响功能。agent 可能从示例中学习到非标准 TID 格式。
- **建议**: `T04` → `T0004`，`T05` → `T0005`。
- **置信度**: 高
- **优先级**: LOW

### LOW-4: `oplinit_skeleton.sh` 中 `leader_checkpoint.md` 模板的 `current_task:` 字段无初始值

- **位置**: `/home/karon/karson_ubuntu/omni_powers/skills/oplinit/scripts/oplinit_skeleton.sh` 第57-74行
- **现象**: 初始模板中 `current_task:` 为空行（第61行），后续 `op_close_post.sh` 用 `sed 's/^current_task:.*/current_task:/'` 清空。两者一致。但初始状态和"完成一个 task 后"的状态完全相同，无法从 checkpoint 区分"刚初始化还没跑过"和"全部 task 完成"。
- **影响**: compact 恢复时需结合 tasks_list.json 状态综合判断——这不是 checkpoint 自身能决定的事，当前设计依赖 leader 综合阅读（oplrun §步骤一：读 profile + checkpoint + jq all）。功能上无缺陷。
- **建议**: 初始模板可加注 `current_task: (无)` 或类似标记，与"全部完成"区分。非必要。
- **置信度**: 中
- **优先级**: LOW

---

## 改进建议

### 建议-1: 统一脚本注释中的 design 引用格式

各脚本注释引用 design 的方式不统一：有的用 `design §X.Y`，有的用 `design §X.Y / RULES.md`，有的用 `D6`/`D3` 等缩写。建议在 `RULES.md` 或 `CLAUDE.md` 中定义标准的引用格式，并在所有脚本中保持一致。当前混合使用不影响功能，但增加维护者定位原文的成本。

### 建议-2: `op_close_post.sh` 中 verdict 校验可增加 WARN 层

当前 `op_close_post.sh` 第38-48行对 review verdict 和 eval verdict 的校验是 hard die——不匹配则退出。但 review.md 可能存在格式漂移（如 reviewer 在 verdict 行前加了 markdown 引用前缀 `> verdict: PASS`），导致 grep 失配。可在 die 前增加 WARN 输出原始末 3 行，帮助 leader 快速定位格式问题。

### 建议-3: oplrun SKILL.md 步骤 3.3 leader 自验可更具体

SKILL.md §3.3 给出 leader 自验的 bash 命令骨架（`head -20 report.md`、`git diff --stat`、定向读 hunk），但未给出"evidence 路径"的格式约定。implementer 在 report.md 中如何写 evidence 段（命令 + 输出路径）未在 oplrun SKILL.md 或 agent prompt 中标准化。leader 自验的效果依赖 implementer 报告的格式一致性——建议在 implementer agent 的 lite 分支 prompt 中定义 `## Evidence` 段的标准格式。

### 建议-4: 三份 `op_check_env.sh` 可合并为共享引用

已知 design §5.5 规划了共享目录方案。在此之前，可将三个 skills 的 `op_check_env.sh` 替换为指向共享位置的 symlink（若 install.sh 已统一装到 `~/.claude/scripts/omni_powers/`），或至少在各脚本头部注释写明"与 XX 路径内容保持一致"。

---

## 不确定项 / 可能误报

### 不确定-1: `op_coder_check.sh` 的 `review.md` 定位路径

`op_coder_check.sh` 第11行用 `tasks/{TID}/review.md` 而非 `op_record/tasks/{TID}/review.md`——即只查活区。但若 task 已完成并被归档（`git mv` 到 op_record），此时 re-dispatch implementer 会走 normal 模式（找不到 review.md），即便历史上曾有 FAIL。按 design，done 后的 task 不应该再 dispatch implementer——此行为正确。但若 task 处于 "archived 但被 leader 手动回退" 的中间态，可能误判。对此场景的覆盖依赖流程纪律而非脚本检测。**倾向：不是 bug，但值得在注释中说明此假设。**

### 不确定-2: `op_status.sh` flock 降级在 lite 下的并发安全性

`op_status.sh` 第52-56行：`flock` 不可用时 WARN 降级为无锁写。design 原则 9 规定"task 严格串行"——lite 无并行 implementer。在此前提下无锁写安全。但若未来 lite 开并行（design §5 未规划），此降级路径需升级。**倾向：当前安全，不是 bug。**

### 不确定-3: `op_assemble_eval_brief.sh` 的"执行后端"段对 non-CDP 场景覆盖不足

硬编码的"执行后端"段只提到 CDP（Playwright）和直驱（Bash/HTTP/SQL），未提及 cua 通道。design §2.5 的可测性契约包含 CDP/cua/直驱三种通道，lite 裸评退化应从 spec 的可测性契约段提取通道信息。当前 brief 的"执行后端"段是通用说明而非针对 spec 的提取。若 spec 的可测性契约指定了 cua 通道，此段无法给出对应指导。**倾向：与 HIGH-2 类似——brief 信息完整度不足。已在 HIGH-2 中覆盖。**

---

*审阅完成时间: 2026-07-09*
