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

## 步骤一：确工作目录 + 读状态

### 1.1 确工作目录

问用户（不区分先后顺序，一句完成）：
1. 在 worktree 还是 master 开发？（worktree 是隔离区，搞砸直接删。master 直接改，风险大）
2. 如果有多个待开发分支，选哪个？

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
cat docs/op_execution/leader_checkpoint.md

# 当前 task 状态（⚠️ 严禁 Read 整文件，用 jq 查）
jq '[.tasks[] | {id, status, depends_on}]' docs/op_execution/tasks_list.json

# 规则手册（compact 恢复必读）
cat RULES.md
```

### 状态判定

| 条件 | 动作 |
|---|---|
| 全部 status=完成 | 循环结束，进入收尾 |
| 存在 status=收口中 | 从 checkpoint 恢复，跳到收口子步骤 |
| 存在 status=审阅中 | 进入循环，先检查 review 是否完成（读 verdict 文件） |
| 存在 status=进行中 | 进入循环，先检查 coder 是否完成（读 context.md） |
| 存在可跑 task | 进入循环，从步骤二开始 |
| 全部阻塞/跳过 | 输出原因，等外部解除 |

---

## 步骤二：选 task

### 2.1 生成 DAG

```bash
bash skills/op-start/scripts/dag_gen.sh
# exit 非 0 → 禁止继续，修复后重跑
```

### 2.2 选下一个 task

task 串行执行，一次只跑一个。选取条件（4 条全满足，取 ID 最小）：status=待开始、depends_on 全部完成、不在阻塞范围、ID 最小。

---

## 循环

### 循环流程

```
进入循环
    │
    ├─ 有可跑 task → 进入子步骤 3.1（派 op-coder）
    │
    ├─ op-coder 完成（前台返回）→ 验证产出 → 进入子步骤 3.2（派 review）
    │
    ├─ 两 review 都完成（后台都返回）→ 读 verdict
    │     ├─ 双 PASS → 进入子步骤 3.3（收口）
    │     └─ FAIL → 进入子步骤 3.4（FAIL 轮）
    │
    └─ 无 task 可推进 → 循环结束 → 收尾
```

### 子步骤 3.1：派 op-coder

```bash
bash skills/op-start/scripts/op-status.sh {TID} 进行中
```

**派活**（前台 Sub Agent）：

```js
Agent({ name: "op-coder", subagent_type: "op-coder", model: "haiku",
  prompt: "cd <work_dir> && pwd\n在此目录 TDD 实现 T{n}。读 docs/op_execution/tasks/{TID}/ 下的 spec/plan/steps。完成后回报结果。" })
```

op-coder 返回后，验证产出（context.md 已更新），进入子步骤 3.2。

### 子步骤 3.2：派 review

```bash
bash skills/op-start/scripts/op-status.sh {TID} 审阅中
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

**任一 reviewer 出错**：只重试出错的那个（max 3），成功的等。重试仍失败 → 该 review 手动写 `verdict: FAIL`，进 FAIL 轮。

两个都返回后：

```bash
bash skills/op-start/scripts/op-read-verdict.sh {TID}
# exit 0 = PASS, exit 1 = FAIL
```

- **双 PASS** → `bash skills/op-start/scripts/op-status.sh {TID} 收口中`，进入子步骤 3.3
- **任一 FAIL** → 进入子步骤 3.4

### 子步骤 3.3：收口

派 op-closer（前台 Sub Agent）：

```js
Agent({ name: "op-closer", subagent_type: "op-closer", model: "haiku",
  prompt: "cd <work_dir> && pwd\n收口 T{n} \"{title}\"。暂存项：[{列表}。]决策：[{内容}。]specs 归属：{feature}。" })
```

op-closer 做：

1. spec 盖戳（"历史快照，以 docs/op_blueprint/specs/ 为准"）
2. git mv `docs/op_execution/tasks/{TID}` → `docs/op_record/tasks/{TID}`
3. 更新 `tasks_list.json`（status→完成）
4. 整理 `docs/op_blueprint/specs/{feature}.md`
5. 追加 `progress.md`、`decisions.md`（有决策时）、`tech_debt.md`
6. 按需更新 `docs/op_blueprint/` 下受影响文档
7. `git add docs/op_execution/ docs/op_record/ docs/op_blueprint/` （不含 src/tests —— coder 已 stage）

返回 closer_output 完整内容。leader 审查：

```bash
# leader 验证 closer 产出
git status --short  # 确认 stage 内容正确

# commit
git commit -m "feat({TID}): {title}"

# 写 checkpoint
HASH=$(git rev-parse HEAD)
# checkpoint 格式见 template/op_execution/leader_checkpoint.md
bash skills/op-start/scripts/close_check.sh {TID}
```

回到循环顶部。

### 子步骤 3.4：FAIL 轮

max 3 轮。

**第 1-2 轮 FAIL**：重新 dispatch op-coder（前台）：

```js
Agent({ name: "op-coder", subagent_type: "op-coder", model: "haiku",
  prompt: "cd <work_dir> && pwd\nT{n} review FAIL。blockers: {...}。读 review_*.md 改代码——只针对 blocker。在 review_*.md 末尾追加修改记录（禁碰 context.md）。完成后回报结果。" })
```

op-coder 返回 → 重派 review（回到子步骤 3.2）。

**第 3 轮仍 FAIL**：

```bash
bash skills/op-start/scripts/op-status.sh {TID} 阻塞 quality
# 写 docs/op_execution/issues/{TID}_quality.md
```

**下游传播**：

```bash
bash skills/op-start/scripts/op-status.sh --batch "{下游TID1},{下游TID2}" 跳过
```

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
| `skills/op-start/scripts/op-status.sh` | 状态流转 |
| `skills/op-start/scripts/op-read-verdict.sh` | verdict 读取 |
| `skills/op-start/scripts/close_check.sh` | 收口验收 |
| `skills/op-start/scripts/dag_gen.sh` | DAG 生成 |
| `skills/op-start/scripts/op-new-task.sh` | 工作区创建 |
| `skills/op-debt2tasks/SKILL.md` | 技术债偿还 |
