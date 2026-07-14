## 当前模型判断依据

- 可观测来源：`~/.claude/settings.json` 顶层 `model=default_model`，`env.ANTHROPIC_MODEL=default_model`，默认档位映射为 haiku=`default_haiku[1m]` / sonnet=`default_sonnet[1m]` / opus=`default_opus[1m]`；主会话环境提示 powered by `default_model`。
- 结论：current 路不设置 model 覆盖，继承主会话；可观测上应为 `default_model`。
- 本报告未写入任何 secret。

## 审阅范围

- 核心规格：`docs/omni_powers_design.md`
- 本分块逐文件、逐段审阅：
  - `agents/op-closer.md`
  - `agents/op-evaluator.md`
  - `agents/op-implementer.md`
  - `agents/op-reviewer.md`

## 高优先级问题（CRITICAL / HIGH）

### 1. `op-implementer` 仍要求写 `review.md`，违反 design 的 review.md 单写者边界

- 位置：`agents/op-implementer.md:3`、`agents/op-implementer.md:22`、`agents/op-implementer.md:47-58`、`agents/op-implementer.md:65-69`
- 现象：文件描述与流程要求 implementer 在 FAIL 轮“在 review.md 追加修改记录 / Fix-N 段”，文件约定也写 `review.md` 由 op-reviewer + implementer 写。
- design 对照：`docs/omni_powers_design.md:121-123`、`326-332`、`342`、`623-627`、`631-636` 明确 `review.md` 单写者是 leader，reviewer 只返回 verdict，由 leader 落盘；implementer 的 FAIL 轮 Fix-N 修复说明应追加到 `report.md`，task 分支碰 `review.md` 会被 merge gate 白名单 REJECT。
- 影响：这是角色写权边界硬冲突。implementer 按提示写 `review.md` 会导致 heavy merge gate REJECT；lite 下会污染 review 单一事实源，破坏“review.md 末行 verdict 由 leader 控制”协议，影响状态机判定与审计轨迹。
- 建议：删除 implementer 对 `review.md` 的所有写入要求；FAIL 轮只读 review 反馈，修复记录写入 `report.md` 的 Fix-N / Round N 段；文件约定改为 `review.md` 只读，leader 单写。
- 置信度：高
- 优先级：CRITICAL

### 2. `op-reviewer` 仍允许/要求自行写 `review.md` 与直接查 `tasks_list.json`，偏离 heavy 只读 review-package 模型

- 位置：`agents/op-reviewer.md:3`、`agents/op-reviewer.md:19-21`、`agents/op-reviewer.md:61-68`
- 现象：description 写“写 review.md”；协议又说 heavy 一般不直接 Write，但输出文件仍列为 `review.md`，流程第 1 步要求“jq 查 tasks_list.json 取 workset”，第 5 步写 review.md。
- design 对照：`docs/omni_powers_design.md:327-332`、`621-627` 明确 reviewer heavy 下无 checkout，不自行 jq，不直接读 `tasks_list.json`；review-package 由脚本注入 report + 三点 diff + spec + workset 对照表；verdict 在返回文本末行给出，由 leader 落盘 `review.md`。
- 影响：heavy 下 reviewer 若按提示自行查 `tasks_list.json` 或写 `review.md`，会撞上文件系统视图设计：`tasks_list.json` 不挂给 subagent，`review.md` 不由 reviewer 写。轻则延迟失败，重则造成 reviewer 与 leader 双写、末行 verdict 可信来源不清。
- 建议：将 reviewer heavy 流程改为“只读 review-package，不 jq、不 git diff、不 Write；返回 markdown，末行 verdict”；lite 分支可保留 leader 指定路径下写 `review.md`，但要明确这是 lite 例外，且由 leader 控制 diff/package 生成。
- 置信度：高
- 优先级：HIGH

### 3. `op-evaluator` 把 DOM/a11y 列为结构化硬门主体，和 design 的 D7 降级语义冲突

- 位置：`agents/op-evaluator.md:41`、`agents/op-evaluator.md:86`、`agents/op-evaluator.md:124-127`
- 现象：evaluator 文档写“结构化信号（DOM/a11y/网络响应）从 CDP 直接抓，进机械硬门”，并在固化基准里把 DOM/a11y tree 归入“结构化/语义信号（硬门主体）”。
- design 对照：`docs/omni_powers_design.md:267-269`、`437-443` 明确 DOM/a11y 降 advisory；结构化硬门信号优先但“DOM/a11y 除外，flaky 降 advisory”；视觉/DOM 对照不阻断夜跑机械硬门。
- 影响：evaluator 会把本应 advisory 的 DOM/a11y 证据升级为机械硬门，导致 UI/CSS/组件结构调整产生 false positive，破坏 baseline 可信度与回归门语义。
- 建议：将 DOM/a11y 从硬门主体移到 advisory/锚点层；CDP 可采 DOM/a11y 作为 evaluator 判断锚点，但不得作为机械硬门阻断依据。网络响应、API、DB、stdout、进程健康、日志关键行保留硬门。
- 置信度：高
- 优先级：HIGH

### 4. `op-closer` 的 feature 归属判断权限与 design D10 冲突

- 位置：`agents/op-closer.md:57`、`agents/op-closer.md:118-123`、`agents/op-closer.md:127-129`
- 现象：blueprint_update 模板写“feature 归属：closer 从 task spec 内容判断的功能名”，输入格式也写“specs 归属：closer 从 task spec 判断的功能名”。
- design 对照：`docs/omni_powers_design.md:526`、`889` 明确 feature_key 在闸门 A 阶段确定，写入 task spec frontmatter / tasks_list，closer 只能引用不能重新判断（D10）。
- 影响：closer 重新判断 feature 归属会绕过闸门 A 与任务元数据，可能把 baseline 或生效规格合入错误功能目录，造成后续对照评、spec_index、baseline_index 错配。
- 建议：改为“feature 归属：从 task spec frontmatter / tasks_list 注入字段读取；缺失则标不确定并回报 leader，不自行判定”。
- 置信度：高
- 优先级：HIGH

## 中低优先级问题（MEDIUM / LOW）

### 5. agent 环境检查 resolver 缺少 design 要求的前置探活与失败语义

- 位置：`agents/op-evaluator.md:9-14`、`agents/op-implementer.md:7-13`、`agents/op-reviewer.md:7-12`
- 现象：三执行 agent 用 `op_script() { ls ... | head -1; }` 后直接 `bash "$(op_script op_check_env.sh)"`。若 `OP_SCRIPT_ROOT`/`OP_HOME` 为空、目录不存在、脚本不存在，会得到空路径或不清晰 Bash 错误；函数未按 design 输出 FATAL。
- design 对照：`docs/omni_powers_design.md:783-799` 要求 resolver 在根目录为空/不存在时明确 FATAL，首个脚本调用前停；脚本 profile 入口也要校验 `OP_PROFILE`。
- 影响：lite/heavy 环境缺失时会延迟失败，错误定位成本高；可能出现空路径 bash 执行错误，难以区分 OP_HOME 未设、共享脚本未安装、脚本名错误。
- 建议：统一三执行 agent 的 resolver：先计算 root，校验非空且目录存在；遍历候选目录找脚本，找不到输出 `FATAL: <script> not found under OP_SCRIPT_ROOT/OP_HOME` 并退出。补充 `OP_PROFILE` 校验提示。
- 置信度：中
- 优先级：MEDIUM

### 6. `op-closer` 的运行前检查仍硬编码 `$OP_HOME`，与 design “现状/重构边界”相符但缺少 heavy-only 声明

- 位置：`agents/op-closer.md:7`
- 现象：closer 使用 `bash "$OP_HOME/scripts/op_check_env.sh"`，未使用 `OP_SCRIPT_ROOT` fallback。
- design 对照：`docs/omni_powers_design.md:779` 说明“仅 closer 保留硬编码 `$OP_HOME`（heavy 独有，OP_SCRIPT_ROOT 不注入 closer 正确）”；`docs/omni_powers_design.md:677`、`733` 明确 lite 不派 closer。
- 影响：技术上符合当前 design，但提示词未显式写“heavy 独有 / lite 不派”，若误派到 lite 会直接因 OP_HOME 缺失失败。
- 建议：在 closer 顶部补“heavy only；OP_PROFILE=lite 时立即 FATAL：lite 不派 op-closer，由 leader 收口”。
- 置信度：中
- 优先级：LOW

### 7. `op-evaluator` 仍写“范围外发现 → 落 issues”，落盘路径表述不够精确

- 位置：`agents/op-evaluator.md:116-118`、`agents/op-evaluator.md:172-174`、`agents/op-evaluator.md:200`
- 现象：正文写“范围外发现 → 落 `issues/` / 必须落 issues”，输出报告中也写“范围外发现（落 issues）”。
- design 对照：`docs/omni_powers_design.md:415-418`、`570-572` 明确 evaluator 不直写 `issues/`；范围外发现写 acceptance issue 草稿，由 leader 收口时落盘并赋 P 级。
- 影响：虽然其写权白名单段写了 `acceptance/{TID}`，但后文“落 issues”可能诱导 evaluator 直接写 `op_execution/issues/`，越过 leader/optriage P 级复核。
- 建议：改成“范围外发现写入 `acceptance/{TID}/acceptance_report.md` 的 issue 草稿段；不直接写 `op_execution/issues/`，由 leader 收口落盘赋 P”。
- 置信度：高
- 优先级：MEDIUM

### 8. `op-reviewer` 的 lite diff 来源写 `git diff HEAD`，未同步 dispatch 锚点 sha 与 `git add -N` 要求

- 位置：`agents/op-reviewer.md:21`、`agents/op-reviewer.md:63-65`
- 现象：lite 分支提示 reviewer 可自由 `git diff HEAD`，流程也写 lite `git diff HEAD`。
- design 对照：`docs/omni_powers_design.md:327-328`、`859-860`、`905-909` 要求 lite diff 锚定 dispatch 时记录的 sha；新增文件先 `git add -N` 纳入；防 implementer 自行 commit 导致 diff 空。
- 影响：如果 implementer 在 lite 下自行 commit，`git diff HEAD` 可能为空，reviewer 失明；新增未跟踪文件也可能漏审。
- 建议：lite reviewer 不自行决定 diff，改读 leader 生成的 review-package；若保留自查，则必须使用 dispatch 锚点 sha 和 `git add -N` 后的 diff。
- 置信度：高
- 优先级：MEDIUM

### 9. `op-evaluator` 输出示例使用 emoji，与全局回复/文档风格约束不一致

- 位置：`agents/op-evaluator.md:157-164`
- 现象：验收报告示例使用 ✅ / ❌。
- design 对照：design 未直接禁止 emoji，但本次全局交流/产物偏向无 emoji；项目状态枚举也强调 ASCII 机读值稳定。
- 影响：低。若报告后续被脚本 grep 或跨平台处理，emoji 可能增加解析与渲染不确定性。
- 建议：改为 `PASS` / `FAIL` / `INSUFFICIENT_EVIDENCE` 等 ASCII 值。
- 置信度：中
- 优先级：LOW

## 改进建议

1. 为四个 agent 建一张“角色 × 文件读写权 × heavy/lite 差异”小表，直接引用 design §3.4/§5.7，避免提示词内部旧协议残留。
2. 将三执行 agent 的环境入口片段提取为同一段标准文本，减少 resolver / OP_PROFILE / OP_SCRIPT_ROOT 漂移。
3. 将 `review.md` 单写者规则设为 agent 提示词顶部铁律：implementer 不写，reviewer heavy 不写，leader 落盘；lite 例外单独说明。
4. 将 evaluator 的证据信号分层统一为 design §2.5 表述：结构化硬门、DOM/a11y advisory、视觉锚点、cua lane。
5. 对 lite 分支补充“裸评退化不是同等安全”的短警示，尤其 reviewer/evaluator 不要暗示存在 heavy 级隔离或 baseline。

## 不确定项 / 可能误报

1. `op-reviewer.md` 同时写“heavy 一般不直接 Write”和“输出文件 review.md”，可能实现层由 leader 包装 agent 返回文本后写入；若 dispatch prompt 已强约束“不许 Write”，则实际风险降低。但 agent 文件本身仍含冲突指令，建议修正。
2. `op-closer.md` 直接追加 decisions.md 不经 leader 审批，与 design §2.6 一致；closer gate 由 leader 返回后检查。此处未判为越权。
3. `op-evaluator.md` 的 DOM/a11y 硬门问题可能来自旧 D7 前表述残留；若当前脚本已在夜跑层降级，agent 提示词仍会影响 evaluator 判断与基准分类，仍建议修。