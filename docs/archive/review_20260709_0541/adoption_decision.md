# 审阅结果决策

## 目录
docs/review_20260709_0541

## 报告来源
- 已读：01_core_rules/current.md, haiku.md, opus.md, sonnet.md / 02_project_docs/current.md, haiku.md, opus.md, sonnet.md / 07_vendor_analysis_repos_d/current.md, haiku.md, opus.md, sonnet.md / 08_agents/current.md, haiku.md, opus.md, sonnet.md / 09_skills_core/current.md, haiku.md, opus.md, sonnet.md / 10_skills_oprun/current.md, haiku.md, opus.md, sonnet.md / 11_lite_skills/current.md, haiku.md, opus.md, sonnet.md / 12_scripts_hooks_install/current.md, haiku.md, opus.md, sonnet.md / 13_templates/current.md, haiku.md, opus.md, sonnet.md / 14_tests/current.md, haiku.md, opus.md, sonnet.md
- 缺失：无（40/40 全部齐全）

## 统计
- 采纳：30 项
- 不采纳：8 项
- 待决定：5 项

## 待决定项（请先决策）

### 1. lite 下 review.md 落盘者——reviewer 直写还是 leader 落盘
- 来源：current, haiku, opus, sonnet（08_agents 四模型共识）
- 位置：op-reviewer.md:3/21/67 / design §2.4/§3.4/§5.6
- 优先级：HIGH
- 详细判断理由：reviewer description 写"lite 自己写 review.md"，正文也指示 lite 下直写。但 design §2.4/§3.4 明确 review.md 单写者=leader，两版共用。如果 reviewer 直写，破坏单写者原则；如果 leader 落盘，agent 文件需改。design §5.6 lite 流程图字面可解读为 reviewer 写，是豁免还是笔误需裁定。
- 选项：
  - A：lite 也由 leader 落盘（统一单写者），reviewer 只返回末行 verdict 文本
  - B：lite 豁免单写者，reviewer 直写 review.md（当前 agent 描述保留）
  - C：lite 下 reviewer 写草稿 review.md，leader 最终追加 verdict 段（混合）
- 推荐：A
- 推荐理由：单写者是两版共用根基（design §3.4），lite 无 worktree 隔离更需确定性；实现成本低（改 description + 正文 3 处）

### 2. op_first_run.md 处置——按当前 design 重写还是归档
- 来源：current, haiku, opus, sonnet（02_project_docs 四模型共识）
- 位置：docs/op_first_run.md 全文
- 优先级：HIGH
- 详细判断理由：文档自述"完成后移 docs/archive/"，但仍在 docs/ 根目录。内容与当前 design 多处冲突：验收时序（merge 后验→应为 merge 前验）、闸门 C 人工审批（→应为 leader 自审+事后报告）、引用已删除的 design §8.1 调教循环、引用不存在的 op_manual_leader.md、模型配置与设计推荐不一致。无法从文件判断首跑是否已完成。
- 选项：
  - A：移入 docs/archive/，顶部标注"历史首跑计划，已过期"
  - B：按当前 design 全面重写为可执行 runbook
  - C：保留在 docs/，顶部加 frontmatter 标注 status 与过期警告
- 推荐：A
- 推荐理由：文档自述生命周期已到期，引用产物不存在（op_manual_leader.md），与当前 design 差距过大，重写成本高且首跑大概率已完成；归档后如需新首跑计划可重写

### 3. op_install.md 处置——移入 archive 还是精简保留
- 来源：current, haiku, opus, sonnet（02_project_docs 四模型共识，current/opus 标为 CRITICAL）
- 位置：docs/op_install.md 全文（381 行）
- 优先级：HIGH
- 详细判断理由：文档已自标废弃，但 381 行正文详述已废弃的 plugin 机制（`$CLAUDE_PLUGIN_ROOT`、`plugin.json`、`claude plugins install`、旧角色名等），与当前 install.sh 模型完全无关。agent 阅读时旧路径/变量名可能污染上下文。同类废弃文档已在 docs/archive/ 下，唯独此文件留在 docs/ 根目录。顶部"当前替代路径"说明本身也已过期（指向不存在的 design §11）。
- 选项：
  - A：移入 docs/archive/，路径 `docs/archive/op_install_plugin_deprecated.md`
  - B：精简为 10 行摘要留在 docs/（"历史上曾有 plugin 方案，当前见 CLAUDE.md 安装段"），其余删除
  - C：保持现状（顶部已有废弃警告）
- 推荐：A
- 推荐理由：与其他废弃文档（omni_powers_lite_design.md、op_findings.md）归档策略一致，消除 agent 上下文污染风险，实现成本最低（一次 mv）

### 4. op_decisions.md D6 取代链标注修正
- 来源：haiku, opus（02_project_docs）
- 位置：op_decisions.md:59（D6 标题）、:138（D12）、:174（D16）
- 优先级：MEDIUM
- 详细判断理由：D6 标题标"已被 D12 取代"，但 D12（两 commit）又被 D16（恢复一 commit）推翻。取代链实际为 D6→D12→D16，最终态是一 commit（与 D6 相同）。当前标注会让读者以为 D12 是最终态。是改 D6 标注为"已被 D16 取代"还是保留完整链标注，取决于文档策略。
- 选项：
  - A：D6 标题改为"已被 D16 取代（经 D12 两 commit→D16 恢复一 commit）"
  - B：保持 D6 标题不变，在 D16 正文补取代链说明
  - C：不动（历史决策记录，忠实于写出时间）
- 推荐：A
- 推荐理由：读者按取代链跳转时不会在 D12 误停，补链说明保留演进线索

### 5. optriage 转 task 是否应默认 pending 而非 ready
- 来源：current, haiku（09_skills_core）
- 位置：optriage/SKILL.md:65-82
- 优先级：HIGH
- 详细判断理由：optriage 允许 issue 直接转为 `status: ready` 的 task，复用旧 spec 路径。但这可能绕过新 task 的工作 spec 创建，形成免检通道（无新 AC、无回归测试契约）。fix 类型应"先红后绿"的约束在此流程中缺失。需权衡 optriage 的快速通道价值与 spec 完整性。
- 选项：
  - A：默认转 `pending`，强制走 `/opintake` 生成新 spec（只有 issue 已附带完整工作 spec 时允许直接 ready）
  - B：保持 ready，但要求 optriage 内联生成简化 spec（最小 AC + 回归测试契约）
  - C：保持现状（issue 已有足够上下文，leader 自审判断即可）
- 推荐：A
- 推荐理由：P0/P1 issue 修复应有独立验收标准，避免免检通道；走 opintake 成本低（已有 issue 分析结果），且保持 task 元数据完整性

## 采纳项

### 1. 脚本统一用 `$OP_HOME/scripts/`，删 lite skill 内副本及 `OP_SCRIPT_ROOT`
- 来源：四模型共识（01/02/08/09/10/11 多模块交叉指向同一根因）
- 位置：design §5.4/§5.5、install.sh:56-58、skills/oplrun/scripts/*、scripts/build_lite.sh、RULES.md:134/142、CLAUDE.md:36/46/67
- 优先级：HIGH
- 详细判断理由：四份报告一致指出 lite 脚本存在两套路径描述（skill 内副本 vs 共享目录）。讨论后确定最优架构：两版统一用 `$OP_HOME/scripts/`，lite 也需 `--set-ophome`（写入全局 `~/.claude/settings.json`，不算项目侵入）。不需要 `OP_SCRIPT_ROOT`，不需要 `~/.claude/scripts/omni_powers/` 共享目录，不需要 skill 内脚本副本。零侵入指不碰项目级 `.claude/` 和文档结构，全局 `~/.claude/` 安装不算侵入。
- 修复说明：
  - design §4.1 补 install.sh 职责边界：**只装 skill + agent + 写 `OP_HOME` 进 `~/.claude/settings.json` 全局 env**。不装 scripts 到 `~/.claude/`，不碰项目级配置
  - design §5.1 lite 零侵入边界补定义：**零侵入 = 不修改项目级 `.claude/` 配置 + 不改造项目文件结构（无 task 分支 / merge gate / hook 注册）**。全局 `~/.claude/`（skill/agent/OP_HOME env）是用户级安装，不算侵入
  - design §4.1 补 heavy 侵入范围：`/opinit` 注册项目级 hook（修改项目 `.claude/settings.json`）+ 写项目 `docs/omni_powers/` 三区骨架 + 建顶层 `e2e/`
  - design §5.4/§5.5 重写：两版统一用 `$OP_HOME/scripts/`，lite `--set-ophome` 必选；删 `OP_SCRIPT_ROOT` 全节与共享目录描述
  - 删 `skills/oplrun/scripts/` 目录（9 个脚本，lite skill 不再自带副本）
  - 删 `scripts/build_lite.sh`（漂移校验不再需要）
  - install.sh:56-58 删 scripts 安装段（脚本在仓库里，不需要装到 `~/.claude/scripts/omni_powers/`）
  - RULES.md:134/142 + CLAUDE.md:36/46/67：lite 脚本路径统一指向 `$OP_HOME/scripts/`
  - CLAUDE.md 安装说明：lite 也用 `--set-ophome`

### 2. CLAUDE.md lite 流程顺序修正——验收在收口/commit 前
- 来源：current, haiku, opus（01_core_rules）
- 位置：CLAUDE.md:33
- 优先级：HIGH
- 详细判断理由：CLAUDE.md 写 lite 流程为 `implementer → leader 自验 → reviewer → 收口 → per-task 裸评`，与 design §5.6 D6"先验 PASS 才 commit"冲突。用户按门牌文档理解会以为先 commit 再验证。三份报告一致指出此问题。
- 修复说明：CLAUDE.md:33 改为 `implementer → leader 自验 → reviewer → per-task 裸评（evaluator）→ leader 收口（commit+归档）→ P0 检查`

### 3. CLAUDE.md heavy 流程顺序修正——验收在 merge 前
- 来源：haiku, opus（01_core_rules）
- 位置：CLAUDE.md:24
- 优先级：HIGH
- 详细判断理由：CLAUDE.md 写 heavy 流程为 `review → merge → per-task 验收`，但 design §2.4 和 §3.4 明确验收在 merge 前（task 分支上验，PASS 才 merge）。与 lite 问题同类——门牌文档时序颠倒。
- 修复说明：CLAUDE.md:24 改为 `task 循环（review → per-task 验收（merge 前验）→ merge → closer 收尾 → 归档）`

### 4. RULES.md:68 回滚命令用中文状态值「待开始」→ 改为 `ready`
- 来源：current, haiku, opus, sonnet（01_core_rules 四模型共识）
- 位置：RULES.md:68
- 优先级：HIGH
- 详细判断理由：四份报告全部指出 RULES.md 回滚步骤写 `bash $OP_HOME/scripts/op_status.sh {TID} 待开始`，违反 design §1.1 ASCII 状态枚举规则。用户/agent 照抄会导致脚本因状态串不匹配失败。RULES.md 是 compact 恢复入口，恢复场景直接抄这行概率高。
- 修复说明：RULES.md:68 改为 `bash $OP_HOME/scripts/op_status.sh {TID} ready`

### 5. RULES.md:98 删除 `op_jq.sh skipped` 命令
- 来源：current, haiku（01_core_rules）
- 位置：RULES.md:98
- 优先级：MEDIUM
- 详细判断理由：RULES.md 第 51 行已明确"不设 skipped 态"，但 compact 恢复命令清单仍列 `bash $OP_HOME/scripts/op_jq.sh skipped`。A16 已删 skipped，保留此命令会让 compact 恢复时执行失败或返回空。
- 修复说明：删除 RULES.md:98 行，或改为注释 `# skipped 态已废弃（A16），不查`

### 6. RULES.md:112 跨 agent 铁律——lite 不再需要 fallback，统一用 `$OP_HOME/scripts/`
- 来源：current, haiku, opus（01_core_rules）
- 位置：RULES.md:112
- 优先级：HIGH
- 详细判断理由：RULES.md:112 写"任何 skill/agent 入口先跑 `bash "$OP_HOME/scripts/op_check_env.sh"`"，此前因 lite 无 `$OP_HOME` 需要 fallback。脚本统一后 lite 也有 `$OP_HOME`，不再需要 fallback 写法。
- 修复说明：保持 `bash "$OP_HOME/scripts/op_check_env.sh"` 即可（两版统一，无需 profile 分支）

### 7. RULES.md compact 恢复改为 profile-first
- 来源：opus（01_core_rules）
- 位置：RULES.md:8-10（compact 恢复入口段）
- 优先级：MEDIUM
- 详细判断理由：RULES.md compact 恢复入口写"读本文件 + jq 查 tasks_list + 读 checkpoint"，但 profile 分叉段又说"compact 恢复第一步先读 profile"。先按 heavy 默认执行会走错脚本/状态机。design §5.2 明确 profile 是 compact 恢复第一步。
- 修复说明：RULES.md 顶部 compact 恢复段改为：先读 `docs/omni_powers/profile`，再按 profile 选状态机，然后 jq/checkpoint

### 8. op-implementer.md:113 review.md → report.md
- 来源：current, haiku, opus, sonnet（08_agents 四模型共识，opus 标为 CRITICAL）
- 位置：agents/op-implementer.md:113
- 优先级：CRITICAL
- 详细判断理由：第 23/54 行明确"不写 review.md（单写者=leader）"，但第 113 行写"不合理 → 在 review.md 追加'此项不改因为 Y'"。同一文件自相矛盾。implementer 若按第 113 行执行，heavy 下 merge gate REJECT，lite 下污染裁决记录。
- 修复说明：agents/op-implementer.md:113 改为 `不合理 → 在 report.md 当前 Round 段追加"此项不改因为 Y"，附技术理由`

### 9. op-implementer.md:50 FAIL 轮读 review.md——heavy 下无法执行
- 来源：sonnet, haiku（08_agents）
- 位置：agents/op-implementer.md:50
- 优先级：HIGH
- 详细判断理由：FAIL 轮流程第 1 步"读 review.md 正文 + git diff"。design §3.4 明确 implementer worktree 不挂 review.md，heavy 下物理上不存在该文件。lite 下无此问题。
- 修复说明：加 profile 分支。heavy：`读 leader dispatch prompt 中注入的 review 反馈摘要（review.md 不挂你的 worktree）`；lite：`读 review.md 正文`

### 10. op-evaluator.md 删除 `eval.md`，范围外发现统一进 `acceptance_report.md`
- 来源：current, opus, sonnet（08_agents）
- 位置：agents/op-evaluator.md:117（eval.md）vs :149（acceptance_report.md）
- 优先级：HIGH
- 详细判断理由：第 117 行让范围外发现写入 `eval.md`，第 149 行主报告写入 `acceptance_report.md`（模板已含范围外发现段）。但 closer 只读 `acceptance_report.md`，不知 `eval.md`。evaluator 若写 eval.md，closer 漏读范围外发现。两文件职责重叠。
- 修复说明：删除 `eval.md` 引用，agents/op-evaluator.md:117 改为 `写入 acceptance/{TID}/acceptance_report.md 的范围外发现段（草稿）`

### 11. op-evaluator.md DOM/a11y 硬门 → advisory（与自身第 125 行对齐）
- 来源：current（08_agents）
- 位置：agents/op-evaluator.md:41, 86
- 优先级：HIGH
- 详细判断理由：第 41 行写"结构化信号（DOM/a11y/网络响应）从 CDP 直接抓，进机械硬门"；第 86 行同列。但设计 D7 明确 DOM/a11y 降 advisory，第 125 行已写"DOM/a11y tree 降 advisory"。文件内部自相矛盾。
- 修复说明：第 41 行和第 86 行删除 DOM/a11y，改为"网络响应、stdout、DB/API、进程日志等可机械断言信号进硬门；DOM/a11y 仅作 advisory 锚点（design D7）"

### 12. op-evaluator.md e2e 输出路径 lite 默认 `docs/omni_powers/e2e/`
- 来源：current（08_agents）
- 位置：agents/op-evaluator.md:25, 27, 123, 160-164, 194-198
- 优先级：HIGH
- 详细判断理由：多处写固定 `e2e/{TID}/...`，但 design §5.3 明确 lite 默认写 `docs/omni_powers/e2e/`，用户显式同意才写顶层 `e2e/`。当前硬编码会在 lite 下污染用户项目顶层测试目录，违反零侵入边界。
- 修复说明：evaluator 输入约定中要求 leader 注入 `e2e_dir`；heavy 默认 `e2e/`，lite 默认 `docs/omni_powers/e2e/`；输出模板改为 `{E2E_DIR}/{TID}/...`

### 13. op-reviewer lite diff 改为 dispatch 锚点 sha
- 来源：current, haiku（08_agents）
- 位置：agents/op-reviewer.md:21, 65
- 优先级：HIGH
- 详细判断理由：lite 下要求 `git diff HEAD`，但 design §5.9 A19/A 明确 lite diff 锚定 dispatch 时记录的 sha，防 implementer 自行 commit 致 diff 空。`git diff HEAD` 在 implementer commit 后为空，review-package 整体失明。
- 修复说明：lite 分支改为 `git diff <dispatch_anchor_sha>` 或读取 leader 提供的 review-package；要求 dispatch prompt 注入锚点

### 14. 三执行 agent `op_script()` resolver 简化为 `$OP_HOME/scripts/` 直查
- 来源：haiku, opus, sonnet（08_agents）
- 位置：agents/op-implementer.md:9-12 / op-evaluator.md:11-13 / op-reviewer.md:9-11
- 优先级：MEDIUM
- 详细判断理由：当前 resolver 用 `ls ... | head -1` 遍历双路径，随后直接 `bash "$(op_script ...)"`。脚本统一到 `$OP_HOME/scripts/` 后，不再需要双路径遍历。但需保留前置探活：校验 `$OP_HOME` 非空且 `$OP_HOME/scripts/` 存在，找不到脚本输出 FATAL。
- 修复说明：resolver 改为 `[ -d "$OP_HOME/scripts" ] || { echo "FATAL: OP_HOME/scripts/ 不存在"; exit 1; }`，然后 `ls "$OP_HOME/scripts/$1" 2>/dev/null | head -1`，找不到 FATAL

### 15. opintake 中文状态值「待开始」→ `ready`
- 来源：current, haiku（09_skills_core）
- 位置：skills/opintake/SKILL.md:4-6, 84-86
- 优先级：HIGH
- 详细判断理由：opintake 写 `status=待开始`（中文），但 design §1.1 要求 tasks_list.status 机读值必须是 ASCII（`ready`）。按此执行会写入中文状态，op_jq.sh 按 ASCII 比较查不到 ready task，任务不可调度。
- 修复说明：skills/opintake/SKILL.md 中所有 tasks_list 状态写入改为 `status="ready"`（中文"待开始"仅允许在渲染说明中出现）

### 16. opspec `spec` 字段值改为路径格式
- 来源：current, haiku（09_skills_core）
- 位置：skills/opspec/SKILL.md:31-36
- 优先级：HIGH
- 详细判断理由：opspec 把 tasks_list 的 `spec` 字段描述成"值为 TID，如 `"T0001"`"。但 design §2.3 与 opintake 规定 spec 是相对路径 `specs/{TID}_{slug}.md`。按 TID 写入后 dispatch/review/evaluator 找 spec 时得到 TID 而非路径，读取失败。
- 修复说明：skills/opspec/SKILL.md:31-36 改为 `spec 字段写 specs/{TID}_{slug}.md`；TID 只放 `id` 字段

### 17. opinit_register_hooks.sh hook 重复注册去重
- 来源：current, haiku, opus, sonnet（09_skills_core 四模型共识）
- 位置：skills/opinit/scripts/opinit_register_hooks.sh:54-62
- 优先级：HIGH
- 详细判断理由：四份报告一致指出 `/opinit` 重跑时 jq 用 `+` 直接拼接已有 hooks 与模板 hooks，无去重。同一 hook 被重复注册多次执行，token 消耗指数增长。opinit_skeleton.sh 强调重跑幂等，但 hook 注册破坏幂等性。
- 修复说明：合并时按 `command` 字段去重（过滤已存在的同事件条目），重跑输出"已存在，跳过"而非追加

### 18. opinit_skeleton.sh checkpoint 注释删「跳过」
- 来源：current, haiku, sonnet（09_skills_core）
- 位置：skills/opinit/scripts/opinit_skeleton.sh:71
- 优先级：LOW
- 详细判断理由：模板注释写"完成/待开始/待规划/阻塞/跳过/挂起"，含已废弃的"跳过"状态。design §1.1 无 skipped（A16 已删），checkpoint 是 compact 恢复入口，残留会误导。
- 修复说明：注释改为"完成/待开始/待规划/阻塞/废弃/挂起"，对应 ASCII：done/ready/pending/blocked/obsolete/suspended

### 19. opstatus/optriage 命令块统一用 `$OP_HOME/scripts/`
- 来源：haiku, opus, sonnet（09_skills_core，与采纳项#1联动）
- 位置：skills/opstatus/SKILL.md:25-32 / skills/optriage/SKILL.md:10/84
- 优先级：MEDIUM
- 详细判断理由：此前 lite 无 `$OP_HOME` 所以需要用 fallback 变量；脚本统一后 lite 也有 `$OP_HOME`，直接写 `$OP_HOME/scripts/` 即可。optriage 还需补 profile 感知段。
- 修复说明：opstatus 命令块改为 `bash "$OP_HOME/scripts/op_jq.sh"`；optriage 参照 opstatus 加 profile 感知段（闸门 C 标 `heavy only`），命令统一用 `$OP_HOME/scripts/`

### 20. optriage TID 示例改为四位格式
- 来源：current, haiku（09_skills_core）
- 位置：skills/optriage/SKILL.md:69, 96-100
- 优先级：MEDIUM
- 详细判断理由：示例使用 `T06`/`T07`，但 design 规定 TID 固定四位宽度 `T0001`。短编号会导致解析、排序、归档路径混乱。
- 修复说明：所有示例统一为 `T0006`/`T0007`，生成规则明确 `T%04d`

### 21. optriage 步骤 4 命令语法修复
- 来源：haiku, opus, sonnet（09_skills_core）
- 位置：skills/optriage/SKILL.md:83-85
- 优先级：MEDIUM
- 详细判断理由：`bash "$OP_HOME/scripts/op_new_task.sh {TID}` 双引号未闭合 + markdown 围栏未闭合。leader 照抄会 shell 语法错误。
- 修复说明：改为 `bash "$OP_HOME/scripts/op_new_task.sh" "{TID}"` 并闭合 ``` 围栏

### 22. opred 删 review.md Fix-N 写入
- 来源：current, haiku（09_skills_core）
- 位置：skills/opred/SKILL.md:34-37
- 优先级：MEDIUM
- 详细判断理由：opred 写"implementer 改测试前必须在 report.md 的归因段（或 review.md 的 Fix-N 段）写明归因"。design 明确 review.md 单写者=leader，implementer 不能写 review.md。heavy 下会被 merge gate REJECT。
- 修复说明：删除"或 review.md 的 Fix-N 段"，统一为 report.md 归因段/Fix-N 段

### 23. opspec spec 模板补 `eval`/`eval_reason` 字段
- 来源：haiku（09_skills_core）
- 位置：skills/opspec/SKILL.md spec 模板 frontmatter
- 优先级：MEDIUM
- 详细判断理由：opintake task JSON 示例有 `eval`/`eval_reason` 字段（design §2.5 D9），但 opspec 的 spec 模板 frontmatter 缺少对应字段，spec 端无法表达免派意图。两处字段定义不对称。
- 修复说明：opspec spec 模板 frontmatter 补 `eval`/`eval_reason` 可选字段说明

### 24. opinit SKILL.md 设计章节引用 §3.3 → §1.3
- 来源：current, haiku, sonnet（09_skills_core）
- 位置：skills/opinit/SKILL.md:73
- 优先级：LOW
- 详细判断理由：blueprint-generator dispatch prompt 引用 `design §3.3`（机械护栏），但文档职责矩阵在 design §1.3。agent 按错误章节找会读到 hook/merge gate 内容。
- 修复说明：`§3.3` → `§1.3`

### 25. heavy/lite e2e 目录落点修正
- 来源：current, haiku（09_skills_core）+ 用户决策
- 位置：skills/opinit/scripts/opinit_skeleton.sh:29 / skills/oplinit/scripts/oplinit_skeleton.sh:33
- 优先级：HIGH
- 详细判断理由：heavy 无条件 `mkdir -p e2e`（用户项目顶层），lite 无条件 `mkdir -p docs/omni_powers/e2e/`。都应先问用户确认落点；默认路径需修正。
- 修复说明：
  - heavy：探测已有 e2e 目录，问用户确认落点，默认 `tests/e2e/`
  - lite：探测已有 e2e 目录，问用户确认落点，默认 `docs/omni_powers/e2e/`；同时在项目 CLAUDE.md 插入的说明段中注明 e2e 目录位置

### 26. heavy/lite 对项目 CLAUDE.md 的修改边界
- 来源：用户决策
- 位置：skills/opinit/SKILL.md / skills/oplinit/SKILL.md / design §4.1/§5.1
- 优先级：HIGH
- 详细判断理由：当前设计未明确两版对项目级 CLAUDE.md 的修改权限。heavy 需要引导 agent 走 omni 流程，应允许重构 CLAUDE.md（插入 omni 相关指引、目录说明、skill 入口等）；lite 零侵入，只允许在末尾插入一段说明（告知 omni 目录结构、e2e 目录位置、skill 入口），不能删除或重构原有内容。
- 修复说明：
  - design §4.1 补：heavy `/opinit` 可重构项目 `CLAUDE.md`
  - design §5.1 补：lite `/oplinit` 只允许在项目 `CLAUDE.md` 末尾插入一段说明段（`docs/omni_powers/` 目录用途 + e2e 落点 + `/oplintake`/`/oplrun`/`/opstatus` 入口），不删不改原有内容；用户拒绝则跳过
  - opinit/oplinit SKILL.md 步骤中体现对应行为

### 27. RULES.md lite 状态机分叉补 obsolete 声明
- 来源：haiku（01_core_rules）
- 位置：RULES.md:130-142（profile 分叉 lite 表格）
- 优先级：HIGH
- 详细判断理由：design §1.1 说状态枚举"两版统一"含 obsolete，但 RULES.md lite 分叉段只声明"删『收口中』态"，未声明 obsolete/suspended/blocked 是否保留。lite 用户废弃 task 时无法确认能否用 obsolete。
- 修复说明：lite 分叉表格补一行：「状态机 | heavy 全态（含 obsolete/suspended/blocked）；仅删『收口中』态」

### 28. design §5.6 lite 状态图补 obsolete 节点
- 来源：haiku（01_core_rules）
- 位置：design §5.6:832-838（lite 状态机图）
- 优先级：MEDIUM
- 详细判断理由：design §1.1 明确两版统一 9 态（含 obsolete），但 §5.6 lite 状态机图漏画 obsolete 节点。与采纳项#26 配套。
- 修复说明：§5.6 lite 状态机 ASCII 图补 `obsolete` 节点

### 29. op-evaluator.md lite 分支跳过读 `op_blueprint/specs/`
- 来源：current（08_agents）
- 位置：agents/op-evaluator.md:16-19, 83-85
- 优先级：MEDIUM
- 详细判断理由：lite 分支顶部声明无 op_blueprint、无 baselines，但步骤 1 第 2 项仍要求读 `op_blueprint/specs/{feature}.md`。lite evaluator 可能因文件不存在失败。
- 修复说明：lite 分支明确跳过"读生效规格"步骤；heavy 读 `op_blueprint/specs/`，lite 只读 eval brief 中的工作 spec

## 不采纳项

### 1. design §2.5 破坏检查 vs §3.1 refactor 断言冻结的张力
- 来源：haiku（01_core_rules）
- 位置：design §2.5/§3.1
- 优先级：HIGH（haiku 评定）
- 详细判断理由：破坏检查改断言期望验证能红，refactor 禁止改断言期望——haiku 认为两节有手段冲突。但破坏检查是"临时改后还原"的验证操作，不触 §3.1 的交付约束，这是设计共识。文档未交叉引用不构成缺陷——读者可自行推断临时性。

### 2. .gitignore 缺少编辑器/OS 临时文件排除
- 来源：sonnet, opus（01_core_rules）
- 位置：.gitignore
- 优先级：LOW
- 详细判断理由：建议补 `.DS_Store`/`*.swp`/`.idea/`。但 omni_powers 是工具仓库而非应用项目，贡献者少，临时文件误提交概率极低。属锦上添花，非必须。

### 3. superpowers.md/trellis.md 内部数据矛盾修正
- 来源：current, haiku, opus, sonnet（07_vendor_analysis_repos_d）
- 位置：vendor 分析文档多处（skill 计数、状态机、平台数）
- 优先级：HIGH（haiku 评定 3 项 HIGH）
- 详细判断理由：vendor 分析是第三方调研文档，不是 omni_powers 自身的规格/流程文件。内部数据矛盾影响调研质量，但修改需联网核实源仓库。审阅约束明确不联网、不读 vendor 源仓库，无法在不核实的情况下修改。且 vendor 分析文档不影响 omni_powers 运行正确性。

### 4. op-closer 赋 P 级与 design leader 赋 P 的张力
- 来源：current, haiku（08_agents）
- 位置：agents/op-closer.md:35-38
- 优先级：MEDIUM
- 详细判断理由：closer 给 issue 草稿赋 P1-P3，禁止赋 P0。haiku 认为 closer 不应独立赋 P。但 design §3.2 赋 P 协议链路是 reviewer→closer→leader/optriage，closer 作为 leader 收口代理赋 P1-P3 是合理分层——P0 已禁，P1-P3 有 leader 事后复核。不采纳。

### 5. op-implementer TDD 示例命令去前端化
- 来源：haiku（08_agents）
- 位置：agents/op-implementer.md:79
- 优先级：LOW
- 详细判断理由：`npm test -- path/to/test.test.ts` 偏前端。但 omni_powers 本身是 bash 项目，implementer 作为通用 agent 被派发到各类项目，示例命令只是示范格式。leader dispatch prompt 应覆盖具体测试命令。agent 文件中的示例改动价值极低。

### 6. op_decisions.md 早期决策折叠/移附录
- 来源：haiku（02_project_docs）
- 优先级：MEDIUM
- 详细判断理由：D1/D4/D5/D10 被取代决策占据前 100 行，可读性差。但 decisions.md 是 append-only 决策史，忠实于写出时间是其设计意图。折叠/移动会破坏原始时间线。头部已有术语演变映射。不采纳。

### 7. .gitattributes `*.cmd` LF → CRLF
- 来源：opus（01_core_rules）
- 优先级：LOW
- 详细判断理由：Windows CMD 解释器对 LF 敏感。但 omni_powers 的 `.cmd` 文件是 polyglot wrapper（hook 用），设计上已考虑跨平台，且项目主要在 WSL/macOS 运行。无实际故障报告。不采纳。

### 8. vendor 分析文档补"已知局限性"小节
- 来源：haiku（07_vendor_analysis_repos_d）
- 优先级：MEDIUM
- 详细判断理由：分析文档缺"已知局限"维度。但 vendor 分析是调研快照，不是正式需求文档。补充需深入理解两个 vendor 的边界，成本高收益低。不采纳。
