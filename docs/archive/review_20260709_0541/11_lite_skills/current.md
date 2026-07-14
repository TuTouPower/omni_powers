## 当前模型判断依据

可观测来源：`/home/karon/.claude/settings.json` 顶层 `model=haiku`；`env.ANTHROPIC_MODEL=default_model`；`ANTHROPIC_DEFAULT_HAIKU_MODEL=default_haiku[1m]`；`ANTHROPIC_DEFAULT_SONNET_MODEL=default_sonnet[1m]`；`ANTHROPIC_DEFAULT_OPUS_MODEL=default_opus[1m]`；主会话环境提示当前由 `default_model` 驱动。不能读取运行时内部状态；current 路继承主会话。

## 审阅范围

已按要求先完整阅读上下文文件：

- `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md`

本轮只审以下文件，排除 `vendors/` 与 `docs/archive/`：

- `/home/karon/karson_ubuntu/omni_powers/skills/oplinit/SKILL.md`
- `/home/karon/karson_ubuntu/omni_powers/skills/oplinit/scripts/op_check_env.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oplinit/scripts/oplinit_skeleton.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oplintake/SKILL.md`
- `/home/karon/karson_ubuntu/omni_powers/skills/oplintake/scripts/op_check_env.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/SKILL.md`
- `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/close_check.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/op_assemble_eval_brief.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/op_check_env.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/op_close_post.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/op_coder_check.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/op_collect_open_issues.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/op_jq.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/op_read_verdict.sh`
- `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/op_status.sh`

未跑构建、未跑测试、未联网；源文件只读。

## 高优先级问题（CRITICAL / HIGH）

### 1. spec 写保护命令只 WARN 不阻断，违背 A19 / §5.9 机械校验目标

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oplrun/SKILL.md:181-185`
- 现象：收口步骤中对 dispatch 后 `op_execution/specs/**` 变更只执行：
  - `git diff --quiet "$DISPATCH_SHA" -- docs/omni_powers/op_execution/specs/ || echo "[WARN] ..." >&2`
  - 命令无非 0 退出；后续继续 `git add -u`、`op_close_post.sh`、commit。
- 影响：lite 无 worktree / merge gate，spec 写保护是设计中补偿同源污染的关键机械防线。当前提示为 advisory，implementer 若改 spec 迎合实现，leader 可能在长流程中忽略 WARN 并归档提交。设计 §5.9 明确写“非零即停”；此处实际不会停。
- 建议：改成硬阻断，例如：
  - `git diff --quiet "$DISPATCH_SHA" -- docs/omni_powers/op_execution/specs/ || { echo "[FAIL] ..." >&2; exit 1; }`
  - 若需允许 spec-delta，必须要求 leader 先完成变更子流程，再重置 dispatch 锚点或显式记录豁免。
- 置信度：高
- 优先级：HIGH

### 2. 收口前 `git add -u` 会 stage 全仓已跟踪改动，可能把非本 task 改动混入 commit

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oplrun/SKILL.md:181-188`
- 现象：收口示例先执行 `git add -u`，范围是整个 repo 已跟踪文件；只对未跟踪的非 omni_powers 文件做 WARN。随后 `op_close_post.sh` 又只 add 部分归档路径，但不能撤销已被 `git add -u` stage 的其它已跟踪文件。
- 影响：lite 无 merge gate，收口边界靠 leader 亲验和脚本。全仓 `git add -u` 可把用户已有文件、前一 task 残留、evaluator 残留、无关已跟踪修改一并纳入 task commit，破坏 “task 即 commit” 与 “只动必须动” 边界。设计 §5.9 说“按实际 diff add”，但仍需先识别实际 diff 文件集并由 leader 确认，不应直接 stage 全仓。
- 建议：
  - 用 dispatch 锚点计算本 task 变更清单：`git diff --name-only "$DISPATCH_SHA"`，先展示并要求确认。
  - 至少限制 `git add -u -- <workset> docs/omni_powers/...`；对 workset 外已跟踪修改先 FAIL 或明确确认。
  - `op_close_post.sh` 内部已 stage 归档、progress、tasks_list；入口文档不应建议无范围 `git add -u`。
- 置信度：高
- 优先级：HIGH

### 3. `op_close_post.sh` 不 stage 归档后的 spec 与 acceptance，导致 close_check 通过但提交可能漏关键归档资产

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/op_close_post.sh:51-64,87-91`
- 现象：脚本会 `git mv`：
  - `op_execution/tasks/$TID` → `op_record/tasks/$TID`
  - `op_execution/specs/${TID}_*.md` → `op_record/specs/`
  - `op_execution/acceptance/$TID` → `op_record/acceptance/$TID`
  但最后只 `git add`：
  - `op_record/tasks/$TID`
  - `op_record/progress.md`
  - `op_execution/tasks_list.json`
  未显式 stage spec 归档、acceptance 归档、活区删除。
- 影响：若外层不靠全仓 `git add -u` 补齐，commit 可能只含 task report/review 归档和状态更新，漏掉已批准 spec 原文、eval brief/eval.md/e2e 草稿等验收资产归档。当前 `/oplrun` 文档用 `git add -u` 偶然掩盖该缺口，但那又引入全仓误 stage 风险。`close_check.sh` 也不检查 spec/acceptance 归档，漏提交不易被发现。
- 建议：在 `op_close_post.sh` 内用精确路径 stage 全部自身移动产物：
  - `docs/omni_powers/op_record/specs/$(basename "$SPEC_SRC")`
  - `docs/omni_powers/op_record/acceptance/$TID`
  - 原活区删除路径（可用 `git add -u -- docs/omni_powers/op_execution/specs docs/omni_powers/op_execution/acceptance docs/omni_powers/op_execution/tasks`）
  - 同时扩展 `close_check.sh` 检查 spec 与 acceptance 归档。
- 置信度：高
- 优先级：HIGH

### 4. `op_assemble_eval_brief.sh` 直接 cat 整份 spec，未剥离“设计探索结论/已知坑”，与隔离要求冲突

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/op_assemble_eval_brief.sh:31-33`
- 现象：brief 机械组装时直接 `cat "$WORK_SPEC"`。设计 §2.5 要求 eval brief “剥探索结论”；§5.7 也要求 lite 简化 brief “跳过基线/baselines 段 + 剥探索结论”。当前会把 spec 中“技术决策 / 设计探索结论 / 已知坑”等内容完整交给 evaluator。
- 影响：evaluator 期望应从 AC/INV/边界/可测性契约推导，而不是从实现路线、候选方案、已知坑中被暗示。lite 已无文件系统隔离，brief 再泄露探索结论，会进一步削弱独立验收，增加“按实现思路放水”或遗漏未提到失败模式的风险。
- 建议：组装时只保留：frontmatter、意图、INV、AC、边界与反例、不做、可测性契约、待澄清状态；过滤“技术决策”下的“设计探索结论/候选/推荐/已知坑”。若保留“条件强制”决策，需限定为接口/数据契约，不带方案探索过程。
- 置信度：高
- 优先级：HIGH

## 中低优先级问题（MEDIUM / LOW）

### 5. `/oplrun` 脚本根文档与设计中的共享脚本定位不一致，易导致 agent 脚本寻址失败

- 位置：
  - `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/SKILL.md:16-24`
  - `/home/karon/karson_ubuntu/omni_powers/skills/oplintake/SKILL.md:12-18`
  - 设计上下文 `/home/karon/karson_ubuntu/omni_powers/docs/omni_powers_design.md:801-825`
- 现象：`oplrun/SKILL.md` 要求：
  - `SCRIPTS="$SKILL_DIR/scripts"`
  - `OP_SCRIPT_ROOT="$SKILL_DIR"`
  - agent 内 `${OP_SCRIPT_ROOT:-$OP_HOME}` 走此。
  但 `oplintake/SKILL.md` 同时写 lite 会指向 install.sh 装的共享 scripts 目录 `~/.claude/scripts/omni_powers/`。设计 §5.5 又同时保留“共享目录目标”和“lite 副本暂保留待重构”的过渡说明。当前说明不统一。
- 影响：leader 或 agent 可能把 `OP_SCRIPT_ROOT` 注入为 skill 目录、共享脚本目录、或 OP_HOME。若 agent resolver 只查 `$root/scripts` / `$root/skills/oprun/scripts`，不同根会解析到不同副本甚至找不到脚本。lite 本身追求零侵入，但脚本副本/共享目录混用会制造版本漂移与排障成本。
- 建议：在三份 SKILL 中统一当前事实：若仍使用 per-skill 副本，则明确 `OP_SCRIPT_ROOT=<~/.claude/skills/oplrun>`；删除“共享 scripts 目录”表述或标为未来目标。若已迁到共享目录，则删除 `skills/oplrun/scripts` 副本并统一 resolver 示例。
- 置信度：中
- 优先级：MEDIUM

### 6. `op_jq.sh pending` 只筛 `ready`，未排除未完成依赖，不符合“选可跑 task”语义

- 位置：
  - `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/op_jq.sh:13-16`
  - `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/SKILL.md:61-68`
- 现象：`pending` 查询返回所有 `status=="ready"`，不判断 `depends_on` 是否全 done。`/oplrun` 文档要求“status=ready、depends_on 全 done、ID 最小”，但脚本没有提供一条可直接选择的“ready 且依赖满足”查询，只要求 leader 再对某 TID 调 `deps`。
- 影响：leader 手动循环时可能误选 ID 最小但依赖未完成的 ready task。设计明确下游保持 ready，调度器依 depends_on 不选中；脚本层未承接该不变量。
- 建议：新增 `runnable` 查询，由 jq 一次性筛选依赖全 done 的 ready task 并按 id 排序取第一个；将 SKILL 中 `pending` 改为 `runnable`。
- 置信度：高
- 优先级：MEDIUM

### 7. `depends_on: null` 与数组混用，增加 jq 查询与调度歧义

- 位置：
  - `/home/karon/karson_ubuntu/omni_powers/skills/oplintake/SKILL.md:79-89,92`
  - `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/op_jq.sh:21-31,48-50`
- 现象：`oplintake` 模板要求无依赖时 `depends_on: null`，有依赖时为数组。设计 §2.3 示例和语义更偏向数组字段。脚本部分用 `.depends_on[]?`、`.depends_on != null and index()` 兼容 null，但消费者需要持续记住双形态。
- 影响：后续脚本、agent prompt、人工编辑容易把 null / [] / 缺字段混用。调度、downstream、状态渲染出现边界 bug 可能性上升。
- 建议：统一为数组：无依赖写 `[]`。脚本可短期兼容 null，但文档模板改为 `depends_on: []`。
- 置信度：中
- 优先级：MEDIUM

### 8. `op_read_verdict.sh` 声称“末行读”，实际读取任意位置最后一个 verdict 行

- 位置：
  - `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/op_read_verdict.sh:7,21-22`
  - `/home/karon/karson_ubuntu/omni_powers/skills/oplrun/SKILL.md:131-134`
- 现象：脚本注释写 “verdict 从末行读”，reviewer prompt 也要求“末行必须 verdict”。但实现是 `grep -oE '^verdict:...' | tail -1`，即文件中最后一个匹配行，不验证它是文件末行。
- 影响：reviewer 若在 verdict 后追加说明，脚本仍 PASS；“末行 verdict”协议失去机械约束。轻则审计格式不一致，重则后续追加内容掩盖最新裁决上下文。
- 建议：用 `tail -n 1 "$REVIEW_FILE"` 解析并要求匹配 `^verdict:[[:space:]]*(PASS|FAIL)$`；若不是末行 verdict 则 FAIL。
- 置信度：高
- 优先级：MEDIUM

### 9. `op_close_post.sh` 归档 spec 使用 `ls | head -1`，多匹配时静默选第一个

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/op_close_post.sh:55-58`
- 现象：脚本按 `${TID}_*.md` 查 spec，`head -1` 静默取第一个。`op_assemble_eval_brief.sh` 也采用同模式。
- 影响：若误产生多个同 TID spec（例如重命名残留、大小写差异、复制文件），收口会归档其中一个，另一个留在活区；task:spec 1:1 不变量被破坏但脚本不报错。
- 建议：匹配结果计数必须等于 1；0 个 FAIL，多个 FAIL 并列出路径要求人工处理。
- 置信度：中
- 优先级：MEDIUM

### 10. `close_check.sh` 不检查 task status=done、spec/acceptance 归档与 commit stage 状态，收口验收覆盖不足

- 位置：`/home/karon/karson_ubuntu/omni_powers/skills/oplrun/scripts/close_check.sh:21-50`
- 现象：close_check 只检查 checkpoint 含 TID、归档 report/review 非空、git status 非本 task 残留仅 WARN。未检查：
  - `tasks_list.json` 中 TID 是否 `done`
  - spec 是否移入 `op_record/specs/`
  - acceptance 是否移入 `op_record/acceptance/`（eval required 时）
  - 是否存在 staged but uncommitted 改动或活区残留
- 影响：收口关键资产缺失时仍可能通过，尤其与问题 3 叠加，会让漏 stage / 漏归档在进入下个 task 前不被硬拦。
- 建议：补充 hard checks：task status=done；spec 归档唯一存在且活区不存在；eval required 时 acceptance 归档存在；`git diff --cached --name-only` 与 `git status --short` 输出需符合预期或至少对非预期 staged 改动 FAIL。
- 置信度：中
- 优先级：MEDIUM

### 11. `oplinit_skeleton.sh` 使用 `head` 但环境检查不校验 coreutils，极小概率影响可移植性

- 位置：
  - `/home/karon/karson_ubuntu/omni_powers/skills/oplinit/scripts/oplinit_skeleton.sh:17-18`
  - `/home/karon/karson_ubuntu/omni_powers/skills/oplinit/scripts/op_check_env.sh:18-19`
- 现象：环境检查只校验 jq/git，脚本使用 `head`、`tr`、`mkdir`、`printf` 等 POSIX 工具。常见 Linux/macOS/Git Bash 都有，但极简环境可能缺失。
- 影响：低。当前支持环境基本都内置，实际故障概率小。
- 建议：无需扩大检查清单；若要更稳，可避免 `head -1`，用 shell read：`IFS= read -r cur < "$PROFILE_FILE"`。
- 置信度：低
- 优先级：LOW

## 改进建议

1. 统一三份 `op_check_env.sh`
   - 三个 lite skill 下内容完全相同。当前过渡期副本可接受，但建议在报告/注释中明确来源与同步机制，或尽快收敛到共享脚本，避免 drift。

2. 为 lite 增加一个“收口预检”脚本
   - 将 `/oplrun/SKILL.md` 中分散的 spec diff、dirty tree、实际 diff 文件集、未跟踪文件、eval verdict、review verdict 检查收敛为脚本，减少 leader 手工漏步。

3. 明确 eval skip 的完整协议
   - `op_close_post.sh` 支持 `.eval == "skip"`，但 `/oplrun` 3.5 文档默认 review PASS 后进入 evaluator。建议在 3.5 前加分支：`eval=skip` 直接收口，并要求 reviewer/leader 验证 `eval_reason`。

4. 结束报告应显式引用 `op_collect_open_issues.sh`
   - 文件存在但 `/oplrun/SKILL.md` 相关文件表未列出，结束报告步骤也未给出调用命令。建议补：`bash "$SCRIPTS/op_collect_open_issues.sh"`。

5. 统一状态显示 ID 格式
   - `/oplrun/SKILL.md` 示例中混有 `T04`、`T05`，设计要求 `T0001` 四位宽度。建议示例统一，降低新用户照抄风险。

## 不确定项 / 可能误报

1. 关于 `git add -u` 的严重性
   - 若团队约定每次 `/oplrun` 前工作树必须完全干净，且 leader 严格检查 `git status --short`，误 stage 风险下降。但文档当前没有把“启动前 clean tree”作为硬前置，且 lite 无 merge gate，因此仍按 HIGH 处理。

2. 关于 `op_close_post.sh` 未 stage spec/acceptance
   - 外层 `/oplrun` 当前先执行 `git add -u`，会把移动删除纳入 index，可能掩盖脚本缺陷。但这依赖一个本身有高风险的外层命令。若修掉全仓 `git add -u`，该问题会立即显现。

3. 关于 eval brief 剥离探索结论
   - 如果产品意图是让 evaluator 知道“条件强制技术决策”以便验接口契约，不能简单删除整个“技术决策”段。建议做结构化过滤：保留契约性条件强制，剥离候选/推荐/已知坑等探索性内容。

4. 关于脚本根定位
   - 设计 §5.5 同时记录旧副本暂留与共享目录目标，当前代码可能处于迁移中。问题重点不是某一路径绝对错误，而是面向 leader/agent 的说明不统一，容易运行时分叉。
