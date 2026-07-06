---
name: oprun
description: >
  从 checkpoint 续跑：task 循环 → spec 级验收 → 闸门 C → 归档。
  触发：/oprun、继续、下一步、干活。
  controller 即 leader 主会话，被本 skill 驱动。
---

# Op Run Skill

> **运行前检查环境**：`bash "$OP_HOME/scripts/op_check_env.sh"`（jq/git/OP_HOME，缺失 die + 装法）

`/oprun` 从 checkpoint 续跑待开始的 task。leader 查状态、派 implementer、review、收口，自动推进。

协议规则、状态机、review 判定等见 `RULES.md`。入口分拣与 spec 编写见 `opintake`。

## 派发模型规则

派发 Sub Agent 时，Agent 工具的 `model` 参数按以下规则传：

1. 读对应环境变量（`OP_IMPLEMENTER_MODEL` / `OP_REVIEWER_MODEL` / `OP_EVALUATOR_MODEL` / `OP_CLOSER_MODEL`）
2. **设了** → `model` 参数传该值（必须是 `haiku`/`sonnet`/`opus` 之一，对应 settings.json 的 `ANTHROPIC_DEFAULT_*_MODEL`）
3. **没设** → `model` 参数**不传**，Agent 继承主会话当前模型（用户可用 `/model` 随时切换）

下面派发示例的 `model:` 行注明"按规则传"——leader 据上述规则决定传不传、传什么。设计 task（brief 指明"只产方案纸"）也不得临时覆盖模型；需要更强模型时由用户通过 `/model` 或 OP_*_MODEL 配置决定。

## 步骤一：确认工作目录 + 读状态

### 1.1 确认工作目录

```bash
git branch -r | grep -E 'origin/(main|master)$' || git branch -r | head -1
```

问用户：worktree（推荐）/ 主分支 / 当前分支。

- **worktree**：`bash "$OP_HOME/scripts/op_worktree_setup.sh" dev .claude/worktrees/op-dev feat/op-dev` → `cd .claude/worktrees/op-dev`（sparse-checkout 自动排除 `e2e/`，行为层隔离；单 session 复用；结束时按收尾段清理；若目录/分支已存在，先让用户选择复用或另取名，勿强删）
- **主分支**：`git checkout {main或master}`
- **当前分支**：不动分支
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
| 全部 status=完成 | 循环结束，进入收尾 |
| 存在 status=收口中 | 从 checkpoint 恢复，跳到收口子步骤 |
| 存在 status=审阅中 | 进入循环，先检查 review 是否完成（读 verdict） |
| 存在 status=进行中 | 进入循环，先检查 implementer 是否完成（读 `tasks/{TID}/report.md` 顶部总报告状态） |
| 存在可跑 task | 进入循环 |
| 存在 status=待规划 | 提醒：用 `/opintake` 生成 spec |
| 全部阻塞/跳过/挂起 | 输出原因，等外部解除或用户修改状态 |

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
  ├─ 双裁决 PASS ──▶ 收口（3.5）──▶ 回 3.1
  └─ 任一 FAIL
       ├─ 第1轮 ──▶ 回 3.2（implementer fail 模式）
       └─ 第2轮 ──▶ 阻塞（写 issues/{TID}_quality.md）──▶ 回 3.1
```

### 子步骤 3.1：选 task

选取条件（全满足，取 ID 最小）：status=待开始、depends_on 全部完成、不在阻塞范围、ID 最小。

无符合条件的 task → 循环结束，进入收尾。

### 子步骤 3.2：派 op-implementer

```bash
bash "$OP_HOME/skills/oprun/scripts/op_coder_check.sh" {TID}
# 输出: mode=normal|fail|blocked, round=1|2|3（>=3 即 blocked，exit 1）
# exit 0=可继续, exit 1=阻塞
```

| mode | round | 动作 |
|------|-------|------|
| normal | 1 | 正向开发：读 brief.md（指向 spec 路径）→ 读工作 spec → TDD（先写映射 AC 的结构层单测，不跑 e2e） |
| fail | 2 | FAIL 轮（最后一轮）：读 review.md，改 blocker |
| blocked | — | exit 1，直接阻塞，不再派 implementer |

**派 implementer 前 leader 先生成 brief.md**：

```
docs/omni_powers/op_execution/tasks/{TID}/brief.md：

{tasks_list 中本 task 的完整记录——AC/INV/depends_on/预计工作集}
工作 spec 路径：docs/omni_powers/op_execution/specs/{spec}.md
定向包（上下文紧张时附）：{architecture.md 摘要 + conventions.md 命名规则}
完成定义：{一句话可测试行为 + 验证命令}
```

```bash
bash "$OP_HOME/scripts/op_status.sh" {TID} 进行中
# P0-4：写 current_task，PostToolUse/SubagentStop hook 据此校验新鲜证据
sed -i "s/^current_task:.*/current_task: {TID}/" docs/omni_powers/op_execution/leader_checkpoint.md
```

```js
Agent({ name: "op-implementer", subagent_type: "op-implementer",
  // model: 按顶部"派发模型规则"传——读 OP_IMPLEMENTER_MODEL，设了传该值，没设不传 model
  prompt: "cd <work_dir> && pwd\n{title}（{TID}）。先跑 op_coder_check.sh {TID} 确定模式。读 tasks/{TID}/brief.md + 指向的工作 spec。TDD 实现（只跑结构层单测，不跑 e2e）。写 report.md（顶部总报告 + 分 Round 追加）。" })
```

implementer 返回后读摘要验证产出：

```bash
head -20 docs/omni_powers/op_execution/tasks/{TID}/report.md
```

### 子步骤 3.3：派 op-reviewer（双裁决）

```bash
bash "$OP_HOME/scripts/op_status.sh" {TID} 审阅中
bash "$OP_HOME/skills/oprun/scripts/op_read_verdict.sh" {TID}
# 输出 round: N, result: NONE|PASS|FAIL
```

```js
Agent({ name: "op-reviewer", subagent_type: "op-reviewer",
  // model: 按顶部"派发模型规则"传——读 OP_REVIEWER_MODEL，设了传该值，没设不传 model
  prompt: "cd <work_dir> && pwd\nreview {TID}。\n读 tasks/{TID}/brief.md → 工作 spec（op_execution/specs/{spec}.md）。\n读 tasks/{TID}/report.md（顶部总报告 + 分轮）。\n代码变更：git diff\n输出：tasks/{TID}/review.md\n双裁决：①规格合规（覆盖 AC/不偏航/不自由发挥）②测试可信（测的是 AC 还是 mock/断言用户可观察/危险模式/implementer 是否偷跑了 e2e）。\n文件最后一行必须写 verdict: PASS 或 FAIL。重审在末尾追加新 verdict 行。" })
```

reviewer spawn/环境出错退避重试 max 3。重试仍失败 → 不写质量 verdict；`bash "$OP_HOME/scripts/op_status.sh {TID} 阻塞 spawn`，下游 `跳过`，记录 spawn 错误摘要到 `op_execution/issues/{TID}_spawn.md` 后回 3.1。

### 子步骤 3.4：判定 review 结果

```bash
bash "$OP_HOME/skills/oprun/scripts/op_read_verdict.sh" {TID}
# exit 0 = PASS, exit 1 = FAIL
```

| 结果 | 轮次 | 动作 |
|---|---|---|
| 双裁决 PASS | 任意 | 收口（3.5） |
| 任一 FAIL | 第1轮 | 回到 3.2（implementer fail 模式修复） |
| 任一 FAIL | 第2轮 | `bash "$OP_HOME/scripts/op_status.sh {TID} 阻塞 quality`，按 optriage issue 元字段格式写 `issues/{TID}_quality.md`，下游 `跳过`，回 3.1 |

### 子步骤 3.5：per-task 收口（轻，closer 提案制两段节奏之一）

双裁决 PASS 后跑收口前机械脚本：

```bash
bash "$OP_HOME/skills/oprun/scripts/op_close_pre.sh" {TID}
```

派 op-closer 做 per-task 收口（只 append decisions，不产 blueprint 提案）：

```js
Agent({ name: "op-closer", subagent_type: "op-closer",
  // model: 按顶部"派发模型规则"传——读 OP_CLOSER_MODEL，设了传该值，没设不传 model
  prompt: "cd <work_dir> && pwd\n收口 {TID} \"{title}\"。specs 归属：{feature}。时间戳：{ISO 时间}。\n这是 per-task 收口：append 决策到 op_record/decisions.md，并将 review 【暂存】项按 optriage issue 格式全部转 issues（加 tech-debt 标签，不二次筛选）。不产 blueprint 提案、不碰 op_blueprint、不归档、不盖戳、不 stage。" })
```

per-task 收口不审批（decisions.md append-only）。直接跑归档脚本：

```bash
bash "$OP_HOME/skills/oprun/scripts/op_close_post.sh {TID} {feature}
git status --short
git commit -m "feat({TID}): {title}"
bash "$OP_HOME/skills/oprun/scripts/op_checkpoint.sh {TID}
# leader 手动编辑 leader_checkpoint.md 的"关键上下文"段
bash "$OP_HOME/skills/oprun/scripts/close_check.sh {TID}
```

回到循环顶部 3.1。

---

## spec 级验收（Stage 4，整份 spec 所有 task 闭环后）

派 op-evaluator 做 spec 级真机验收。**evaluator 仅在 Stage 4 介入一次**：评估 → 固化 → 破坏检查 → 对抗探索。

**派 evaluator 前 leader 先做访问隔离准备（结构隔离 + 报告回流，design §2.5；hook 对 subagent 失效，靠结构隔离非 hook）**：
1. 跑 `skills/oprun/scripts/op_assemble_eval_brief.sh {前缀}` 机械组装 evaluator brief——固定路径 cat（工作 spec / 生效规格开工前基线 / baselines 索引 / 启动方式），leader 不参与内容，evaluator 只读 brief 文件。
2. **创建 evaluator 隔离 worktree**（sparse-checkout 排除 `src/`、`docs/omni_powers/op_execution/tasks/`、`op_record/tasks/`、`decisions.md`，防抄实现）：

   ```bash
   bash "$OP_HOME/scripts/op_worktree_setup.sh" eval .claude/worktrees/op-eval feat/op-eval
   ```

   evaluator 在 `.claude/worktrees/op-eval` 工作——源码/task 目录/decisions 物理不在文件系统（结构隔离硬底线，绕过 hook 对 subagent 失效）。需 git 2.25+；脚本失败（旧 git）则退化为 advisory + WARN。
3. dispatch prompt 固定模板（advisory 留痕，不拦截），`cd` 指向 `.claude/worktrees/op-eval`。

```js
eval_brief_path="docs/omni_powers/op_execution/acceptance/{前缀}/eval_brief.md"

Agent({ name: "op-evaluator", subagent_type: "op-evaluator",
  // model: 按顶部"派发模型规则"传——读 OP_EVALUATOR_MODEL，设了传该值，没设不传 model
  prompt: "cd <work_dir> && pwd\n读 {eval_brief_path}，按 brief 执行 spec 级验收 {spec前缀}。" })
```

> prompt 故意极简——内容全在脚本组装的 brief 里，prompt 不塞 task 路径/report/diff（dispatch 协议层）。evaluator 按 brief 内的启动方式、AC、可测性契约执行：逐 AC 评估 → PASS 的 AC 固化成 e2e/{前缀}/ → 破坏检查 → 对抗探索。范围内 FAIL 转修复 task；范围外落 issues。

验收范围内 FAIL → 修复 task 回流（走 task 循环）重验收，**≤3 轮**（到顶 Critical→升级人裁决/转设计 task，Important/Minor→落 issue）。验收 PASS → 进 per-leaf 收尾。

## per-leaf 收尾（Stage 4 验收 PASS 后，closer 两段节奏之二）

派 op-closer 产 per-leaf 提案（吸收验收结果）：

```js
Agent({ name: "op-closer", subagent_type: "op-closer",
  // model: 按顶部"派发模型规则"传
  prompt: "cd <work_dir> && pwd\n收尾叶子 {前缀} \"{title}\"。验收已 PASS。\n产 blueprint 更新提案到 op_execution/acceptance/{前缀}/blueprint_update.md（diff 覆盖 op_blueprint 全部文档 + baselines 合入段 + 叶子归档提案）。吸收验收发现的边界行为、FAIL 修复后的最终形态。只留\"现在是什么\"，过滤被否方案。不碰 git、不改 status、不归档、不盖戳、不 stage、不写 op_blueprint/。" })
```

## 闸门 C

先跑 `/optriage`（或按 `skills/optriage/SKILL.md` 执行）分级 issues：P0/P1 转正式 task，P2/P3 登记。

呈报四样给人审：验收报告 + 自决决策表（契约边界内决策，否了哪条转 rework）+ P0/P1 issue（P0 默认阻断；若用户显式豁免，记录 decisions）+ closer 的 per-leaf 收尾提案。

人批 → leader 执行实际写入 `op_blueprint/`（specs + baselines 合入）→ merge → 叶子归档（原文入 `op_record/specs/`、acceptance 工作区入 `op_record/acceptance/{前缀}/`，前缀标记完成——永不复用）。

---

## 收尾

**worktree 模式**：
```bash
git checkout <原分支>
git merge feat/op-dev --ff-only
bash "$OP_HOME/scripts/op_worktree_teardown.sh" .claude/worktrees/op-dev feat/op-dev
bash "$OP_HOME/scripts/op_worktree_teardown.sh" .claude/worktrees/op-eval feat/op-eval 2>/dev/null || true  # 若 Stage 4 已创建
cd <原项目根目录>
```

**主分支/当前分支模式**：无额外操作。

- **全部完成**：检查 issues/ 有无 `tech-debt` 标签项，提示处理
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
| `skills/oprun/scripts/op_close_post.sh` | 收口后机械步骤 |
| `skills/oprun/scripts/op_coder_check.sh` | implementer 模式判定 |
| `skills/oprun/scripts/op_read_verdict.sh` | verdict 读取 + 轮次 |
| `skills/oprun/scripts/close_check.sh` | 收口验收 |
| `skills/oprun/scripts/op_checkpoint.sh` | checkpoint 写入 |
| `scripts/op_jq.sh` | tasks_list.json 查询 |
| `scripts/op_worktree_setup.sh` | 隔离 worktree 创建（dev 排除 e2e / eval 排除 src+tasks+decisions） |
| `scripts/op_worktree_teardown.sh` | worktree + 分支清理 |
