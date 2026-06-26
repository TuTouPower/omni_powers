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

问用户：

```
/op-start

在哪开发？
1. worktree 模式（推荐）：创建隔离区，搞砸一键删除
2. master 模式：直接在 master 分支改，风险大
```

- **选 worktree**：`git worktree add .worktrees/op-dev -b feat/op-dev` → `cd .worktrees/op-dev`
- **选 master**：不创建 worktree，当前目录就是工作目录
- 记下 `<work_dir>` = 当前 `pwd`

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
| 存在 status=进行中 | 进入循环，先检查 coder 是否完成（读 context.md） |
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
    ├─ 无 task → 循环结束 → 收尾
    └─ 有 task
        │
        ▼
      派 coder（3.2，前台 Sub Agent）
        │
        ▼
      派 review（3.3，后台 Sub Agent ×2 并行）
        │
        ▼
      读 verdict（3.4）
        │
        ├─ 双 PASS → 收口（3.5）→ 回到循环顶部
        │
        └─ 任一 FAIL → 回到 3.2（coder 自动判断是 FAIL 轮还是新 task）
                      第 3 轮仍 FAIL → 阻塞 → 回到循环顶部
```

### 子步骤 3.1：选 task

选取条件（4 条全满足，取 ID 最小）：status=待开始、depends_on 全部完成、不在阻塞范围、ID 最小。

无符合条件的 task → 循环结束，进入收尾。

### 子步骤 3.2：派 coder

**派活前先跑判断脚本**：

```bash
bash skills/op-start/scripts/op-coder-check.sh {TID}
# 输出: mode=normal|fail|blocked, round=1|2|3
# exit 0=可继续, exit 1=阻塞（不应再派 coder）
```

| mode | round | 动作 |
|------|-------|------|
| normal | 1 | 正向开发，读 spec/plan/steps |
| fail | 2 | FAIL 轮：读 review_*.md + diff，针对 blocker 改 |
| fail | 3 | FAIL 轮（最后一轮） |
| blocked | - | exit 1，直接阻塞，不再派 coder |

```bash
bash scripts/op_status.sh {TID} 进行中
```

```js
Agent({ name: "op-coder", subagent_type: "op-coder", model: "haiku",
  prompt: "cd <work_dir> && pwd\nT{n}。先跑 op-coder-check.sh {TID} 确定模式。读 docs/omni_powers/op_execution/tasks/{TID}/ 下的 spec/plan/steps。" })
```

coder 返回后，验证产出（context.md 已更新），进入子步骤 3.3。

### 子步骤 3.3：派 review

```bash
bash scripts/op_status.sh {TID} 审阅中
```

并行派两个后台 Sub Agent：

```js
Agent({ name: "op-code-reviewer", subagent_type: "op-code-reviewer", model: "sonnet",
  background: true,
  prompt: "cd <work_dir> && pwd\nreview T{n}。git diff + context.md → 写 review_code.md。首行 verdict: PASS 或 FAIL。FAIL 时每条问题标等级，默认不暂存。重审时在末尾纯追加 ### Round N verdict: PASS/FAIL。" })

Agent({ name: "op-test-reviewer", subagent_type: "op-test-reviewer", model: "sonnet",
  background: true,
  prompt: "cd <work_dir> && pwd\nreview T{n} tests。读 tests/ + context.md → 写 review_test.md。首行 verdict: PASS 或 FAIL。重审时在末尾纯追加 ### Round N verdict: PASS/FAIL。" })
```

**任一 reviewer 出错**：只重试出错的那个（max 3），成功的等。重试仍失败 → 该 review 文件手动写 `verdict: FAIL`。

两个都返回后进入子步骤 3.4。

### 子步骤 3.4：判定

```bash
bash skills/op-start/scripts/op-read-verdict.sh {TID}
# 输出每个 review 文件的 verdict + 最终结果
# exit 0 = 双 PASS, exit 1 = 任一 FAIL
```

脚本分别读 `review_code.md` 和 `review_test.md` 的**最后一条** verdict 行，两个独立判定。

| code | test | 结果 |
|------|------|------|
| PASS | PASS | → 收口（子步骤 3.5） |
| FAIL | PASS | → 回 coder（子步骤 3.2），code-reviewer blockers |
| PASS | FAIL | → 回 coder（子步骤 3.2），test-reviewer blockers |
| FAIL | FAIL | → 回 coder（子步骤 3.2），两份 blockers |

**第 3 轮仍任一 FAIL**：不再回 coder：

```bash
bash scripts/op_status.sh {TID} 阻塞 quality
# 写 docs/omni_powers/op_execution/issues/{TID}_quality.md
```

**下游传播**：

```bash
bash scripts/op_status.sh --batch "{下游TID1},{下游TID2}" 跳过
```

回到循环顶部。

### 子步骤 3.5：收口

双 PASS 后派 op-closer（前台 Sub Agent）：

```bash
bash scripts/op_status.sh {TID} 收口中
```

```js
Agent({ name: "op-closer", subagent_type: "op-closer", model: "haiku",
  prompt: "cd <work_dir> && pwd\n收口 T{n} \"{title}\"。暂存项：[{列表}。]决策：[{内容}。]specs 归属：{feature}。" })
```

op-closer 做：

1. spec 盖戳（"历史快照，以 docs/omni_powers/op_blueprint/specs/ 为准"）
2. git mv `docs/omni_powers/op_execution/tasks/{TID}` → `docs/omni_powers/op_record/tasks/{TID}`
3. 更新 `tasks_list.json`（status→完成）
4. 整理 `docs/omni_powers/op_blueprint/specs/{feature}.md`
5. 追加 `progress.md`、`decisions.md`（有决策时）、`tech_debt.md`
6. 按需更新 `docs/omni_powers/op_blueprint/` 下受影响文档
7. `git add docs/omni_powers/op_execution/ docs/omni_powers/op_record/ docs/omni_powers/op_blueprint/`

返回 closer_output 完整内容。leader 审查：

```bash
git status --short  # 确认 stage 内容正确
git commit -m "feat({TID}): {title}"

# 写 checkpoint
HASH=$(git rev-parse HEAD)
# 格式见 template/op_execution/leader_checkpoint.md
bash skills/op-start/scripts/close_check.sh {TID}
```

回到循环顶部。

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

**master 模式**：无额外操作。

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
| `RULES.md` | 规则手册 |
| `RULES_DETAIL.md` | 操作细则 |
| `template/` | 文档模板 |
| `scripts/op_status.sh` | 状态流转 |
| `skills/op-start/scripts/op-coder-check.sh` | coder 模式判定（正向/Fail/阻塞） |
| `skills/op-start/scripts/op-read-verdict.sh` | verdict 读取 |
| `skills/op-start/scripts/close_check.sh` | 收口验收 |
| `skills/op-start/scripts/dag_gen.sh` | DAG 生成 |
| `scripts/op_new_task.sh` | 工作区创建 |
| `skills/op-debt2tasks/SKILL.md` | 技术债偿还 |
