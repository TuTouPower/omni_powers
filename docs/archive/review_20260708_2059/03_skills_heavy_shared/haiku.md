# haiku 审阅报告：heavy skills 分块

## 当前模型判断依据

可观测来源：session 顶层 model=default_haiku[1m]（powered by 标注）；env 未设 ANTHROPIC_MODEL，current 路继承主会话 default_haiku[1m]。本路为多模型审阅授权调用的 haiku 视角，禁写 secret，仅写本报告文件。

## 审阅范围

- skills/opinit/SKILL.md + scripts/opinit_register_hooks.sh + scripts/opinit_skeleton.sh
- skills/opintake/SKILL.md
- skills/oprun/SKILL.md + 7 个 scripts（close_check / op_assemble_eval_brief / op_checkpoint / op_close_post / op_close_pre / op_coder_check / op_read_verdict）
- skills/opspec/SKILL.md
- skills/opstatus/SKILL.md
- skills/opred/SKILL.md
- skills/optriage/SKILL.md

核心参考：docs/omni_powers_design.md（heavy 流程 §2、状态机 §1.1、权限 §2.6/§3.4、交付状态 §0.2/§4.2）。

---

## 高优先级问题

### H1. opstatus 与 optriage 仍用中文状态串，与 design §1.1 ASCII 机读铁律冲突
- **位置**：skills/opstatus/SKILL.md 步骤 3 渲染段（"完成/进行中/待开始/阻塞/废弃"）、步骤 4（"待规划/阻塞/废弃"）；skills/optriage/SKILL.md step 2-3（"status: 待开始/待规划"）。
- **现象**：design §1.1 明确要求 `tasks_list.json.status` 为 ASCII（pending/ready/in_progress/reviewing/closing/done/suspended/blocked/obsolete），"脚本/agent 不得自创状态串；脚本内 jq/grep 比较一律用左列 ASCII 值；opstatus 渲染层映射中文给人读"。但：
  - opstatus SKILL.md 步骤 3 直接渲染中文枚举（✅完成/🔄进行中/⏳待开始/🚫阻塞/⚫废弃），未声明"渲染层映射、机读仍 ASCII"。
  - optriage step 3 分配属性写 `status: 待开始` 或 `待规划`，直接把中文写进 tasks_list.json，违反机读 ASCII 铁律。
  - opstatus 步骤 2 `op_jq.sh pending/blocked/obsolete` 用的是 ASCII 参数，但渲染段与 optriage 写入段自相矛盾。
- **影响**：optriage 写入中文 status 会污染 tasks_list.json，后续 jq/grep 比较失败（脚本比较的是 ASCII），状态机判定错乱；跨平台 locale 风险（design 已点名 Windows Git Bash）。
- **建议**：optriage step 3 改写 `status: ready` / `pending`（ASCII），并在文档注明"渲染中文归 opstatus，写入一律 ASCII"；opstatus 步骤 3 加一行"渲染层映射：机读 ASCII → 中文显示"。
- **置信度**：高。
- **优先级**：HIGH。

### H2. opintake SKILL.md 示例 status 值与 spec 字段语义错乱
- **位置**：skills/opintake/SKILL.md 步骤四 tasks_list.json 示例（行 63-73）。
- **现象**：示例写 `"status": "待开始"`（中文，同 H1）+ `"spec": "T0001"`（只写 TID）+ `"type": "实现"`（中文且非 design 的 change type 枚举）。对照 design §2.3 task 元数据规范：`status: ready`（ASCII）、`spec: "specs/T0003_xxx.md"`（路径）或至少 TID 一致、type 应为 feat/fix/refactor/perf（§2.1 change type）。还多了一个 `type: "实现"` 字段不在 design schema 内。
- **影响**：opintake 是 task 落盘入口，示例错则 leader 照抄写错；spec 字段值"T0001"与 opspec SKILL.md「TID 编码」段（写进 tasks_list.json 的 `spec` 字段，值为 TID）自洽，但与 design §2.3 示例（`"spec": "specs/T0003_xxx.md"`）不一致——两处对 spec 字段值定义冲突（TID vs 路径）。
- **建议**：统一 spec 字段值定义（建议跟 design §2.3 用路径，或显式修订 design）；status 改 ASCII；删 `type: "实现"` 或改为 change type（feat/fix/...）并与 §2.1 对齐。
- **置信度**：高（status/type）、中（spec 字段语义——需 cross design 与 opspec 定夺）。
- **优先级**：HIGH。

### H3. op_checkpoint.sh 状态过滤用中文，与 design §1.1 ASCII 铁律冲突
- **位置**：skills/oprun/scripts/op_checkpoint.sh 行 31-36。
- **现象**：`select(.status == "完成")` / `"待开始"` / `"待规划"` / `"阻塞"` / `"跳过"` / `"挂起"`——全中文 jq 比较。design §1.1 明令"脚本内 jq/grep 比较一律用左列 ASCII 值"。同脚本行 21 grep `^- ${TID}` 是 checkpoint 内部格式（OK），但 status 比较段违规。
- **影响**：若 tasks_list.json 实际存 ASCII（按 design 与 opinit_skeleton 期望），这些 select 全部命中 0 条，checkpoint 状态段恒输出"无"，机械更新失效；若存中文（按 H1/H2 污染），又与 design 冲突。两难——脚本与 design 必有一处错。
- **建议**：改 ASCII（done/ready/pending/blocked/skipped/suspended）。同时核对 op_status.sh 实际写入值，保证读写一致。
- **置信度**：高。
- **优先级**：HIGH。

### H4. op_close_post.sh verdict 正则只匹配行首，与 review.md 追加写模式可能失配
- **位置**：skills/oprun/scripts/op_close_post.sh 行 37。
- **现象**：`grep -oE '^verdict:[[:space:]]*(PASS|FAIL)'`——要求 verdict 在行首。但 design §2.4/§3.4 规定 review.md"按追加写，每轮 verdict 追加，末行为最新"，reviewer 实际写入格式若为 `verdict: PASS`（行首）则 OK；若 reviewer 写 `- verdict: PASS` 或 markdown 列表项则失配。op_read_verdict.sh（行 22）同样 `^verdict:` 行首匹配。更关键：design §2.4 说 verdict 是"返回文本末行"由 leader 落盘，格式是 `verdict: PASS|FAIL`——两脚本假设一致，但无文档强约束 reviewer 写"行首 verdict:"。
- **影响**：reviewer 若末行带前缀（如 markdown），close_post 与 read_verdict 都读不到 verdict → die "review verdict 不存在" → 收口卡死。
- **建议**：在 reviewer agent 提示词或 opred/opspec 强约束末行格式为裸 `verdict: PASS|FAIL`（无前缀），并在两脚本注释引用该约束；或正则放宽为 `[[:space:]]*verdict:`。
- **置信度**：中（依赖 reviewer 实际输出格式，未读 agent.md 确认）。
- **优先级**：HIGH（收口阻断风险）。

### H5. op_assemble_eval_brief.sh 未剥 design §2.5 明令剥离的"设计探索结论/已知坑"段
- **位置**：skills/oprun/scripts/op_assemble_eval_brief.sh 行 33-36。
- **现象**：脚本直接 `cat "$WORK_SPEC"` 整文件塞进 brief。但 design §2.5 evaluator 访问隔离层第 2 点明确："eval_brief 机械组装（...**剥"设计探索结论/已知坑"段**...，不含 implementer 产物）"。design §2.4 dispatch 也有"剥探索结论"。工作 spec 模板（opspec SKILL.md）含「设计探索结论」段——整 cat 会把探索结论原样喂给 evaluator，违背访问隔离初衷（evaluator 看到 spec 推导过程容易被带偏）。
- **影响**：evaluator 访问隔离防线削弱——虽然 evaluator worktree 无 src（结构隔离仍在），但 brief 含探索结论会让 evaluator 沿 leader 推导路径思考，独立性受损。防"抄实现"靠结构（src 不在），防"抄思路"靠剥探索结论——后者失效。
- **建议**：cat 前 sed/awk 删掉工作 spec 的「### 设计探索结论」子段（到下一个 ### 或 ## 为止），保留条件强制 + 可测性契约。design §5.7 lite 形态也提"跳基线/baselines 段 + 剥探索结论"，heavy 应同样处理。
- **置信度**：高。
- **优先级**：HIGH。

---

## 中低优先级问题

### M1. opinit SKILL.md 步骤五 hook 注册描述与 register_hooks.sh 实际行为部分不符
- **位置**：skills/opinit/SKILL.md 步骤五（行 101-109）。
- **现象**：SKILL 说"合并 hooks 到项目 .claude/settings.json（按事件 concat，不覆盖用户已有 hooks，不碰 env）"，脚本 opinit_register_hooks.sh 实际还做了：①git 层 hooks 注册（.git/hooks/，pre-commit spec 写保护 + commit-msg e2e trailer，行 73-89）②Windows cygpath wrapper 改写（行 32-51）。SKILL.md 完全没提 git hooks 注册这件 heavy 专属大事（design §3.3 第 4 道 spec 写保护 / §2.5 e2e trailer 自锁的关键实现）。
- **影响**：用户/leader 读 SKILL 不知有 git 层 hooks，重跑 opinit 不知会同步更新 git hooks（脚本注释行 72"更新 omni_powers git hook 后需重跑 /opinit 同步"未进 SKILL）。
- **建议**：步骤五补一行说明"同时注册 git 层 hooks（pre-commit spec 写保护 + commit-msg e2e trailer 校验，绕过 subagent deny 失效，design §3.3）；更新 hook 后重跑 /opinit 同步"。
- **置信度**：高。
- **优先级**：MEDIUM。

### M2. opinit_skeleton.sh 建 e2e/ 但未探测用户已有顶层 e2e/
- **位置**：skills/opinit/scripts/opinit_skeleton.sh 行 29 `mkdir -p ... e2e`。
- **现象**：design §1 明确"**用户项目已有顶层 e2e/ 时 init 探测提示**（迁移子目录 / 显式豁免进保护 / 换路径），避免用户既有测试被锁"。skeleton.sh 无条件 `mkdir -p e2e`（-p 不报错但也不提示），opinit SKILL.md 步骤零浏览也没列"探测 e2e/"检查项。
- **影响**：用户已有 e2e/ 会被默默当作 omni_powers e2e/ 用，后续 merge gate / implementer worktree 排除规则会锁用户已有测试，与 design 意图相悖。
- **建议**：skeleton.sh 建前先 `[ -d e2e ]` 探测，存在则 echo WARN + die 让 leader 询问用户处置（迁移/豁免/换路径）；或 opinit SKILL 步骤零补探测命令。
- **置信度**：高。
- **优先级**：MEDIUM。

### M3. opinit_skeleton.sh 未建 config 文件（design §1 规划中但已声明）
- **位置**：skills/opinit/scripts/opinit_skeleton.sh 全文无 config。
- **现象**：design §1 目录结构含 `config`（OP_E2E_DIR 等项目级路径配置），虽标注"⚠️ 规划中——config parser 未落地，D4-B"，但 design 也说"init 时由用户定"。skeleton 无任何 config 占位或询问。属规划项尚未落地，脚本与 design 当前状态（未落地）一致，但 SKILL.md 步骤零也没"问 e2e 路径"环节（与 M2 关联）。
- **影响**：e2e/ 路径硬编码顶层，用户想自定义（如 docs/omni_powers/e2e/）无入口。当前 advisory（design 说未生效）。
- **建议**：D4-B 落地前，至少 opinit SKILL 步骤零询问 e2e 路径并记录到 checkpoint 或 decisions，为 parser 落地铺路；skeleton 建空 config 占位文件。
- **置信度**：中。
- **优先级**：MEDIUM（规划项，非阻塞）。

### M4. opintake SKILL.md 拆 task 示例缺 eval 字段（D9）
- **位置**：skills/opintake/SKILL.md 步骤四示例。
- **现象**：design §2.5 明确"task schema 字段 `eval: "required"|"skip"` + `eval_reason`，D9——oprun 机械判定免派"。opintake 拆 task 示例未含 eval 字段，导致 leader 照抄后 oprun 无机械判定依据（需临场判断，违背 D9"机械判定"意图）。
- **影响**：非行为型 task 免派 evaluator 的机制落不全——oprun 拿不到 eval 字段只能临场判断。
- **建议**：示例补 `"eval": "required"`（默认）+ 非行为型 task 标 `"skip"` + `"eval_reason": "..."`；或 opintake 步骤四补一段"判定 eval 字段"说明。
- **置信度**：中（design 说 D9，未确认 oprun 是否已读 tasks_list 的 eval 字段）。
- **优先级**：MEDIUM。

### M5. opintake SKILL.md spec 字段引用 tasks_list 与 design §2.3 不一致
- **位置**：skills/opintake/SKILL.md 步骤四示例 `"spec": "T0001"` vs design §2.3 `"spec": "specs/T0003_xxx.md"`。
- **现象**：同 H2 的 spec 字段语义部分。opintake 示例用 TID，design 用路径，opspec SKILL.md「TID 编码」段说"写进 tasks_list.json 的 `spec` 字段（值为 TID）"——opspec 与 opintake 一致用 TID，与 design 不一致。
- **影响**：三处文档对 spec 字段值定义不一致，实现时可能有的脚本按 TID 找、有的按路径找。
- **建议**：统一为一种（推荐 TID + 全局约定 spec 文件命名 `{TID}_{slug}.md` 可由 TID glob 出路径，op_assemble_eval_brief.sh 行 20 已用 glob 证明 TID 够用），修订 design §2.3 示例。
- **置信度**：高。
- **优先级**：MEDIUM。

### M6. oprun SKILL.md 步骤 1.1 worktree 模式描述与 P1 per-task 分支模型混杂
- **位置**：skills/oprun/SKILL.md 步骤 1.1（行 27-41）+ 收尾段（行 279-288）。
- **现象**：步骤 1.1 给用户三选一（worktree/主分支/当前分支），worktree 选项描述是"单 session 复用 .claude/worktrees/op-dev feat/op-dev"。但 design §3.4 P1 模型是 per-task 分支（`op/task/{TID}` 从主分支头切，每 task 一个），oprun 步骤 3.2 也隐含 per-task（dispatch implementer 用 task 分支）。收尾段行 283-285 注释"P0 整 session worktree 模型 / P1 per-task 分支模型"——两模型并存但步骤 1.1 只讲 P0 整 session worktree，P1 per-task 切分支环节在 SKILL 里没体现（谁切 op/task/{TID}？何时切？）。
- **影响**：P1 per-task 分支模型（design §3.4 核心安全机制）在 oprun SKILL 里是隐形的，leader 照 SKILL 跑可能漏切 task 分支、漏建 implementer worktree（op_worktree_setup.sh dev），merge gate 与 sparse-checkout 全失效。
- **建议**：步骤 1.1 或 3.2 补 per-task 分支切出 + implementer worktree 建立环节（design §3.4 步骤 1：leader 从主分支头创建 op/task/{TID} + implementer worktree）；明确 worktree 模式（整 session op-dev）与 per-task 分支模型的关系（前者 P0、后者 P1，当前交付 P1 应主讲 per-task）。
- **置信度**：中（design §0.2 标 P1 未落地，当前 P0，但 SKILL 应前瞻或明确标 P0/P1 差异）。
- **优先级**：MEDIUM。

### M7. op_coder_check.sh 与 op_read_verdict.sh 轮次定义注释口径不一
- **位置**：op_coder_check.sh 行 6 注释"review ≤ 2 轮（第 3 轮 → blocked）"；op_read_verdict.sh 行 7 无轮次上限注释。
- **现象**：两脚本都用 `grep -c '^verdict:'` 数轮次，coder_check 行 25 `next_round > 2 → blocked` 正确实现"两轮到顶"。但 design §2.4 review 循环上限说"最多两轮"，语义是"review→fix→re-review 为一轮；两轮修不平→blocked"。脚本把"verdict 行数 = 轮次"，第 1 轮 verdict 后 next_round=2（fail 模式），第 2 轮 verdict 后 next_round=3 > 2 → blocked——即允许 2 次 review verdict，符合 design。但注释"第 3 轮 → blocked"易误读为"允许跑到第 3 轮"。
- **影响**：注释歧义，实现正确但易在维护时被误改。
- **建议**：注释改为"已有 2 个 verdict（两轮到顶）→ 第 3 次派 implementer 前 blocked"。
- **置信度**：高。
- **优先级**：LOW。

### M8. close_check.sh 第 3 项 git status grep 正则宽松
- **位置**：close_check.sh 行 43。
- **现象**：`grep -v "^[MADRC? ]\+ ${arch}"`——`${arch}` 含 TID，但 git status --short 输出格式是 `XY path`，path 可能带引号或相对路径前缀。正则用 `${arch}`（绝对归档路径）匹配 git status 的相对路径输出，大概率全部不匹配 → others 变量非空 → 永远 WARN。
- **影响**：warn 恒 1，提醒失效（狼来了）。
- **建议**：用 `git status --short -- docs/omni_powers/op_record/tasks/$TID` 反向过滤，或用 git diff 名单比对。
- **置信度**：中（未实测 git status 输出格式）。
- **优先级**：LOW。

### M9. opstatus SKILL.md 缺 obsolete/suspended 渲染与 issues P0/P1 列表来源
- **位置**：skills/opstatus/SKILL.md 步骤 3 渲染格式。
- **现象**：渲染示例有 ⚫废弃 🚫阻塞，但缺 suspended（挂起）态显示；"issues == open issue 计数 + P0/P1 列表"未给 jq 命令（issues 不是 tasks_list.json 字段，是 issues/ 目录文件，需另扫）。步骤 2 `op_jq.sh all/pending/blocked/obsolete` 也没 suspended/ready/in_progress/reviewing/closing 子命令。
- **影响**：opstatus 渲染不全，挂起态 task 不可见；issues 段无操作指引。
- **建议**：渲染段补 suspended；步骤 2 补全状态子命令或统一用 `op_jq.sh all` 后过滤；issues 段补 `ls issues/*.md | jq parse frontmatter severity` 示例。
- **置信度**：高。
- **优先级**：LOW。

### M10. optriage SKILL.md 转 task 后 op_new_task.sh 调用语法疑似错误
- **位置**：skills/optriage/SKILL.md step 3 行 84。
- **现象**：写 `bash "$OP_HOME/scripts/op_new_task.sh {TID}`——①缺右引号 `"` ②未传 issue 上下文 ③step 3 已说"用 jq 追加到 tasks_list.json"（行 80），紧接着又调 op_new_task.sh，两步关系不清（op_new_task.sh 是否就是 jq 追加的封装？）。
- **影响**：leader 照抄执行语法错误（缺引号 bash 报错）；语义混淆。
- **建议**：修引号；明确 op_new_task.sh 职责（是建工作区还是写 tasks_list），与 jq 追加减重。
- **置信度**：高。
- **优先级**：LOW。

### M11. opred SKILL.md 锁定文件解锁流程引用 test_lock.sh，design 未定义该脚本
- **位置**：opred SKILL.md「锁定文件解锁」步骤 3 `scripts/test_lock.sh remove <file>`。
- **现象**：design §4.1 scripts 清单无 test_lock.sh（有 op_worktree_setup/op_merge_gate/op_close_pre/post 等）。opinit_skeleton.sh 建 `.test_locks` 文件（行 76-79），但无对应管理脚本。opred 引用的 test_lock.sh 可能在别处或未实现。
- **影响**：解锁步骤无法执行（脚本缺失），锁定机制空转。
- **建议**：确认 test_lock.sh 是否存在（未在本次审阅范围的全局 scripts/）；若未实现，opred 应标注"待 D12/P1 落地"或改用 leader 手动 git 解锁描述。
- **置信度**：中（未读全局 scripts/ 目录确认）。
- **优先级**：LOW（advisory，锁定主要靠 merge gate）。

---

## 改进建议（跨文件）

1. **状态串统一 ASCII**：H1/H2/H3 三处（opstatus/opintake/op_checkpoint）一致违规，根因是 design §1.1 铁律未被 skill/脚本内化。建议跑一次全仓 grep 中文状态串（完成/待开始/待规划/阻塞/跳过/挂起/废弃/收口中/进行中/审阅中），逐处定 ASCII + 渲染层映射。这是状态机正确性的基础。

2. **spec 字段值统一**：H2/M5 design vs opspec/opintake 三处冲突，建议一次裁决（TID 还是路径），修订 design 或两个 skill。TID 更轻（glob 出路径），推荐 TID。

3. **eval 字段（D9）补全**：M4 opintake 拆 task 示例补 eval 字段，让 oprun 机械判定非行为型 task 免派有依据。

4. **verdict 格式强约束**：H4 op_close_post/op_read_verdict 假设行首裸 verdict，建议在 op-reviewer agent 提示词与 opspec/opred 文档双重约束末行格式，脚本注释引用该约束。

5. **eval_brief 剥探索结论**：H5 op_assemble_eval_brief.sh 加 sed 删工作 spec 的「设计探索结论」子段，落实 design §2.5 访问隔离。

6. **opinit 探测 e2e/ + 补 git hooks 说明**：M1/M2 opinit SKILL 步骤零补 e2e/ 探测、步骤五补 git hooks 注册说明。

---

## 不确定项

1. **reviewer 实际 verdict 写入格式**（H4）：未读 agents/op-reviewer.md，无法确认末行是否裸 `verdict: PASS|FAIL`。若 agent 已强约束，H4 降级为 LOW（仅脚本正则健壮性建议）。

2. **op_status.sh 实际写入值**（H3）：未读 scripts/op_status.sh，无法确认它写中文还是 ASCII。若它写 ASCII，则 op_checkpoint.sh 的中文比较恒失效（更严重）；若写中文，则与 design 冲突且 opstatus 渲染一致但跨平台风险。需读 op_status.sh 定夺。

3. **op_new_task.sh 职责**（M10）：未读该脚本，不知是建工作区还是写 tasks_list。影响 optriage step 3 流程正确性判断。

4. **test_lock.sh 是否存在**（M11）：未读全局 scripts/ 目录，不确定 opred 引用的脚本是否落地。

5. **per-task 分支模型当前是否启用**（M6）：design §0.2 标 merge gate 为 P1 未落地，但 op_assemble_eval_brief.sh / op_close_post.sh 等脚本已就位。当前 P0 还是 P1 运行态影响 oprun SKILL 步骤 1.1/3.2 是否需主讲 per-task 分支——需读 RULES.md 或实际 tasks_list 确认运行态。

6. **tasks_list.json 实际 status 值**（H1/H2/H3 根因确认）：未读实际项目的 tasks_list.json 样本，无法确认线上数据是中文还是 ASCII。若历史数据已中文，修订需带迁移脚本。
