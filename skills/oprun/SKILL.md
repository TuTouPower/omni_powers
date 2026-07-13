---
name: oprun
description: >
  从 checkpoint 续跑：task 循环（review → per-task 验收 → merge → closer 收尾 → leader 自审写入 → 归档）。一次 oprun 结束生成事后报告（A18，无用户事中审批）。
  触发：/oprun、继续、下一步、干活。
  controller 即 leader 主会话，被本 skill 驱动。
---

# Op Run Skill

> **运行前检查环境**：`bash "$OP_HOME/scripts/op_check_env.sh"`（jq/git/OP_HOME，缺失 die + 装法）

`/oprun` 从 checkpoint 续跑待开始的 task。leader 查状态、派 implementer、review、收口，自动推进。

协议规则、状态机、review 判定等见 `RULES.md`。spec 编写见 `opintake`。

## 派发模型规则

派发 Sub Agent 时，Agent 工具的 `model` 参数按以下规则传：

1. 读对应环境变量（`OP_IMPLEMENTER_MODEL` / `OP_REVIEWER_MODEL` / `OP_EVALUATOR_MODEL` / `OP_CLOSER_MODEL`）
2. **设了** → `model` 参数传该值（必须是 `haiku`/`sonnet`/`opus` 之一，对应 settings.json 的 `ANTHROPIC_DEFAULT_*_MODEL`）
3. **没设** → `model` 参数**不传**，Agent 继承主会话当前模型（用户可用 `/model` 随时切换）

下面派发示例的 `model:` 行注明"按规则传"——leader 据上述规则决定传不传、传什么。设计 task（dispatch prompt 指明"只产方案纸"）也不得临时覆盖模型；需要更强模型时由用户通过 `/model` 或 OP_*_MODEL 配置决定。

若 Agent model 拦截 hook deny 显式 `model`，对应 `OP_*_MODEL` 用户项目配置即构成授权依据。重派时在 dispatch prompt 首行加入顶层 marker：`model_override_authorized: OP_*_MODEL 项目级配置`。marker 必须是 prompt/description 顶层行，不得放进代码块。相同参数被 deny 后禁止盲重试；必须修改参数，或补上该授权 marker 后再派发。

## 步骤一：确认工作目录 + 读状态

### 1.1 确认工作目录

```bash
git branch -r | grep -E 'origin/(main|master)$' || git branch -r | head -1
```

问用户：worktree（推荐）/ 主分支 / 当前分支。

- **worktree**：`bash "$OP_HOME/scripts/op_worktree_setup.sh" dev .claude/worktrees/op-dev feat/op-dev` → `cd .claude/worktrees/op-dev`（sparse-checkout 自动排除 `e2e/`，行为层隔离；单 session 复用；结束时按收尾段清理；若目录/分支已存在，先让用户选择复用或另取名，勿强删）
- **主分支**：`git checkout {main或master}` 后，派 implementer 前创建并切到临时 task 分支（如 `op/task/{TID}`）；实现改动不得直接落主分支
- **当前分支**：若当前分支是主分支，按“主分支”规则先创建并切到临时 task 分支；否则保持当前 task/feature 分支
- 记下 `<work_dir>` = 当前 `pwd` + 原分支名

### 1.2 读状态

```bash
# profile 互斥：lite 项目禁走 heavy 入口（无 profile 文件 = 旧 heavy 项目，放行）
if [ -f docs/omni_powers/profile ] && ! grep -qx heavy docs/omni_powers/profile; then
    echo "[FAIL] profile≠heavy——lite 项目请用 /oplrun，不混跑" >&2; false
fi
cat docs/omni_powers/op_execution/leader_checkpoint.md
jq '[.tasks[] | {id, status, depends_on}]' docs/omni_powers/op_execution/tasks_list.json
cat RULES.md
```

> 上面互斥检查若 FAIL（命令非 0），**立即停**，不进循环。

### 状态判定

| 条件 | 动作 |
|---|---|
| 全部 status=done | 循环结束，进入收尾 |
| 存在 status=closing | 从 checkpoint 恢复，跳到收口子步骤 |
| 存在 status=reviewing | 进入循环，先检查 review 是否完成（读 verdict） |
| 存在 status=in_progress | 进入循环，先检查 implementer 是否完成（读 `tasks/{TID}/report.md` 顶部总报告状态） |
| 存在可跑 task | 进入循环 |
| 存在 status=pending | 提醒：用 `/opintake` 生成 spec |
| 全部 blocked/suspended/obsolete | 输出原因，等外部解除或用户修改状态 |

### 1.3 approved spec 漂移复查（SessionStart 职责挪入，design §3.3 第 4 道）

启动时（读状态后、task 循环前）跑 approved spec 漂移复查——扫 `op_blueprint/specs/*.md` status=approved/in_progress 的 spec，有未 commit 改动则 WARN 走变更子流程（§2.4）：

```bash
if [ -d "docs/omni_powers/op_blueprint/specs" ]; then
  for spec in docs/omni_powers/op_blueprint/specs/*.md; do
    [ -f "$spec" ] || continue
    st="$(awk -F': *' '/^status:/{print $2; exit}' "$spec" 2>/dev/null | tr -d ' ')"
    if [ "$st" = "approved" ] || [ "$st" = "in_progress" ]; then
      git diff --quiet HEAD -- "$spec" 2>/dev/null || echo "[WARN] $spec 状态=$st 但有未 commit 改动，疑似规格漂移，走变更子流程（§2.4）" >&2
    fi
  done
fi
```

按需触发（跑 /oprun 才查），不每会话强灌——原 SessionStart hook 已移除，此复查是其职责落点。

---

## 循环

```
选 task（3.1）── 无 task ──▶ 循环结束 ──▶ 收尾
  │
有 task
  ▼
派 op-implementer（3.2，前台）
  │ mode=normal ──▶ 正向开发
  │ mode=fail（第1轮）──▶ 修复 blocker
  │ mode=blocked（第2轮 FAIL 后）──▶ 阻塞，回 3.1
  ▼
派 op-reviewer（3.3，前台，双裁决）
  ▼
判定（3.4）
  ├─ 双裁决 PASS ──▶ per-task 验收（3.5）
  │                      ├─ FAIL(≤3轮) ──▶ 修复 task 回流重验
  │                      └─ PASS ──▶ merge gate + squash-merge（3.6）─▶ closer 一段式收尾（3.7）─▶ leader 自审写入（3.8）─▶ 归档 ─▶ 回 3.1（A18，无用户事中审批）
  └─ 任一 FAIL
       ├─ 第1轮 ──▶ 回 3.2（implementer fail 模式）
       └─ 第2轮 ──▶ 阻塞（写 issues/{TID}_quality.md）──▶ 回 3.1
```

### 子步骤 3.1：选 task

选取条件（全满足，取 ID 最小）：status=待开始、depends_on 全部完成、不在阻塞范围、ID 最小。

无符合条件的 task → 循环结束，进入收尾。

### 子步骤 3.2：派 op-implementer

```bash
bash "$OP_HOME/scripts/op_implementer_check.sh" {TID}
# 输出: mode=normal|fail|blocked, round=1|2|3（>=3 即 blocked，exit 1）
# exit 0=可继续, exit 1=阻塞
```

| mode | round | 动作 |
|------|-------|------|
| normal | 1 | 正向开发：读 spec（dispatch prompt 给路径，op_execution/specs/{TID}_{slug}.md）+ jq 查 tasks_list.json 取 workset → TDD（先写映射验收标准的结构层单测，不跑 e2e） |
| fail | 2 | FAIL 轮（最后一轮）：读 review.md，改 blocker |
| blocked | — | exit 1，直接阻塞，不再派 implementer |

**派 implementer 前 leader 不生成文件**——dispatch prompt 直接给指针：

```
TID: {TID}
spec: docs/omni_powers/op_execution/specs/{TID}_{slug}.md
取元数据: jq 查 tasks_list.json 该 task（workset/depends_on）
约定: heavy 读 op_blueprint/architecture.md + conventions.md；lite spec 自足
```

```bash
bash "$OP_HOME/scripts/op_status.sh" {TID} in_progress
# P0-4：写 current_task，PostToolUse/SubagentStop hook 据此校验新鲜证据
awk '/^### current_task$/{print;print "";print "{TID}";f=1;next} /^### /{f=0} {if(!f)print}' docs/omni_powers/op_execution/leader_checkpoint.md > /tmp/cp.md && mv /tmp/cp.md docs/omni_powers/op_execution/leader_checkpoint.md
```

```js
Agent({ name: "op-implementer", subagent_type: "op-implementer",
  // model: 按顶部"派发模型规则"传——读 OP_IMPLEMENTER_MODEL，设了传该值，没设不传 model
  prompt: "cd <work_dir> && pwd\n{title}（{TID}）。先跑 op_implementer_check.sh {TID} 确定模式。读 spec（路径见 dispatch prompt）。TDD 实现（只跑结构层单测，不跑 e2e）。写 report.md（顶部总报告 + 分 Round 追加）。" })
```

implementer 返回后读摘要验证产出：

```bash
head -20 docs/omni_powers/op_execution/tasks/{TID}/report.md
```

### 子步骤 3.3：派 op-reviewer（双裁决）

```bash
bash "$OP_HOME/scripts/op_status.sh" {TID} reviewing
bash "$OP_HOME/scripts/op_read_verdict.sh" {TID}
# 输出 round: N, result: NONE|PASS|FAIL
```

```js
Agent({ name: "op-reviewer", subagent_type: "op-reviewer",
  // model: 按顶部"派发模型规则"传——读 OP_REVIEWER_MODEL，设了传该值，没设不传 model
  prompt: "cd <work_dir> && pwd\nreview {TID}。\n读 spec（路径见 dispatch prompt）（op_execution/specs/{spec}.md）。\n读 tasks/{TID}/report.md（顶部总报告 + 分轮）。\n代码变更：git diff\n输出：tasks/{TID}/review.md\n双裁决：规格合规（覆盖验收标准/不偏航/不自由发挥）+ 测试可信（测的是验收标准还是 mock/断言用户可观察/危险模式/implementer 是否偷跑了 e2e）。\n文件最后一行必须写 verdict: PASS 或 FAIL。重审在末尾追加新 verdict 行。" })
```

reviewer spawn/环境出错退避重试 max 3。重试仍失败 → 不写质量 verdict；`bash "$OP_HOME/scripts/op_status.sh {TID} blocked spawn`，下游保持 ready（调度器依 depends_on 不选中，A16），记录 spawn 错误摘要到 `op_execution/issues/{TID}_spawn.md` 后回 3.1。

### 子步骤 3.4：判定 review 结果

```bash
bash "$OP_HOME/scripts/op_read_verdict.sh" {TID}
# exit 0 = PASS, exit 1 = FAIL
```

| 结果 | 轮次 | 动作 |
|---|---|---|
| 双裁决 PASS | 任意 | 收口（3.5） |
| 任一 FAIL | 第1轮 | 回到 3.2（implementer fail 模式修复） |
| 任一 FAIL | 第2轮 | `bash "$OP_HOME/scripts/op_status.sh {TID} blocked quality`，按 optriage issue 元字段格式写 `issues/{TID}_quality.md`，下游保持 ready（A16），回 3.1 |

### 子步骤 3.5：per-task 验收（merge 前验，design §2.5）

双裁决 PASS 后、squash-merge 前派 op-evaluator 做 per-task 真机验收（构建产物从 task 分支构建）。**非行为型 task 免派**（接口先行/脚手架/纯内部重构，验收由 reviewer + 编译器承担，design §2.5）。

**派 evaluator 前 leader 先做访问隔离准备（结构 + 脚本，design §2.5；前提：hook 对 subagent 失效，隔离靠 worktree 结构 + 脚本机械组装 brief，不靠 hook 拦截）**：
1. 跑 `bash "$OP_HOME/scripts/op_assemble_eval_brief.sh" {TID}` 机械组装 evaluator brief——固定路径 cat（该 task 工作 spec 条件强制+可测性契约 / 生效规格开工前基线 / baselines 索引 / 启动方式，**剥设计探索结论段**），leader 不参与内容，evaluator 只读 brief 文件。
   **brief 生成后立即 commit 到 task 分支**——未 commit 文件不会出现在新 worktree，evaluator 连 brief 都读不到（HIGH-2 事故）：
   ```bash
   git add "docs/omni_powers/op_execution/acceptance/{TID}/eval_brief.md" && git commit -m "chore({TID}): evaluator brief"
   ```
2. **创建 evaluator 隔离 worktree**（基于 task 分支切出，sparse-checkout 排除 `src/`、`docs/omni_powers/op_execution/tasks/`、`op_record/tasks/`、`decisions.md`，防无意抄实现）：

   ```bash
   bash "$OP_HOME/scripts/op_worktree_setup.sh" eval .claude/worktrees/op-eval feat/op-eval
   ```

   evaluator 在 `.claude/worktrees/op-eval` 工作——**sparse-checkout 已落地（git 2.25+），advisory 防无意耦合**（正常读文件流程碰不到被排除路径；但 object store 共享，git 底层命令可绕，design §0.1）。**真正的硬底线**：写入侧靠 merge gate（§3.4，白名单）。旧 git（<2.25）脚本失败则退化为 advisory + WARN，merge gate 不受影响。
3. dispatch prompt 固定模板（advisory 留痕，不拦截），`cd` 指向 `.claude/worktrees/op-eval`。

```js
eval_brief_path="docs/omni_powers/op_execution/acceptance/{TID}/eval_brief.md"

Agent({ name: "op-evaluator", subagent_type: "op-evaluator",
  // model: 按顶部"派发模型规则"传——读 OP_EVALUATOR_MODEL，设了传该值，没设不传 model
  prompt: "cd <work_dir> && pwd\n读 {eval_brief_path}，按 brief 执行 per-task 验收 {TID}。" })
```

> prompt 故意极简——内容全在脚本组装的 brief 里，prompt 不塞 task 路径/report/diff（dispatch 协议层）。evaluator 按 brief 内的启动方式、验收标准、可测性契约执行：逐条验收标准评估 → PASS 的验收标准 固化成 acceptance/{TID}/ → 破坏检查 → 对抗探索。范围内 FAIL 转修复 task；范围外落 issues。

**evaluator 返回后：leader 收拢验收产物入主仓库（本轮改进，防蒸发）**。evaluator 在 eval worktree 写的产物会随 worktree teardown 蒸发（T0003 事故：`run-acceptance.mjs` 写在 op-eval worktree 内，删 worktree 即丢，验收报告引用的固化脚本仓库里根本不存在）。leader 必须在 teardown 前把两类产物落回主仓库：

```bash
# 1. 从 eval worktree 回收 acceptance 产物（acceptance_report.md 等——op_close_post.sh 强依赖）
mkdir -p "docs/omni_powers/op_execution/acceptance/{TID}"
cp -r ".claude/worktrees/op-eval/docs/omni_powers/op_execution/acceptance/{TID}/." "docs/omni_powers/op_execution/acceptance/{TID}/" 2>/dev/null || true
[ -s "docs/omni_powers/op_execution/acceptance/{TID}/acceptance_report.md" ] || echo "[WARN] acceptance_report.md 缺失——evaluator 可能未正常产出" >&2
# 2. 从 eval worktree 回收固化的 e2e 到主仓库（evaluator 按 brief 已写到 worktree 的 e2e/{TID}/）
mkdir -p "e2e/{TID}"
cp -r ".claude/worktrees/op-eval/e2e/{TID}/." "e2e/{TID}/" 2>/dev/null || true
# 3. 校验确有固化产物（B5 闸：op_close_post.sh 归档前要求 e2e/{TID}/ 已跟踪）
git add "e2e/{TID}" && git diff --cached --quiet "e2e/{TID}" && echo "[WARN] e2e/{TID}/ 无固化产物——非行为型 task 用 eval:skip，行为型 task 须补" >&2
# ⚠️ 此时不 commit e2e！e2e 提交放在 squash-merge 之后（3.6）。若先提交到主分支，
# 后续 merge gate tip-to-tip diff 会把主分支独有 e2e 解释为 task 分支删除，必然 REJECT（HIGH-1 事故）。
```

> **为何 e2e 走专属入口而非 merge gate 白名单**：e2e/** 是 leader 专属写入区（design §3.4 黑名单），implementer/task 分支禁碰。evaluator 固化产物由 **leader** 用 trailer 解锁提交到主仓库——这是黑名单的合法通道，不经 task 分支 merge gate。B5 归档闸（`e2e/{TID}/` 须已跟踪）查主仓库入库状态（squash-merge 后 E2E commit 落盘），merge gate 黑名单拦 task 分支越权——两者不冲突。**E2E commit 必须放在 squash-merge 之后**，避免 tip-to-tip diff 误判。

验收范围内 FAIL → **回流 op-implementer 修复**（同分支续做，fail 模式，回 3.2 派 implementer——**leader 不亲自改 src/**，防越权顶替；leader 只派发+读结果），修复后**必须重派 op-evaluator 重验收**，**≤3 轮**。

> **重验收强制闸（本轮改进，防跳验收标 done）**：eval FAIL 后的任何修复 commit，都必须重跑 evaluator 产新 `acceptance_report.md`（末行新 verdict）。`op_close_post.sh` 读 `acceptance_report.md` 末行 verdict——非 PASS 直接 die，收口走不动。禁止手工改 tasks_list 把 FAIL 的 task 标 done。
>
> **leader 不接管 implementer（本轮改进）**：eval FAIL 的根因常是运行时行为 bug（implementer 禁跑 e2e、reviewer 静态审看不见，必然堆到 eval 才爆——这是设计张力，非流程冗余）。但修复仍归 implementer，leader 亲自改 src 会击穿"被监督者之外证据链"。若限流/中断打断 eval，恢复后续跑，不由 leader 顶替。

到顶处置（design §2.5：验收标准是 binary gate，**不存在降级落 issue**）——人裁三选一：继续追加修复轮（显式授权）/ 显式豁免带 FAIL 验收标准归档（记 decisions.md + 该验收标准在生效规格标注 KNOWN-FAIL + 自动开 P1 issue）/ 转设计 task 改思路。范围外发现（不属本 task spec 验收标准 的问题/可用性建议）→ issues。验收 PASS → 进 mutation check → merge gate（3.6）。

**验收 PASS 后，运行 mutation check（本轮接入）**：
```bash
# 对 src/ 下受本 task workset 覆盖的 JS/TS 源文件跑变异测试（WARN 不阻断）
for f in <workset文件列表>; do
    if echo "$f" | grep -qE '\.(js|ts|jsx|tsx)$' && [ -f "$f" ]; then
        bash "$OP_HOME/scripts/op_mutation_check.sh" "$f" "npx vitest run --reporter=verbose 2>/dev/null || npx jest --no-coverage 2>/dev/null" || true
    fi
done
```
> ESCAPE 记 WARN 不阻断——mutation check 是体检层，不挡流程。

---

## merge gate + squash-merge（验收 PASS 后，3.6）

验收 PASS 后过 merge gate（写入硬底线，design §3.4）——squash-merge 回主分支前必跑。**主分支/当前分支模式也必须保持 task 分支拓扑**：派 implementer 前，实现改动必须先落到临时 task 分支（如 `op/task/{TID}`）；若发现改动已直接落在主分支，视为流程错误，硬停并报告用户，不得以事后人工检查或直接 commit 替代 gate。gate PASS 后 squash 回主分支。

```bash
bash "$OP_HOME/scripts/op_merge_gate.sh" {TID} {task_branch}   # task_branch 如 op/task/{TID} 或 feat/op-dev
# 校验：白名单允许触碰 = workset ∪ tasks/{TID}/report.md ∪ 结构层测试路径；其余 REJECT
#       + review verdict PASS 存在（读主分支 review.md 末行）+ 工作集越界即拒（advisory 升硬）
#       + 受保护路径黑名单二次确认（op_blueprint / op_record / specs / review.md / tasks_list.json / issues / e2e）
# exit 0=PASS 才许合；task 分支对白名单外路径的任何变更直接 REJECT（合法变更走专属通道：spec 变更子流程 / e2e leader 入口 / closer 提案）
```

> **实现状态**：`op_merge_gate.sh` 已落地（本轮）。用 `git merge-base {base} {task_branch}` 三点 diff 算实际改动集，不依赖 dispatch 锚点。REJECT（exit 1）时停下按越界项处理，不强合。exit 2 表示环境/参数错误，必须硬停并报告用户；禁止降级为人工检查 workset 后直接 commit。

merge gate PASS → squash-merge 回主分支（design §3.4 步骤 6，`git merge --squash`，兑现"task 即 commit"）。**不归档、不删分支**——归档在闸门 C 后（3.8）。

squash-merge 完成后，E2E 固化产物走 leader 专属入口提交（放在 squash 之后，避免 tip-to-tip diff 误判——HIGH-1）：
```bash
git add "e2e/{TID}"
trailer=$(bash "$OP_HOME/scripts/op_trailer_unlock.sh")
git commit -m "test({TID}): 固化 per-task 验收 E2E（AC 回归保护）" -m "$trailer"
```

进 closer 一段式收尾（3.7）。

---

## closer 一段式收尾（Stage 4，per-task 验收 PASS 后，3.7）

派 op-closer 做 per-task 一段式收尾（吸收验收结果）：同时产 blueprint 更新提案 + append decisions + 转暂存 issue。

```js
Agent({ name: "op-closer", subagent_type: "op-closer",
  // model: 按顶部"派发模型规则"传——读 OP_CLOSER_MODEL，设了传该值，没设不传 model
  prompt: "cd <work_dir> && pwd\n收尾 task {TID} \"{title}\"。验收已 PASS。\n一段式 per-task 收口：\n提取 report.md 的红灯归因段 append 到 op_record/decisions.md（来源标记 red-attribution，[来源标记 | {TID} | Round-N | 日期]；小决策不收，spec-delta 由 leader 写不经你）；将 review 【暂存】项按 optriage issue 格式全部转 issues（加 tech-debt 标签，不二次筛选）；产 blueprint 更新提案到 op_execution/acceptance/{TID}/blueprint_update.md（diff 覆盖 op_blueprint 全部文档 + baselines 合入段 + task 归档提案）。吸收验收发现的边界行为、FAIL 修复后的最终形态。只留\"现在是什么\"，过滤被否方案。\n权限红线（design §2.4）：仅写 decisions.md + issues/ + acceptance/{TID}/blueprint_update.md；不跑脚本、不碰 git、不改 status、不 stage、不碰 spec、不碰 op_blueprint、不归档、不盖戳。" })
```

closer 返回后 leader 跑收口前机械脚本：

```bash
bash "$OP_HOME/scripts/op_closer_gate.sh" {TID}   # 机械校验 closer 写入路径白/黑名单，越界拒进 leader 自审（本轮接入）
bash "$OP_HOME/skills/oprun/scripts/op_close_pre.sh" {TID}   # tasks_list 标"收口中"（不盖戳 spec）
```

---

## leader 自审写入（per-task，3.8，A18——无用户事中审批）

先跑 `/optriage`（或按 `skills/optriage/SKILL.md` 执行）分级 issues：P0/P1 转正式 task，P2/P3 登记。

leader 自审 closer 提案（呈报四样：验收报告 + spec 变更决策表 + P0/P1 issue + closer 提案）+ 直接执行写入 `op_blueprint/`（specs + baselines 合入）——**不呈报用户事中审批**（A18）。P0/P1 issue 不阻断（进结束报告，用户事后处置）。自审深度：默认快速审，>5 条变更或跨功能 baseline/e2e 升级详细审。

自审清单追加：
- 核对 `docs/omni_powers/profile` 实际值；closer/reviewer 产物中 profile/流程归因表述与实际不符，必须修正后再写入。
- issue 中流程归因不得直接采信 agent 推断；须结合 profile 实际值与流程证据复核。

leader 自审采纳 → 跑归档脚本：

```bash
bash "$OP_HOME/scripts/op_close_post.sh" {TID} {feature}
# 前置检查：review verdict PASS + merge gate PASS + decisions.md 存在本 TID closer append 块且已 commit（无则 die）
# → git mv 归档 task 目录到 op_record/tasks/{TID}/ + spec 原文入 op_record/specs/ + acceptance 入 op_record/acceptance/{TID}/
#   + 追加 progress + tasks_list 标"完成"
git status --short
git commit -m "feat({TID}): {title}"
bash "$OP_HOME/scripts/close_check.sh" {TID}
# 删 task 分支与 worktree（per-task 分支模型）
```

回到循环顶部 3.1。

---

## 收尾

**worktree 模式**：
```bash
git checkout <原分支>
# P0 整 session worktree 模型：feat/op-dev 上 per-task commit 整体 ff-merge 回主分支
# P1 per-task 分支模型（design §3.4）：每 task 已 squash-merge + 过 merge gate，此步仅清理 worktree，不再 ff-merge
git merge feat/op-dev --ff-only   # 仅 P0 模式执行；P1 模型此行跳过
bash "$OP_HOME/scripts/op_worktree_teardown.sh" .claude/worktrees/op-dev feat/op-dev
bash "$OP_HOME/scripts/op_worktree_teardown.sh" .claude/worktrees/op-eval feat/op-eval 2>/dev/null || true  # 若 per-task 验收已创建
cd <原项目根目录>
```

**主分支/当前分支模式**：无额外操作。

- **全部完成（A18 事后报告）**：生成汇总报告呈报用户——blueprint diff（规格新增/修改/删除）+ baselines 合入 + task 完成情况 + 累积 issues（P0/P1，P0 标注）+ AC/INV 变更记录 + spec 变更决策表。用户审核报告，发现不对则记 issue 或 `git revert` 整批。检查 issues/ 有无 `tech-debt` 标签项，提示处理
- **有待规划项**：提示用 `/opintake`
- **全部阻塞/挂起**：输出原因，等外部解除

## compact 恢复

1. 读 `RULES.md`
2. jq 查 tasks_list.json
3. 若有未归档 `tasks/{TID}/` 则从 report.md + review.md 重建状态
4. 重新选 task 进入循环

## 相关文件

| 文件 | 用途 |
|---|---|
| `RULES.md` | 运行时操作手册（compact 恢复入口） |
| `docs_template/omni_powers/` | 文档模板 |
| `scripts/op_status.sh` | 状态流转 |
| `skills/oprun/scripts/op_close_pre.sh` | 收口前机械步骤 |
| `scripts/op_close_post.sh` | 收口后机械步骤 |
| `scripts/op_implementer_check.sh` | implementer 模式判定 |
| `scripts/op_read_verdict.sh` | verdict 读取 + 轮次 |
| `scripts/close_check.sh` | 收口验收 |
| `scripts/op_jq.sh` | tasks_list.json 查询 |
| `scripts/op_worktree_setup.sh` | 隔离 worktree 创建（dev 排除 e2e / eval 排除 src+tasks+decisions） |
| `scripts/op_worktree_teardown.sh` | worktree + 分支清理 |
| `scripts/op_merge_gate.sh` | merge gate 受保护路径零 diff 校验（design §3.4，P1 交付） |
