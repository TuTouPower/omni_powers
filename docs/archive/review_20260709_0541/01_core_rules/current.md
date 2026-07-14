## 当前模型判断依据

可观测来源：`/home/karon/.claude/settings.json` 顶层 `model` 为 `haiku`；同文件 `env.ANTHROPIC_MODEL` 为 `default_model`；`env.ANTHROPIC_DEFAULT_HAIKU_MODEL` 为 `default_haiku[1m]`；`env.ANTHROPIC_DEFAULT_SONNET_MODEL` 为 `default_sonnet[1m]`；`env.ANTHROPIC_DEFAULT_OPUS_MODEL` 为 `default_opus[1m]`；主会话环境提示显示当前由 `default_model` 驱动。不能读取运行时内部状态，因此只能判断：current 路不设置 model 字段时继承主会话；主会话可见模型标识为 `default_model`，配置默认模型字段显示 `haiku`。

## 审阅范围

本轮只读审阅以下文件，排除 `vendors/` 与 `docs/archive/`：

- `/home/karon/karson_ubuntu/omni_powers/.gitattributes`
- `/home/karon/karson_ubuntu/omni_powers/.gitignore`
- `/home/karon/karson_ubuntu/omni_powers/CLAUDE.md`
- `/home/karon/karson_ubuntu/omni_powers/RULES.md`
- `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md`

未运行构建、测试、联网命令；仅创建并写入本报告文件。

## 高优先级问题（CRITICAL / HIGH）

### HIGH 1. lite 模式验收与 commit 顺序在三处互相矛盾，可能导致未验收代码先入库

- 位置：
  - `/home/karon/karson_ubuntu/omni_powers/CLAUDE.md:33`
  - `/home/karon/karson_ubuntu/omni_powers/RULES.md:135-136`
  - `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md:853-865`
- 现象：
  - `CLAUDE.md:33` 写 lite 流程为 `implementer → leader 自验 → reviewer → 收口 → per-task 裸评 → P0 检查 → 归档`。
  - `RULES.md:136` 写 lite 收口为 `review PASS → git add workset + commit → per-task 裸评 → P0 检查 → 归档`。
  - `omni_powers_design.md:863-865` 明确写 `验收前置，D6——先验 PASS 才 commit`，即 reviewer PASS 后先 evaluator 裸评，PASS 后才 leader 收口 commit + 归档。
- 影响：运行时入口文档和项目说明会引导 leader 在 evaluator 验收前提交代码，破坏 lite 模式“先验 PASS 才 commit”安全目标；若 evaluator 后续 FAIL，已提交状态、task 状态、归档时序会混乱。
- 建议：统一为设计档 §5.6 当前更安全路径：`review PASS → evaluator per-task 裸评 → PASS → leader 收口（git add 实际 diff + commit + 归档）→ P0 汇总/结束报告`。同步修改 `CLAUDE.md` 快速开始、`RULES.md` lite 分叉表、状态机 done 定义。
- 置信度：高
- 优先级：HIGH

### HIGH 2. RULES.md 的通用环境入口要求强制 `$OP_HOME`，与 lite “无 OP_HOME”设计冲突

- 位置：
  - `/home/karon/karson_ubuntu/omni_powers/RULES.md:112`
  - `/home/karon/karson_ubuntu/omni_powers/RULES.md:134,142`
  - `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md:777-799`
- 现象：`RULES.md:112` 把“任何 skill/agent 入口先跑 `bash "$OP_HOME/scripts/op_check_env.sh"`”列为跨 agent 铁律；但 lite 分叉和设计档明确 lite 无 `$OP_HOME`，应靠 `${OP_SCRIPT_ROOT:-$OP_HOME}` fallback 与 `OP_SCRIPT_ROOT` 注入。
- 影响：lite agent/skill 若严格执行 `RULES.md:112`，会在未设置 OP_HOME 时直接失败；即使后续 lite 分叉写了 fallback，也与“跨 agent 铁律”冲突，恢复/派发时容易按错误入口执行。
- 建议：把 `RULES.md:112` 改成 profile-aware 规则：先解析 `docs/omni_powers/profile`；heavy 跑 `$OP_HOME/scripts/op_check_env.sh`；lite 跑 `${OP_SCRIPT_ROOT:-$OP_HOME}` resolver 找到的 `op_check_env.sh`，且不要求 OP_HOME。
- 置信度：高
- 优先级：HIGH

### HIGH 3. lite 脚本“已共享目录消灭副本”与“副本暂保留待重构”在同一节冲突

- 位置：
  - `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md:801-805`
  - `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md:823-824`
  - `/home/karon/karson_ubuntu/omni_powers/CLAUDE.md:36,46,67`
  - `/home/karon/karson_ubuntu/omni_powers/RULES.md:142`
- 现象：设计档 §5.5 开头写 install.sh 已装 `~/.claude/scripts/omni_powers/`，lite skill 不再各自带 `scripts/` 副本，消灭 per-skill 副本同步机制；但同节末尾又写 lite 副本 `skills/oplrun/scripts/` 暂保留，完整归并待重构，`build_lite.sh` 暂留维护副本同步。`CLAUDE.md` 仍称 `scripts/build_lite.sh` 是 lite 副本漂移校验，`oplrun` 脚本自包含；`RULES.md:142` 也指向 `~/.claude/skills/oplrun/scripts`。
- 影响：安装、派发、compact 恢复时到底使用共享脚本还是 skill 内副本不清晰；若两处脚本漂移，leader/agent 可能读不同版本，尤其 `op_status.sh`、`op_assemble_eval_brief.sh`、`op_close_post.sh` 这类状态关键脚本会造成运行状态不一致。
- 建议：明确当前事实状态，只保留一种表述。若副本仍存在并被使用，则 §5.5 开头改为“目标方案/规划中”；若共享目录已生效，则删除 `build_lite.sh` 副本维护叙述，并把 `RULES.md:142`、`CLAUDE.md:36/46/67` 全部改为共享脚本路径。
- 置信度：高
- 优先级：HIGH

### HIGH 4. op-implementer 是否能读 tasks_list.json / 自行 jq 在设计档内前后冲突

- 位置：
  - `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md:128-129`
  - `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md:323`
  - `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md:626`
  - `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md:671-673`
- 现象：设计档多处写 `tasks_list.json` 不挂给 implementer worktree，workset/depends_on 由 dispatch 脚本提取注入，agent 不自行 jq；但插件结构表又写 `op-implementer 读 spec + jq tasks_list 元数据`。
- 影响：agent 角色说明可能引导 implementer 在隔离 worktree 中读取不存在或不应读取的 `tasks_list.json`，破坏“流程文件只在主 worktree 单副本”设计；失败时会表现为环境错误，成功绕读时又破坏隔离边界。
- 建议：把 `omni_powers_design.md:671-673` 改为“读 spec + dispatch 注入的 tasks_list 元数据（workset/depends_on），不自行 jq tasks_list”。同步检查 agent 文档是否仍有“jq tasks_list”表述。
- 置信度：高
- 优先级：HIGH

## 中低优先级问题（MEDIUM / LOW）

### MEDIUM 1. heavy per-task squash-merge 与最终 Stage 5 merge 语义重复，容易误解为两次 merge

- 位置：
  - `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md:193`
  - `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md:203`
  - `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md:538-542`
  - `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md:638`
- 现象：Stage 3 已写验收 PASS 后 `squash-merge 回主分支`，§3.4 也写 per-task `git merge --squash op/task/{TID}`；但 Stage 5 又写“全部 task 闭环 → Stage 5 merge：系统层夜跑回归全过 → merge”。
- 影响：读者无法判断 Stage 5 的 merge 是合入主分支、发布分支合并、还是仅系统层验证后结束；若按字面执行，可能重复 merge 或在所有 task 完成前后出现两套合入协议。
- 建议：把 Stage 5 改名为“系统层回归 / 发布前验证”，若确有最终集成分支合并，补充目标分支和与 per-task squash-merge 的关系。
- 置信度：高
- 优先级：MEDIUM

### MEDIUM 2. RULES.md 仍保留 `skipped` 查询命令，但设计已明确不设 skipped 态

- 位置：
  - `/home/karon/karson_ubuntu/omni_powers/RULES.md:51-56`
  - `/home/karon/karson_ubuntu/omni_powers/RULES.md:92-100`
  - `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md:832-837`
- 现象：`RULES.md` 下游传播段明确“不设 skipped 态”，但 compact 恢复命令示例仍列 `bash $OP_HOME/scripts/op_jq.sh skipped`。
- 影响：compact 恢复或排障时可能调用已废弃 query；若脚本已删除该分支会报错，若脚本保留旧分支则会传播过时状态模型。
- 建议：删除 `op_jq.sh skipped` 示例；如需要看“被阻塞下游”，新增明确 query 名，例如 `blocked_downstream`，并说明它是派生视图而非 task status。
- 置信度：高
- 优先级：MEDIUM

### MEDIUM 3. RULES.md 回滚示例使用中文状态值，违反 ASCII 状态枚举

- 位置：
  - `/home/karon/karson_ubuntu/omni_powers/RULES.md:66-69`
  - `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md:133-147`
- 现象：设计档要求 `tasks_list.json.status` 机读值必须用 ASCII（如 `ready`），脚本/agent 不得自创状态串；但 `RULES.md:67` 示例为 `bash $OP_HOME/scripts/op_status.sh {TID} 待开始`。
- 影响：照抄命令可能写入非法状态或被脚本拒绝；若脚本未校验，会污染 tasks_list 状态机。
- 建议：改为 `bash $OP_HOME/scripts/op_status.sh {TID} ready`，并注明中文只在 opstatus 渲染层出现。
- 置信度：高
- 优先级：MEDIUM

### MEDIUM 4. CLAUDE.md 对 heavy 能力表述过满，未提示 merge gate / 系统夜跑仍有阶段性未落地项

- 位置：
  - `/home/karon/karson_ubuntu/omni_powers/CLAUDE.md:5,19-25,36`
  - `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md:39-58`
  - `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md:612`
- 现象：`CLAUDE.md` 面向用户描述 heavy 为“task 分支 + merge gate + worktree 隔离 + blueprint”，快速开始也把 `/oprun` 描述为完整链路；设计档能力矩阵和 §3.4 则标出部分能力为 P1/P2/P3 或“当前未落地”。
- 影响：用户可能误以为 heavy 当前已具备全部硬防线，忽略过渡期风险；尤其 merge gate 是安全模型核心，如果未落地却被 README 式入口文档当成既有能力，会误导使用决策。
- 建议：`CLAUDE.md` 增加“能力状态以设计档 §0.2 为准；部分防线按阶段交付”一句；快速开始避免把未落地能力写成无条件已可用。
- 置信度：中
- 优先级：MEDIUM

### MEDIUM 5. lite “零侵入/脚本自包含”表述与共享脚本安装模型冲突

- 位置：
  - `/home/karon/karson_ubuntu/omni_powers/CLAUDE.md:31-36`
  - `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md:760-776`
  - `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md:801-805`
- 现象：`CLAUDE.md` 写 lite “脚本自包含”，且 “不改用户配置与已有文档”；设计档写 install.sh 会全局安装 `~/.claude/scripts/omni_powers/` 供 lite 固定路径引用。零侵入边界虽解释“全局 ~/.claude 一次性安装不算侵入”，但“脚本自包含”与共享脚本目录不是同一概念。
- 影响：用户排障时会去 `skills/oplrun/scripts/` 找脚本，或误以为 lite 不依赖全局共享脚本目录；安装缺失时错误定位困难。
- 建议：把 `CLAUDE.md:36` 改为“lite 不加 hook；脚本通过全局共享目录/当前保留副本（按实际状态）寻址”，避免“自包含”模糊词。
- 置信度：高
- 优先级：MEDIUM

### MEDIUM 6. RULES.md lite compact 恢复脚本路径与设计档目标路径不一致

- 位置：
  - `/home/karon/karson_ubuntu/omni_powers/RULES.md:142`
  - `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md:801-805,823-824`
- 现象：`RULES.md:142` 指 `$SCRIPTS = oplrun skill 安装目录下的 scripts 子目录，如 ~/.claude/skills/oplrun/scripts`；设计档主叙述称 lite 应指向 `~/.claude/scripts/omni_powers/` 共享脚本目录，但后文又说副本暂留。
- 影响：compact 恢复是高频入口，路径错会直接导致恢复失败或跑到旧副本。
- 建议：在脚本共享状态定稿后同步 `RULES.md:142`；若过渡期双路径并存，写成 resolver 规则，不写死单一路径。
- 置信度：高
- 优先级：MEDIUM

### LOW 1. RULES.md 中 closer 权限引用章节号过期

- 位置：
  - `/home/karon/karson_ubuntu/omni_powers/RULES.md:147`
  - `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md:482-500`
- 现象：`RULES.md:147` 写 “op-closer per-task 权限红线（design §2.4，一段式）”；实际 closer 一段式收口在设计档 §2.6。
- 影响：读者跳转错误，维护时可能误改 review 循环段而非 closer 段。
- 建议：改为 `design §2.6`。
- 置信度：高
- 优先级：LOW

### LOW 2. .gitignore 忽略 `docs/review_*`，可能让审阅报告默认不入版本库

- 位置：
  - `/home/karon/karson_ubuntu/omni_powers/.gitignore:2`
- 现象：`.gitignore` 忽略所有 `docs/review_*`，本次指定报告路径也被该规则覆盖。
- 影响：若审阅报告预期归档进 repo，需要 `git add -f`；若只作临时审阅产物则无问题。
- 建议：确认审阅报告生命周期。若报告需长期归档，改为忽略更窄临时目录或在流程文档提示 `git add -f docs/review_*`。
- 置信度：中
- 优先级：LOW

## 改进建议

1. 建立“运行时文档一致性检查”清单：状态枚举、lite/heavy 分叉、脚本根路径、commit/验收顺序、agent 可读写路径，作为每次改设计档后的必查项。
2. 在 `CLAUDE.md` 只放用户入口与能力概览，所有“当前是否落地”的事实统一指向 `docs/omni_powers_design.md` §0.2，避免 README 式文档承诺过满。
3. 对 lite 当前脚本寻址做一次决策收口：共享目录已生效、skill 副本过渡、还是完全自包含三选一；不要在同一文档同时保留目标态与现状态而不标注。
4. 把 `RULES.md` 中所有命令示例改为 ASCII 状态值，并补一条“中文只用于渲染，不得传给脚本”。
5. 给 `op_jq.sh` query 名称与 task status 枚举做文档同源生成或最小校验，防 `skipped` 这类废弃 query 残留。

## 不确定项 / 可能误报

1. `docs/omni_powers_design.md:823-824` 可能是在记录过渡期现状，而 `801-805` 是目标方案；但文档未显式标“目标态/当前态”，按运行手册审阅视角仍构成高风险歧义。
2. `CLAUDE.md` 对 heavy 能力描述可能是产品目标而非当前实现；但快速开始区域面向用户，缺少“按 §0.2 查看落地状态”提示，仍可能误导。
3. `.gitignore` 忽略审阅报告可能是刻意设计，避免临时多模型审阅产物入库；仅在报告需要版本化时才是问题。