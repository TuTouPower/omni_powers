---
name: oprun
description: >
  从 checkpoint 续跑：task 循环 → spec 级验收 → 闸门 C → 归档。
  触发：/oprun、继续、下一步、干活。
  controller 即 leader 主会话，被本 skill 驱动。
---

# Op Run Skill

`/oprun` 从 checkpoint 续跑就绪的 task。leader 查状态、派 implementer、review、收口，自动推进。

协议规则、状态机、review 判定等见 `RULES.md`。入口分拣与 spec 编写见 `opintake`。

## 派发模型规则

派发 Sub Agent 时，Agent 工具的 `model` 参数按以下规则传：

1. 读对应环境变量（`OP_IMPLEMENTER_MODEL` / `OP_REVIEWER_MODEL` / `OP_EVALUATOR_MODEL` / `OP_CLOSER_MODEL`）
2. **设了** → `model` 参数传该值（必须是 `haiku`/`sonnet`/`opus` 之一，对应 settings.json 的 `ANTHROPIC_DEFAULT_*_MODEL`）
3. **没设** → `model` 参数**不传**，Agent 继承主会话当前模型（用户可用 `/model` 随时切换）

下面派发示例的 `model:` 行注明"按规则传"——leader 据上述规则决定传不传、传什么。设计 task（brief 指明"只产方案纸"）临时把 implementer 的模型设为 `opus`，覆盖环境变量。

## 步骤一：确认工作目录 + 读状态

### 1.1 确认工作目录

```bash
git branch -r | grep -E 'origin/(main|master)$' || git branch -r | head -1
```

问用户：worktree（推荐）/ 主分支 / 当前分支。

- **worktree**：`git worktree add .worktrees/op-dev -b feat/op-dev` → `cd .worktrees/op-dev`
- **主分支**：`git checkout {main或master}`
- **当前分支**：不动分支
- 记下 `<work_dir>` = 当前 `pwd` + 原分支名

### 1.2 读状态

```bash
cat docs/omni_powers/op_execution/leader_checkpoint.md
jq '[.tasks[] | {id, status, depends_on}]' docs/omni_powers/op_execution/tasks_list.json
cat RULES.md
```

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
bash skills/oprun/scripts/op-coder-check.sh {TID}
# 输出: mode=normal|fail|blocked, round=1|2
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
bash scripts/op_status.sh {TID} 进行中
```

```js
Agent({ name: "op-implementer", subagent_type: "op-implementer",
  // model: 按顶部"派发模型规则"传——读 OP_IMPLEMENTER_MODEL，设了传该值，没设不传 model
  prompt: "cd <work_dir> && pwd\n{title}（{TID}）。先跑 op-coder-check.sh {TID} 确定模式。读 tasks/{TID}/brief.md + 指向的工作 spec。TDD 实现（只跑结构层单测，不跑 e2e）。写 report.md（顶部总报告 + 分 Round 追加）。" })
```

implementer 返回后读摘要验证产出：

```bash
head -20 docs/omni_powers/op_execution/tasks/{TID}/report.md
```

### 子步骤 3.3：派 op-reviewer（双裁决）

```bash
bash scripts/op_status.sh {TID} 审阅中
bash skills/oprun/scripts/op-read-verdict.sh {TID}
# 输出 round: N, result: NONE|PASS|FAIL
```

```js
Agent({ name: "op-reviewer", subagent_type: "op-reviewer",
  // model: 按顶部"派发模型规则"传——读 OP_REVIEWER_MODEL，设了传该值，没设不传 model
  prompt: "cd <work_dir> && pwd\nreview {TID}。\n读 tasks/{TID}/brief.md → 工作 spec（op_execution/specs/{spec}.md）。\n读 tasks/{TID}/report.md（顶部总报告 + 分轮）。\n代码变更：git diff\n输出：tasks/{TID}/review.md\n双裁决：①规格合规（覆盖 AC/不偏航/不自由发挥）②测试可信（测的是 AC 还是 mock/断言用户可观察/危险模式/implementer 是否偷跑了 e2e）。\n文件最后一行必须写 verdict: PASS 或 FAIL。重审在末尾追加新 verdict 行。" })
```

reviewer 出错重试 max 3。重试仍失败 → review.md 手写 `verdict: FAIL`。

### 子步骤 3.4：判定 review 结果

```bash
bash skills/oprun/scripts/op-read-verdict.sh {TID}
# exit 0 = PASS, exit 1 = FAIL
```

| 结果 | 轮次 | 动作 |
|---|---|---|
| 双裁决 PASS | 任意 | 收口（3.5） |
| 任一 FAIL | 第1轮 | 回到 3.2（implementer fail 模式修复） |
| 任一 FAIL | 第2轮 | `bash scripts/op_status.sh {TID} 阻塞 quality`，写 `issues/{TID}_quality.md`，下游 `跳过`，回 3.1 |

### 子步骤 3.5：per-task 收口（轻，closer 提案制两段节奏之一）

双裁决 PASS 后跑收口前机械脚本：

```bash
bash scripts/op_close_pre.sh {TID}
```

派 op-closer 做 per-task 收口（只 append decisions，不产 blueprint 提案）：

```js
Agent({ name: "op-closer", subagent_type: "op-closer",
  // model: 按顶部"派发模型规则"传——读 OP_CLOSER_MODEL，设了传该值，没设不传 model
  prompt: "cd <work_dir> && pwd\n收口 {TID} \"{title}\"。specs 归属：{feature}。\n这是 per-task 收口：只 append 决策到 op_record/decisions.md，暂存项转 issues。不产 blueprint 提案、不碰 op_blueprint、不归档、不盖戳、不 stage。" })
```

per-task 收口不审批（decisions.md append-only）。直接跑归档脚本：

```bash
bash scripts/op_close_post.sh {TID}
git status --short
git commit -m "feat({TID}): {title}"
bash skills/oprun/scripts/op-checkpoint.sh {TID}
# leader 手动编辑 leader_checkpoint.md 的"关键上下文"段
bash skills/oprun/scripts/close_check.sh {TID}
```

回到循环顶部 3.1。

---

## spec 级验收（Stage 4，整份 spec 所有 task 闭环后）

派 op-evaluator 做 spec 级真机验收。**evaluator 仅在 Stage 4 介入一次**：评估 → 固化 → 破坏检查 → 对抗探索。

**派 evaluator 前 leader 保证访问隔离（结构单层 + 报告回流，design §8.1；hook 对 subagent 失效，依据 `op_decisions.md` D18）**：
1. 跑 `scripts/op_assemble_eval_brief.sh {前缀}` 机械组装 evaluator brief——固定路径 cat（工作 spec / 生效规格开工前基线 / baselines 索引 / 启动方式），leader 不参与内容，evaluator 只读 brief 文件。
2. **evaluator worktree 无 src**：evaluator 在独立 worktree，只挂载 spec + 生效规格 + baselines + 构建产物 + `e2e/`——`src/**`、task 目录、`decisions.md` 物理不挂载。implementer 分支跑 CI 产构建产物供 evaluator 操作。
3. dispatch prompt 固定模板（advisory 留痕，不拦截）。

```js
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

呈报四样给人审：验收报告 + 自决决策表（契约边界内决策，否了哪条转 rework）+ P0/P1 issue（人定阻不阻断 merge）+ closer 的 per-leaf 收尾提案。

人批 → leader 执行实际写入 `op_blueprint/`（specs + baselines 合入）→ merge → 叶子归档（原文入 `op_record/specs/`、acceptance 工作区入 `op_record/acceptance/{前缀}/`，前缀标记完成——永不复用）。

---

## 收尾

**worktree 模式**：
```bash
git checkout <原分支>
git merge feat/op-dev --ff-only
git worktree remove .worktrees/op-dev
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
| `scripts/op_close_pre.sh` | 收口前机械步骤 |
| `scripts/op_close_post.sh` | 收口后机械步骤 |
| `skills/oprun/scripts/op-coder-check.sh` | implementer 模式判定 |
| `skills/oprun/scripts/op-read-verdict.sh` | verdict 读取 + 轮次 |
| `skills/oprun/scripts/close_check.sh` | 收口验收 |
| `skills/oprun/scripts/op-checkpoint.sh` | checkpoint 写入 |
| `scripts/op_jq.sh` | tasks_list.json 查询 |
