## 当前模型判断依据

可观测来源：`/home/karon/.claude/settings.json` 顶层 `model=haiku`；`env.ANTHROPIC_MODEL=default_model`；`ANTHROPIC_DEFAULT_HAIKU_MODEL=default_haiku[1m]`；主会话环境提示当前由 `default_model` 驱动。不能读取运行时内部状态；current 路继承主会话。本路以 haiku 视角独立审阅，不参考其他路。

## 审阅范围

模块 09_skills_core，排除 `vendors/` 与 `docs/archive/`。全量审阅 8 文件：

1. `/home/karon/karson_ubuntu/omni_powers/skills/opinit/SKILL.md`
2. `/home/karon/karson_ubuntu/omni_powers/skills/opinit/scripts/opinit_register_hooks.sh`
3. `/home/karon/karson_ubuntu/omni_powers/skills/opinit/scripts/opinit_skeleton.sh`
4. `/home/karon/karson_ubuntu/omni_powers/skills/opintake/SKILL.md`
5. `/home/karon/karson_ubuntu/omni_powers/skills/opred/SKILL.md`
6. `/home/karon/karson_ubuntu/omni_powers/skills/opspec/SKILL.md`
7. `/home/karon/karson_ubuntu/omni_powers/skills/opstatus/SKILL.md`
8. `/home/karon/karson_ubuntu/omni_powers/skills/optriage/SKILL.md`

对照设计档案 `docs/omni_powers_design.md`（§0-§5）作上下文。

## 高优先级问题（CRITICAL / HIGH）

### H1. optriage step 3 代码块语法残缺，命令无法执行
- **位置**：`skills/optriage/SKILL.md` 第 83-85 行
- **现象**：代码块写为
  ```bash
  bash "$OP_HOME/scripts/op_new_task.sh {TID}
  ```
  缺少右花括号参数闭合 + 代码块结束标记。完整意图应是 `bash "$OP_HOME/scripts/op_new_task.sh" {TID}`（`{TID}` 是占位符），且 markdown 围栏 ``` 未闭合（下方第 87 行直接跟文字）。
- **影响**：leader 按 SKILL.md 逐字执行时 bash 会报语法错（未闭合引号），且 markdown 渲染断裂。optriage 是 leader 收尾必调 skill，转 task 这一步是核心动作，执行失败会中断 triage 流程。
- **建议**：补全为 `bash "$OP_HOME/scripts/op_new_task.sh" "{TID}"` 并闭合 ``` 围栏。
- **置信度**：高（肉眼可验，`{TID}` 后无引号闭合 + 无围栏结束）。
- **优先级**：HIGH（不是 CRITICAL 因为 leader 是 LLM 会自行纠错，但文档作为契约不应留语法残缺）。

### H2. opintake SKILL.md「相关文件」表重复条目 + 引用不存在的脚本职责错配
- **位置**：`skills/opintake/SKILL.md` 第 95-103 行
- **现象**：表内 `skills/opspec/SKILL.md` 出现两次（第 99 行与第 102 行），用途描述不同；`scripts/op_new_task.sh` 标注「工作区创建」、`scripts/op_jq.sh` 标注「tasks_list.json 查询」——但 opintake 步骤四拆 task 实际未引用任何脚本（步骤四纯文字描述 + JSON 示例），这些脚本是否真存在/被调用未在流程内验证。
- **影响**：文档冗余 + 可能误导维护者以为 opintake 调用了 `op_new_task.sh`。重复条目降低可信度。
- **建议**：合并重复行；只列 opintake 流程中真正调用的文件（`opspec/SKILL.md` 一次即可）；若步骤四确实该调 `op_new_task.sh` 写 task，应在步骤四补脚本调用，否则从表移除。
- **置信度**：高（重复行确凿）；脚本是否该被调用属推断。
- **优先级**：HIGH（文档准确性 + 流程契约一致性）。

### H3. opinit_skeleton.sh 创建 `e2e/` 目录，与 design「用户已有 e2e/ 探测提示」冲突
- **位置**：`skills/opinit/scripts/opinit_skeleton.sh` 第 29 行 `mkdir -p docs/archive e2e`
- **现象**：脚本无条件 `mkdir -p e2e`。design §1 明确：「用户项目已有顶层 e2e/ 时 init 探测提示（迁移子目录 / 显式豁免进保护 / 换路径），避免用户既有测试被锁」。SKILL.md 步骤零也无 e2e 探测逻辑。
- **影响**：若用户项目已有 `e2e/`（非 omni_powers 管理），opinit 直接 `mkdir -p` 是 no-op（已存在不报错），但既不探测也不提示——违反 design 的「避免用户既有测试被锁」意图；若用户 e2e/ 内容与 omni_powers merge gate 期望冲突（design §3.4 merge gate 硬拦 task 分支 e2e/ 变更），会把用户已有测试纳入保护范围产生意外。
- **建议**：步骤零加 `ls e2e/ 2>/dev/null` 探测；skeleton 脚本对 e2e/ 改为「不存在才建 + 存在则 WARN 由 SKILL.md 处理」，或把 e2e 目录创建移出 skeleton（交 SKILL.md 按探测结果决策）。
- **置信度**：中高（脚本行为确凿；design 探测提示要求确凿；但「是否真锁了用户测试」取决于后续 merge gate 配置，属潜在风险）。
- **优先级**：HIGH（与 design 明确要求冲突，且影响用户既有资产）。

### H4. opstatus SKILL.md 状态枚举与 design §1.1 官方表不一致
- **位置**：`skills/opstatus/SKILL.md` 第 38-49 行（渲染示例）+ 第 53-56 行（异常提示）
- **现象**：
  - 渲染示例用 emoji + 中文（`✅完成`/`🔄进行中`/`⏳待开始`/`🚫阻塞`/`⚫废弃`），但 design §1.1 官方枚举的机读 ASCII 是 `done`/`in_progress`/`ready`/`pending`/`reviewing`/`closing`/`suspended`/`blocked`/`obsolete`，且 design 明确「opstatus 渲染层映射中文给人读」。示例缺 `reviewing`/`closing`/`suspended` 三态的渲染。
  - 异常提示（第 53-56 行）提到「待规划」「阻塞」「废弃」「tech-debt」，但缺「待开始 ready」「进行中」「审阅中」的正向状态提示，且「待规划」对应 design 的 `pending`，措辞需对齐。
  - 第 13 行 profile 感知段写「无『收口中』态」——对齐 design §5.6，但渲染示例（第 38-49 行）未体现 lite 分支如何渲染。
- **影响**：opstatus 是给人看的唯一状态视图，枚举不全会导致部分 task 状态渲染空白或靠 leader 临场发挥，降低一致性。
- **建议**：渲染示例补全 9 态（或至少 heavy 8 态 + lite 标注），每态给固定 emoji+中文映射；明确 lite 下隐藏 `closing`。
- **置信度**：中高（示例缺态确凿；design 枚举权威性确凿）。
- **优先级**：HIGH（数据视图一致性，opstatus 是核心只读入口）。

### H5. opintake 缺「运行前 profile 校验脚本化」，仅靠文字 grep 易漏
- **位置**：`skills/opintake/SKILL.md` 第 13 行
- **现象**：profile 互斥校验写成内联 shell 片段 `[ -f docs/omni_powers/profile ] && ! grep -qx heavy docs/omni_powers/profile`，但既未封装为脚本，也未在步骤一前显式列出「先跑这段」。对比 opinit_skeleton.sh 第 14-23 行有完整 profile die 逻辑、opstatus/opred/optriage 只提「运行前检查环境」——opintake 作为需求入口，profile 校验散落在 frontmatter 后的提示块，leader 可能跳过。
- **影响**：lite 项目误跑 `/opintake`（应跑 `/oplintake`）时，若 leader 未执行该校验，会按 heavy 流程写 spec/拆 task，污染 lite 项目状态（design §5.2 明确互斥保护要求 die）。
- **建议**：把 profile 校验提升为步骤零的显式 bash 块（与 op_check_env.sh 并列），或纳入 `op_check_env.sh` 的 profile 分支；SKILL.md 步骤一标题前加「步骤零：环境 + profile 校验」。
- **置信度**：中（逻辑存在但位置弱；实际是否被跳过取决于 leader 遵循度）。
- **优先级**：HIGH（互斥保护是 design 硬要求，入口校验不应靠散文）。

## 中低优先级问题（MEDIUM / LOW）

### M1. opinit_register_hooks.sh git hook 覆盖判定用 grep "omni_powers"，用户自定义 hook 含此串会被误判为 omni_powers 生成
- **位置**：`skills/opinit/scripts/opinit_register_hooks.sh` 第 79 行 `grep -q "omni_powers" "$hooks_dir/$name"`
- **现象**：判定已有 git hook 是否「omni_powers 生成」靠 grep 字符串 `omni_powers`。若用户自定义 pre-commit 恰含 `omni_powers`（如注释引用本系统），会被误判为「omni_powers 生成」从而被覆盖。
- **影响**：低概率覆盖用户自定义 hook，潜在数据丢失。
- **建议**：用更精确的标记（如固定 marker 行 `# @omni_powers:generated`），或检测前先备份。
- **置信度**：中（逻辑成立但触发概率低）。
- **优先级**：MEDIUM。

### M2. opinit_register_hooks.sh trap 清理在 Windows MINGW 分支的 TMP_TEMPLATE 可能为空触发 rm 报错
- **位置**：第 52 行 `trap '[ -n "${TMP_TEMPLATE:-}" ] && rm -f "$TMP_TEMPLATE"' EXIT`
- **现象**：trap 在非 Windows 分支 TMP_TEMPLATE 始终空（条件 `[ -n ]` 为假，安全）。Windows 分支 mktemp 失败时 set -e 会先退出，trap 触发时 TMP_TEMPLATE 可能是空串（mktemp 赋值前），`rm -f ""` 报错但不致命。
- **影响**：边缘场景噪音日志。
- **建议**：`mktemp` 失败显式 die 提示，或 trap 用 `rm -f -- "${TMP_TEMPLATE:?}"`（仅在非空时 rm，当前写法已基本满足）。
- **置信度**：中低。
- **优先级**：LOW。

### M3. opinit SKILL.md 步骤六 grep '待办|未做|todo|待完成|TODO' 缺大小写/英文变体覆盖
- **位置**：`skills/opintake/SKILL.md` 同类问题在 opinit 第 118 行 `grep -rilE '待办|未做|todo|待完成|TODO'`
- **现象**：`-i` 已忽略大小写，但缺 `未完成`/`plan`/`schedule`/`backlog` 等同义词；步骤零（第 29 行）用的关键词是 `'task|plan|todo'`，两处 grep 关键词不一致。
- **影响**：候选遗漏，未执行计划提取不完整。
- **建议**：统一两处关键词集合，或抽成共享常量。
- **置信度**：中。
- **优先级**：MEDIUM。

### M4. opred SKILL.md「锁定文件解锁」步骤 3 引用已删除的 test_lock.sh，但表述半旧半新易混
- **位置**：`skills/opred/SKILL.md` 第 56 行
- **现象**：已注明「test_lock.sh 已删 Q3——锁定靠 pre_tool_use `e2e/*` 硬编码 hook」，但步骤 3/5 仍写「解锁」「重新锁定」，给人「有锁机制」的错觉，实际（按注解）是 leader 直接改。
- **影响**：读者困惑；步骤 3「解锁 = leader 直接改」与步骤 5「重新锁定」语义不对称（锁定靠 hook 硬编码，无显式「重新锁定」动作）。
- **建议**：把步骤 3/5 改写为「leader 直接改实现/测试 + 记 decisions」，删除「重新锁定」这类无对应动作的表述。
- **置信度**：中高。
- **优先级**：MEDIUM。

### M5. opspec SKILL.md「兜底」段与 opintake 职责边界描述冗余
- **位置**：`skills/opspec/SKILL.md` 第 15-20 行
- **现象**：opspec 声称「内部 skill，由 opintake 调用」，又有「兜底：用户直接命中」分支，两段逻辑（引导走 opintake vs 当场补问 ≤3 问）并存。design §4.1 明确 opspec「不直接对用户——opintake 负责和用户交互」。兜底分支削弱「内部」定位。
- **影响**：边界模糊；若 leader 直接调 opspec，可能绕过 opintake 的澄清流程。
- **建议**：要么删除兜底（强制走 opintake），要么显式标注「兜底仅限 opintake 不可用时的降级」。
- **置信度**：中。
- **优先级**：MEDIUM。

### M6. opstatus SKILL.md 第 13 行 `$SCRIPTS` 变量未定义来源
- **位置**：`skills/opstatus/SKILL.md` 第 13 行
- **现象**：写「`$SCRIPTS` = `~/.claude/scripts/omni_powers/`」，但全文未说明 `$SCRIPTS` 如何 export/设置。design §5.4 用的是 `${OP_SCRIPT_ROOT:-$OP_HOME}` fallback。两处变量名不一致（`$SCRIPTS` vs `OP_SCRIPT_ROOT`）。
- **影响**：lite 项目 leader 不知道 `$SCRIPTS` 从哪来，可能误用 `$OP_HOME`（lite 无 OP_HOME）。
- **建议**：统一为 design §5.4 的 `${OP_SCRIPT_ROOT:-$OP_HOME}`，删除 `$SCRIPTS` 别名。
- **置信度**：高（变量名确凿不一致）。
- **优先级**：MEDIUM。

### M7. opintake SKILL.md 步骤四 task JSON 示例含 `eval`/`eval_reason` 字段，但 opspec spec 模板未体现对应字段
- **位置**：`skills/opintake/SKILL.md` 第 71-72 行 vs `skills/opspec/SKILL.md` spec 模板
- **现象**：opintake task JSON 示例有 `eval: "required"` + `eval_reason: null`（对齐 design §2.5 D9），但 opspec 的 spec 模板 frontmatter（第 44-47 行）只有 `status` + `type`，无 `eval`/`eval_reason`。design §2.5 提到「spec frontmatter 亦可标」。
- **影响**：两处字段定义不对称，spec 端无法表达免派意图。
- **建议**：opspec spec 模板 frontmatter 补 `eval`/`eval_reason` 可选字段说明。
- **置信度**：中高。
- **优先级**：MEDIUM。

### L1. opinit SKILL.md 步骤三 blueprint-generator dispatch prompt 过长单行 \n 拼接
- **位置**：第 78 行、第 87 行、第 98 行
- **现象**：三个 Agent dispatch prompt 用 `\n` 内联拼接长字符串，可读性差，维护易错。
- **影响**：维护成本。
- **建议**：改用模板字符串或多行变量。
- **置信度**：高。
- **优先级**：LOW。

### L2. optriage SKILL.md「task 数量限制」段（第 114-116 行）规则突兀，design 未见依据
- **位置**：`skills/optriage/SKILL.md` 第 114-116 行
- **现象**：「转 task 总数不超过 10 个」「每 task 覆盖 issue 不超过 5 个」——硬编码阈值，design §3.2（issues 机制）未提此限制。
- **影响**：超出阈值时行为未定义（截断？警告？）；阈值依据不明。
- **建议**：补依据或改为「建议」非「限制」。
- **置信度**：中。
- **优先级**：LOW。

### L3. opred SKILL.md 第 10 行环境检查免责表述冗长
- **位置**：`skills/opred/SKILL.md` 第 10 行
- **现象**：「若仅作为被 agent prompt 引用的纯文本协议片段，不单独执行 shell，则此检查由调用入口负责」——长定语。
- **影响**：可读性。
- **建议**：精简。
- **置信度**：高。
- **优先级**：LOW。

### L4. opinit_skeleton.sh checkpoint 模板注释含「跳过」状态，与 design §1.1 枚举（无 skipped）不一致
- **位置**：`skills/opinit/scripts/opinit_skeleton.sh` 第 71 行注释 `<!-- AUTO：op_checkpoint.sh 更新（完成/待开始/待规划/阻塞/跳过/挂起）-->`
- **现象**：注释列举含「跳过」，但 design §1.1 官方枚举无 `skipped` 态（design §5.6 明确「不设 skipped 态」）。
- **影响**：注释误导，实际 checkpoint 不会出现「跳过」。
- **建议**：删除「跳过」。
- **置信度**：高。
- **优先级**：LOW（仅注释，不影响运行）。

## 改进建议

1. **统一 profile 感知入口**：opintake/opstatus/opred/optriage 的 profile 校验散落在各 SKILL.md 提示块，变量名（`$SCRIPTS` vs `OP_SCRIPT_ROOT`）和校验位置不统一。建议抽一个 `op_check_profile.sh`（或并入 `op_check_env.sh`），所有 skill 步骤零统一调用，返回 profile 值供后续分支。

2. **补全 opstatus 渲染枚举**：按 design §1.1 官方 9 态给固定 emoji+中文映射表，heavy/lite 差异（lite 隐 `closing`）在渲染层处理，避免 leader 临场发挥。

3. **e2e/ 探测前置于 skeleton**：opinit 步骤零加 e2e 探测，skeleton 脚本对 e2e 改条件创建，对齐 design §1「避免用户既有测试被锁」。

4. **文档表去重 + 字段对称**：opintake 相关文件表去重 opspec 行；opspec spec 模板补 `eval`/`eval_reason` 与 opintake task JSON 对称。

5. **脚本化互斥校验**：把 opintake 第 13 行的 profile grep 提升为显式 bash 步骤零块，与 op_check_env 并列。

## 不确定项 / 可能误报

1. **H3 e2e 目录风险**：`mkdir -p e2e` 对已存在 e2e/ 是 no-op，是否真的「锁了用户测试」取决于后续 merge gate 配置（P1 才落地，当前未落地）。若当前阶段 merge gate 未生效，实际风险低于描述。需结合 merge gate 实现状态判定。

2. **M1 grep "omni_powers" 误判**：触发需用户 hook 含此串，概率极低，可能属过度防御。

3. **M5 opspec 兜底分支**：是否真会被 leader 直接调用取决于触发机制，若 skill description 明确「内部 skill」，实际命中率低。可能属设计冗余而非缺陷。

4. **L4 注释「跳过」**：可能对齐历史版本状态枚举（A16/D1 提到删 skipped），注释未同步清理。属残留而非新缺陷。

5. **opintake 步骤四是否应调 op_new_task.sh**：SKILL.md 未写脚本调用，但相关文件表列出该脚本。可能 leader 按 jq 直接写 tasks_list.json（步骤四 JSON 示例暗示），脚本仅辅助——需对照 `op_new_task.sh` 实际职责确认（本模块未审 scripts/op_new_task.sh，不在范围）。
