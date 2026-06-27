---
name: op-start
description: >
  统一工作流入口——用户只需 /op-start，leader 进入自治循环。
  触发：/op-start、继续、下一步、干活。
---

# Op Start Skill

`/op-start` 是多 Agent 协作的启动按钮。leader 查看状态、派活、收口，自动推进所有 task。

**用户再触发 `/op-start`** 只在：compact 恢复、crash 恢复、想查进度。

协议规则、状态机、review 判定等见 `RULES.md`。

## 步骤一：确认工作目录 + 读状态

### 1.1 确认工作目录

先查仓库分支：

```bash
# 查远端默认分支
git branch -r | grep -E 'origin/(main|master)$' || git branch -r | head -1
```

问用户：

```
/op-start

在哪开发？
1. worktree（推荐）：创建隔离区，搞砸一键删除
2. 主分支（{main或master}）：直接在主分支改
3. 当前分支（{当前分支名}）
```

- **选 worktree**：`git worktree add .worktrees/op-dev -b feat/op-dev` → `cd .worktrees/op-dev`
- **选主分支**：`git checkout {main或master}`，当前目录就是工作目录
- **选当前分支**：不动分支，当前目录就是工作目录
- 记下 `<work_dir>` = 当前 `pwd` + 原分支名

用户也可以指定分支名：`/op-start feat/my-branch` → `git worktree add .worktrees/my-branch -b feat/my-branch`

### 1.2 读状态

```bash
# 上次断在哪
cat docs/omni_powers/op_execution/leader_checkpoint.md

# 当前 task 状态（⚠️ 严禁 Read 整文件，用 jq 查）
jq '[.tasks[] | {id, status, depends_on}]' docs/omni_powers/op_execution/tasks_list.json

# 规则手册（compact 恢复必读）
cat RULES.md
```

### 状态判定

| 条件 | 动作 |
|---|---|
| 全部 status=完成 | 循环结束，进入收尾 |
| 存在 status=收口中 | 从 checkpoint 恢复，跳到收口子步骤 |
| 存在 status=审阅中 | 进入循环，先检查 review 是否完成（读 verdict） |
| 存在 status=进行中 | 进入循环，先检查 coder 是否完成（`bash skills/op-start/scripts/op-context-read.sh {TID}`） |
| 存在可跑 task | 进入循环 |
| 全部阻塞/跳过 | 输出原因，等外部解除 |

---

## 步骤二：生成 DAG

```bash
bash skills/op-start/scripts/dag_gen.sh
# exit 非 0 → 禁止继续，修复后重跑
```

---

## 循环

```
进入循环
  │
  ▼
选 task（3.1）
  │
  ├────▶ 无 task ──▶ 循环结束 ──▶ 收尾
  │
  ▼
有 task
  │
  ▼
派 coder（3.2，前台 Sub Agent）
  │ mode=normal ──▶ 正向开发
  │ mode=fail（第1/2轮）──▶ 修复 blocker
  │ mode=blocked（第3轮 FAIL 后）──▶ 阻塞，回到 3.1
  │
  ▼
派 review（3.3，后台 Sub Agent ×3 并行）
  │
  ▼
判定 review 结果（3.4）
  │
  ├────▶ 三 PASS ──▶ 收口（3.5）──▶ 回到 3.1
  │
  ▼
任一 FAIL
  ├────▶ 第1/2轮 ──▶ 回到 3.2（coder 进入 fail 模式修复）
  └────▶ 第3轮 ──▶ 阻塞（写 issues/{TID}_quality.md）──▶ 回到 3.1
```

### 子步骤 3.1：选 task

选取条件（4 条全满足，取 ID 最小）：status=待开始、depends_on 全部完成、不在阻塞范围、ID 最小。

无符合条件的 task → 循环结束，进入收尾。

### 子步骤 3.2：派 coder

```bash
bash skills/op-start/scripts/op-coder-check.sh {TID}
# 输出: mode=normal|fail|blocked, round=1|2|3
# exit 0=可继续, exit 1=阻塞
```

| mode | round | 动作 |
|------|-------|------|
| normal | 1 | 正向开发：读 spec/plan，TDD |
| fail | 2 | FAIL 轮：读 review_*.md，改 blocker |
| fail | 3 | FAIL 轮（最后一轮）：修完或阻塞 |
| blocked | — | exit 1，直接阻塞，不再派 coder |

```bash
bash scripts/op_status.sh {TID} 进行中
```

```js
Agent({ name: "op-coder", subagent_type: "op-coder", model: "haiku",
  prompt: "cd <work_dir> && pwd\n{title}（{TID}）。先跑 op-coder-check.sh {TID} 确定模式。读 docs/omni_powers/op_execution/tasks/{TID}/ 下的 spec/plan。完成后用 op-context-append.sh 写摘要到 context.md。" })
```

coder 返回后，读摘要验证产出：

```bash
bash skills/op-start/scripts/op-context-read.sh {TID}
# 只读顶部摘要，不读完整 context。完整 context 交给 reviewer 细读
```

进入子步骤 3.3。

### 子步骤 3.3：派 review

```bash
bash scripts/op_status.sh {TID} 审阅中
```

先跑 op-read-verdict.sh 判断轮次：

```bash
bash skills/op-start/scripts/op-read-verdict.sh {TID}
# 输出 round: N, result: NONE|PASS|FAIL
# round=0 → 首轮，round≥1 → FAIL 轮（重审）
```

#### 首轮（round=0）

```js
Agent({ name: "op-spec-reviewer", subagent_type: "op-spec-reviewer", model: "sonnet",
  background: true,
  prompt: "cd <work_dir> && pwd\n首轮 review {TID} spec。\n任务文件：docs/omni_powers/op_execution/tasks/{TID}/spec.md + plan.md + context.md\n代码变更：git diff\n输出：docs/omni_powers/op_execution/tasks/{TID}/review_spec.md\n逐条核对实现是否与 spec 一致。文件最后一行必须写 verdict: PASS 或 FAIL。" })

Agent({ name: "op-code-reviewer", subagent_type: "op-code-reviewer", model: "sonnet",
  background: true,
  prompt: "cd <work_dir> && pwd\n首轮 review {TID}。\n任务文件：docs/omni_powers/op_execution/tasks/{TID}/spec.md + plan.md + context.md\n代码变更：git diff\n输出：docs/omni_powers/op_execution/tasks/{TID}/review_code.md\n文件最后一行必须写 verdict: PASS 或 FAIL。" })

Agent({ name: "op-test-reviewer", subagent_type: "op-test-reviewer", model: "sonnet",
  background: true,
  prompt: "cd <work_dir> && pwd\n首轮 review {TID} tests。\n任务文件：docs/omni_powers/op_execution/tasks/{TID}/spec.md + plan.md + context.md\n测试：tests/\n输出：docs/omni_powers/op_execution/tasks/{TID}/review_test.md\n文件最后一行必须写 verdict: PASS 或 FAIL。" })
```

#### FAIL 轮（round≥1）

```js
Agent({ name: "op-spec-reviewer", subagent_type: "op-spec-reviewer", model: "sonnet",
  background: true,
  prompt: "cd <work_dir> && pwd\n重审 {TID} spec。\n任务文件：docs/omni_powers/op_execution/tasks/{TID}/spec.md + plan.md\n上次审查：docs/omni_powers/op_execution/tasks/{TID}/review_spec.md\n代码变更：git diff\n验证修复后，在 review_spec.md 末尾追加新 verdict 行（不覆盖已有内容）。" })

Agent({ name: "op-code-reviewer", subagent_type: "op-code-reviewer", model: "sonnet",
  background: true,
  prompt: "cd <work_dir> && pwd\n重审 {TID}。\n任务文件：docs/omni_powers/op_execution/tasks/{TID}/spec.md + plan.md\n上次审查：docs/omni_powers/op_execution/tasks/{TID}/review_code.md\n代码变更：git diff\n验证修复后，在 review_code.md 末尾追加新 verdict 行（不覆盖已有内容）。" })

Agent({ name: "op-test-reviewer", subagent_type: "op-test-reviewer", model: "sonnet",
  background: true,
  prompt: "cd <work_dir> && pwd\n重审 {TID} tests。\n任务文件：docs/omni_powers/op_execution/tasks/{TID}/spec.md + plan.md\n上次审查：docs/omni_powers/op_execution/tasks/{TID}/review_test.md\n代码变更：git diff\n验证修复后，在 review_test.md 末尾追加新 verdict 行（不覆盖已有内容）。" })
```

**任一 reviewer 出错**：只重试出错的那个（max 3），成功的等。重试仍失败 → 该 review 文件手动写 `verdict: FAIL`。

三个都返回后进入子步骤 3.4。

### 子步骤 3.4：判定 review 结果

```bash
bash skills/op-start/scripts/op-read-verdict.sh {TID}
# 输出 round + spec_review + code_review + test_review + result
# exit 0 = 三 PASS, exit 1 = 任一 FAIL
```

| 结果 | 轮次 | 动作 |
|---|---|---|
| 三 PASS | 任意 | 收口（子步骤 3.5） |
| 任一 FAIL | 第1/2轮 | 回到子步骤 3.2（coder 进入 fail 模式修复） |
| 任一 FAIL | 第3轮 | `bash scripts/op_status.sh {TID} 阻塞 quality`，写 `issues/{TID}_quality.md`，`bash scripts/op_status.sh --batch "{下游TID列表}" 跳过`，回到子步骤 3.1 |

### 子步骤 3.5：收口

三 PASS 后派 op-closer（前台 Sub Agent）：

```bash
bash scripts/op_status.sh {TID} 收口中
```

```js
Agent({ name: "op-closer", subagent_type: "op-closer", model: "haiku",
  prompt: "cd <work_dir> && pwd\n收口 {TID} \"{title}\"。暂存项：[{列表}。]决策：[{内容}。]specs 归属：{feature}。" })
```

op-closer 做：

1. spec 盖戳（"历史快照，以 docs/omni_powers/op_blueprint/specs/ 为准"）
2. git mv `docs/omni_powers/op_execution/tasks/{TID}` → `docs/omni_powers/op_record/tasks/{TID}`
3. `bash scripts/op_status.sh {TID} 完成`
4. 整理 `docs/omni_powers/op_blueprint/` 下所有受影响文档（specs/{feature}.md、prd.md、architecture.md 等）
5. 追加 `docs/omni_powers/op_record/progress.md`、`docs/omni_powers/op_record/decisions.md`（有决策时）、`docs/omni_powers/op_execution/tech_debt.md`
6. `git add docs/omni_powers/op_execution/ docs/omni_powers/op_record/ docs/omni_powers/op_blueprint/`

返回 closer_output 完整内容。leader 审查：

```bash
git status --short  # 确认 stage 内容正确
git commit -m "feat({TID}): {title}"

# 自动写 checkpoint 机械部分（取 hash + 查 title + 写已完成列表 + 重算状态）
bash skills/op-start/scripts/op-checkpoint.sh {TID}

# leader 手动编辑 docs/omni_powers/op_execution/leader_checkpoint.md 的"关键上下文"段

# 验收
bash skills/op-start/scripts/close_check.sh {TID}
```

回到循环顶部 子步骤 3.1。

---

## 收尾

循环结束后：

**worktree 模式**：
```bash
git checkout <原分支>
git merge feat/op-dev --ff-only
git worktree remove .worktrees/op-dev
cd <原项目根目录>
```

**主分支/当前分支模式**：无额外操作。

- **全部完成**：检查 tech_debt.md，有未偿债项则提示 `/op-debt2tasks`
- **全部阻塞**：输出原因，等外部解除

## compact 恢复

1. 读 `RULES.md`
2. jq 查 tasks_list.json
3. 若有未归档 `tasks/{TID}/` 则从 context.md + review_*.md 重建状态
4. 重新选 task 进入循环

## 相关文件

| 文件 | 用途 |
|---|---|
| `RULES.md` | 规则手册 + 操作细则 |
| `template/` | 文档模板 |
| `scripts/op_status.sh` | 状态流转 |
| `skills/op-start/scripts/op-coder-check.sh` | coder 模式判定（正向/Fail/阻塞） |
| `skills/op-start/scripts/op-read-verdict.sh` | verdict 读取 + 轮次判断 |
| `skills/op-start/scripts/op-context-read.sh` | 读 context.md 摘要（不进完整上下文） |
| `skills/op-start/scripts/op-context-append.sh` | coder 写摘要到 context.md 顶部 |
| `skills/op-start/scripts/close_check.sh` | 收口验收 |
| `skills/op-start/scripts/op-checkpoint.sh` | checkpoint 写入 |
| `skills/op-start/scripts/dag_gen.sh` | DAG 生成 |
| `scripts/op_new_task.sh` | 工作区创建 |
| `skills/op-debt2tasks/SKILL.md` | 技术债偿还 |
