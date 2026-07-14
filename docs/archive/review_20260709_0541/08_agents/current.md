## 当前模型判断依据

可观测来源：`/home/karon/.claude/settings.json` 顶层 `model=haiku`；`env.ANTHROPIC_MODEL=default_model`；`ANTHROPIC_DEFAULT_HAIKU_MODEL=default_haiku[1m]`；`ANTHROPIC_DEFAULT_SONNET_MODEL=default_sonnet[1m]`；`ANTHROPIC_DEFAULT_OPUS_MODEL=default_opus[1m]`；主会话环境提示当前由 `default_model` 驱动。不能读取运行时内部状态；current 路继承主会话。

## 审阅范围

已按要求先完整阅读上下文文件：

- `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md`

本轮全量逐文件、逐段审阅以下文件，排除 `vendors/` 与 `docs/archive/`：

- `/home/karon/karson_ubuntu/omni_powers/agents/op-closer.md`
- `/home/karon/karson_ubuntu/omni_powers/agents/op-evaluator.md`
- `/home/karon/karson_ubuntu/omni_powers/agents/op-implementer.md`
- `/home/karon/karson_ubuntu/omni_powers/agents/op-reviewer.md`

未跑构建，未跑测试，未联网。源文件只读，仅写本报告。

## 高优先级问题（CRITICAL / HIGH）

### 1. op-evaluator 把 DOM/a11y 写成 CDP 结构化硬门，违背设计中 D7 降级规则

- 位置：`/home/karon/karson_ubuntu/omni_powers/agents/op-evaluator.md:41`、`/home/karon/karson_ubuntu/omni_powers/agents/op-evaluator.md:86`
- 现象：第 41 行写“结构化信号（DOM/a11y/网络响应）从 CDP 直接抓，进机械硬门”；第 86 行也把 `DOM/a11y/stdout/DB/API/进程` 并列为机械硬门证据。设计档案 §2.2、§2.5、§0.2 明确 D7：`DOM/a11y 降 advisory`，纯视觉与 DOM 信号不进机械硬门，夜跑回归不因视觉/DOM diff 阻断。
- 影响：evaluator 会把容易受 CSS、组件结构、兄弟节点、a11y tree 噪声影响的信号当成硬门，导致 false positive、错误阻断，且与设计中“结构化硬门信号不含 DOM/a11y”冲突。更严重时，固化测试与 baseline 可能以错误信号层级入库，破坏后续回归判定可信度。
- 建议：将第 41 行和第 86 行改为：网络响应、stdout、DB/API、进程日志等可机械断言信号进硬门；DOM/a11y 仅作 evaluator 判断锚点/advisory，除非做过稳定规范化且仅作为辅助证据。保持与第 125 行已写的“DOM/a11y tree 降 advisory”一致。
- 置信度：高
- 优先级：HIGH

### 2. op-evaluator 输出与固化路径固定顶层 `e2e/`，未按 lite 默认 `docs/omni_powers/e2e/` 与 OP_E2E_DIR 规划分流

- 位置：`/home/karon/karson_ubuntu/omni_powers/agents/op-evaluator.md:25`、`/home/karon/karson_ubuntu/omni_powers/agents/op-evaluator.md:27`、`/home/karon/karson_ubuntu/omni_powers/agents/op-evaluator.md:123`、`/home/karon/karson_ubuntu/omni_powers/agents/op-evaluator.md:160-164`、`/home/karon/karson_ubuntu/omni_powers/agents/op-evaluator.md:194-198`
- 现象：提示词多处直接要求写 `e2e/`，示例也固定为 `e2e/{TID}/...`。设计档案 §5.3 明确 lite 验收 E2E 默认写 `docs/omni_powers/e2e/`，用户显式同意才写顶层 `e2e/`；§1 也声明 `OP_E2E_DIR` 规划中，当前硬编码规则有已知问题。agent 文件未提示按 profile 或 leader 注入路径选择。
- 影响：lite 模式可能污染用户项目顶层测试目录，违反“零侵入”边界。若用户已有顶层 `e2e/`，evaluator 固化测试可能被项目 runner 自动发现，引入非预期失败或混入用户测试资产。heavy/lite 共用 agent 文件时，此硬编码风险直接影响 lite。
- 建议：在 evaluator 输入/前置约定中要求 leader 注入 `e2e_dir` 或从 brief 读取验收资产目录；heavy 默认顶层 `e2e/`，lite 默认 `docs/omni_powers/e2e/`，用户显式配置时使用配置值。所有输出模板示例改为 `{E2E_DIR}/{TID}/...`。
- 置信度：高
- 优先级：HIGH

### 3. op-reviewer lite 分支允许 reviewer 自己写 review.md，破坏设计中“review.md 单写者 = leader”的统一边界

- 位置：`/home/karon/karson_ubuntu/omni_powers/agents/op-reviewer.md:3`、`/home/karon/karson_ubuntu/omni_powers/agents/op-reviewer.md:17-27`、`/home/karon/karson_ubuntu/omni_powers/agents/op-reviewer.md:21`、`/home/karon/karson_ubuntu/omni_powers/agents/op-reviewer.md:67`
- 现象：description 写“lite 自己写”；第 21 行写 heavy 由 leader 落盘，但 lite 自己写 `review.md`；第 67 行也直接写“写 review.md”。设计档案 §1.1、§2.4、§3.4 明确 review.md 单写者 = leader，reviewer 只返回末行 verdict，leader 落盘；lite §5.6 流程虽写“派 op-reviewer → 双裁决 → tasks/{TID}/review.md”，但没有明确授权 reviewer 成为写者，且全局单写者设计用于避免任务流程文件多写者污染。
- 影响：heavy/lite 共用 agent 下，reviewer 在 lite 直写流程文件，会扩大 subagent 对流程文件的写权限，削弱 leader 作为状态一致性单点。若 reviewer 覆盖或错误追加 review 历史，后续 leader 读取末行 verdict、两轮上限、归档证据都可能失真。
- 建议：统一为 reviewer 不直接写 `review.md`，heavy/lite 均返回审查文本和末行 `verdict: PASS|FAIL`，由 leader 写入/追加。若确需 lite reviewer 写文件，应在设计档案 §5.6/§3.4 明确作为例外，并补充防覆盖要求与校验脚本。
- 置信度：中高
- 优先级：HIGH

### 4. op-reviewer lite diff 使用裸 `git diff HEAD`，与设计要求的 dispatch 锚点 sha 不一致

- 位置：`/home/karon/karson_ubuntu/omni_powers/agents/op-reviewer.md:21`、`/home/karon/karson_ubuntu/omni_powers/agents/op-reviewer.md:65`
- 现象：第 21 行与第 65 行要求 lite 下 `git diff HEAD`。设计档案 §2.4、§3.4、§5.6、§5.9 反复要求 lite diff 锚定 dispatch 时记录的 sha，防 implementer 自行 commit 致 diff 空；§5.6 第 859-860 行虽有“git diff HEAD”旧写法，但 §5.9 A19/A 锚点补强明确修正为 dispatch 锚点 sha。
- 影响：如果 implementer 在 lite 主分支直改后自行 commit，`git diff HEAD` 为空，reviewer 可能看不到实际改动，双裁决失效。这是设计已经识别的“review-package 整体失明”风险。
- 建议：lite 分支不允许 reviewer 自行裸跑 `git diff HEAD`。改为读取 leader 提供的 review-package，或明确使用 `git diff <dispatch_anchor_sha>...` / `git diff <dispatch_anchor_sha>`（按脚本约定）并要求 dispatch prompt 注入锚点。
- 置信度：高
- 优先级：HIGH

## 中低优先级问题（MEDIUM / LOW）

### 5. op-implementer 收到 review 反馈时仍要求在 review.md 追加反驳，违反“不写 review.md”铁律

- 位置：`/home/karon/karson_ubuntu/omni_powers/agents/op-implementer.md:22`、`/home/karon/karson_ubuntu/omni_powers/agents/op-implementer.md:54`、`/home/karon/karson_ubuntu/omni_powers/agents/op-implementer.md:115`
- 现象：第 22、54 行明确“不写 review.md”，但第 115 行写“不合理 → 在 review.md 追加‘此项不改因为 Y’”。同一文件内部自相矛盾，也违背设计档案 §1.1、§2.4 中 review.md 单写者 = leader、FAIL 轮 Fix-N 修复说明进入 report.md 的规则。
- 影响：implementer 可能修改 review.md，导致 merge gate 白名单拒绝，或在 lite 下污染 reviewer/leader 的裁决记录。也会让 report.md 缺少应有审计轨迹。
- 建议：第 115 行改为“不合理 → 在 report.md 的本轮 Round N 追加‘此项不改因为 Y’，附技术理由”。全文件保持“不写 review.md”。
- 置信度：高
- 优先级：MEDIUM

### 6. op-closer 让 closer 直接为 reviewer 暂存项赋 P 级，与设计中 leader/optriage 赋 P 不一致

- 位置：`/home/karon/karson_ubuntu/omni_powers/agents/op-closer.md:35-38`
- 现象：第 37 行写 `severity` 由 closer 直接赋，同时又写“P0 不由你赋”。设计档案 §3.2 写 reviewer 范围外发现由 leader 收口时落盘并赋 P；closer 一段式 §2.6 说“转 reviewer 暂存 issue”，并未把 P 级裁决明确交给 closer。`op-closer` description 和 §2.6 还强调 closer 是提案者，P0/P1 结束报告语义依赖全局裁定。
- 影响：closer 可能在缺少全局排期上下文时赋 P1/P2/P3，导致 issue 阻断语义、checkpoint 提醒、后续 optriage 处理不稳定。虽然禁止赋 P0 降低风险，但 P1 仍有“下个 spec 前必修”语义，不应轻易由 closer 单独判定。
- 建议：改为 closer 转 issue 草稿时写 `severity: TBD` 或 `severity_suggestion`，由 leader/optriage 赋最终 P 级；若保留 closer 赋 P，需在设计 §3.2/§2.6 明确“closer 作为 leader 收口代理赋 P1-P3，P0 需复核”。
- 置信度：中
- 优先级：MEDIUM

### 7. op-closer `feature_key` 缺失处理前后矛盾

- 位置：`/home/karon/karson_ubuntu/omni_powers/agents/op-closer.md:57`、`/home/karon/karson_ubuntu/omni_powers/agents/op-closer.md:129`
- 现象：第 57 行要求 feature_key 缺失“回报 leader 不自判”；第 129 行又写“不确定 feature 归属时写‘不确定’，leader 补充”。前者应停止产提案，后者允许带不确定继续写。
- 影响：closer 可能在缺少 feature_key 时仍生成涉及 `op_blueprint/specs/{feature}.md`、baselines 合入路径的提案，后续 leader 自审成本升高，也可能把 baseline 合入到错误功能键。
- 建议：统一为硬失败：feature_key 缺失或不确定时停止，回报 leader 补齐；不要生成 `blueprint_update.md`。若允许继续，则提案必须不包含 specs/baselines 路径，仅列待判定项。
- 置信度：高
- 优先级：MEDIUM

### 8. 三个执行 agent 的 `op_script()` resolver 对缺失脚本无明确 FATAL，可能变成晦涩 bash 错误

- 位置：`/home/karon/karson_ubuntu/omni_powers/agents/op-evaluator.md:11-13`、`/home/karon/karson_ubuntu/omni_powers/agents/op-implementer.md:9-12`、`/home/karon/karson_ubuntu/omni_powers/agents/op-reviewer.md:9-11`
- 现象：resolver 使用 `ls ... | head -1`，随后 `bash "$(op_script op_check_env.sh)"`。若 `OP_ROOT` 为空、目录不存在或脚本缺失，`op_script` 返回空，实际错误会变成 `bash ""` 或 `ls` 噪声。设计档案 §5.4 明确要求 resolver 后立即校验根目录存在，找不到脚本输出明确 `FATAL: $1 not found under OP_SCRIPT_ROOT` 并停在首个脚本调用前。
- 影响：环境入口配置错时，agent 失败信息不稳定，定位成本高。lite 场景尤其依赖 `OP_SCRIPT_ROOT` 注入，错误提示模糊会拖慢恢复。
- 建议：将三个 agent 的 resolver 改成设计档案 §5.4 的函数形态：检查 `${OP_SCRIPT_ROOT:-$OP_HOME}` 非空且目录存在；遍历 `$root/scripts` 与 `$root/skills/oprun/scripts`；找不到脚本时明确 FATAL 并 exit 1。
- 置信度：高
- 优先级：MEDIUM

### 9. op-closer 仍硬依赖 `$OP_HOME/scripts/op_check_env.sh`，与设计中 heavy 脚本双路径 resolver 不完全一致

- 位置：`/home/karon/karson_ubuntu/omni_powers/agents/op-closer.md:7`
- 现象：运行前检查只写 `bash "$OP_HOME/scripts/op_check_env.sh"`。设计 §5.4 提到 closer heavy 独有，OP_SCRIPT_ROOT 不注入 closer 正确；但 heavy 脚本本身也分 `$OP_HOME/scripts` 与 `$OP_HOME/skills/oprun/scripts` 两处，设计给出的通用 resolver 强调单行 fallback 不够。
- 影响：如果 `op_check_env.sh` 实际位于 `skills/oprun/scripts/` 或安装布局调整，closer 会先失败。当前可能碰巧存在 `$OP_HOME/scripts/op_check_env.sh`，但提示词抗布局漂移能力弱。
- 建议：closer 虽 heavy 独有，也复用双路径 `op_script()` resolver，但 root 固定 `${OP_HOME}`，并在 `OP_PROFILE=lite` 时立即退出。
- 置信度：中
- 优先级：LOW

### 10. op-evaluator Step 1 heavy 直接读 `op_blueprint/specs/{feature}.md`，未说明 lite 跳过该步骤的执行点

- 位置：`/home/karon/karson_ubuntu/omni_powers/agents/op-evaluator.md:16-19`、`/home/karon/karson_ubuntu/omni_powers/agents/op-evaluator.md:83-85`
- 现象：顶部 lite 分支写无 op_blueprint、无 baselines，并跳过步骤 0/2/重验对照；但步骤 1 第 2 项仍要求读 `op_blueprint/specs/{feature}.md`。顶部未明确“lite 下步骤 1.2 也跳过”。
- 影响：lite evaluator 可能读取空壳 `op_blueprint/` 或因文件不存在失败，违背 §5.7 “lite 一律不读 op_blueprint/”。
- 建议：在 lite 分支明确跳过“读生效规格”步骤；步骤 1 拆成 heavy-only 与 common：heavy 读生效规格，lite 只读 eval brief 中的工作 spec + 可测性契约。
- 置信度：高
- 优先级：MEDIUM

## 改进建议

1. 统一四个 agent 的“角色写权矩阵”小节，逐条列出 heavy/lite 下可读、可写、禁止路径，并与设计 §3.4、§5.7 对齐。当前写权散落在各文件，容易产生 `review.md`、`e2e/`、`issues/` 这类边界漂移。
2. 在 dispatch 输入格式中显式要求 leader 注入：`TID`、`work_dir`、`spec_path`、`profile`、`dispatch_anchor_sha`、`e2e_dir`、`feature_key`、`review_package_path` 或 `eval_brief_path`。agent 不自行推断关键路径。
3. 将 `OP_PROFILE=lite` 分支写成可执行清单，而不只是能力说明。例如 evaluator 顶部列“lite 跳过步骤：0、1.2、2.4 baselines、重验对照；输出 E2E 到 {E2E_DIR}”。
4. 将所有示例路径从裸 `tasks/{TID}`、`e2e/{TID}` 统一为完整相对根路径或占位变量，避免 `docs/omni_powers/op_execution/tasks/{TID}` 与 `op_execution/tasks/{TID}` 混用造成实现误解。
5. 对“暂存项转 issues”建立统一模板：reviewer/evaluator 只给草稿与 P 建议，leader/optriage 最终赋 P，除非设计明确授权 closer 赋 P1-P3。

## 不确定项 / 可能误报

1. `op-reviewer` lite 自写 `review.md` 可能是当前实现有意简化：lite 无 worktree/merge gate，允许 reviewer 直写以减少 leader 步骤。但这与设计主线“review.md 单写者 = leader”冲突，需要设计明确化。若团队已决定 lite 例外，则本问题应降级为文档需补充。
2. `op-closer` 赋 P 级可能被视作“leader 收口时派 closer 代理落盘者赋 P”。但设计 §3.2 明确写 leader 收口落盘并赋 P，且 P 级有全局排期语义，因此当前判断为中等风险。
3. `op-closer` 的 `$OP_HOME/scripts/op_check_env.sh` 可能在现有安装布局中稳定存在；问题主要是与设计中双路径 resolver 和未来布局变更不一致，故列为 LOW。
4. `OP_E2E_DIR` 仍处规划中，设计也承认当前硬编码规则存在。报告中关于 evaluator 路径的 HIGH 主要基于 lite 零侵入已经明确要求默认 `docs/omni_powers/e2e/`，不是要求立即实现未落地 config parser。
