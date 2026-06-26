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

## 步骤一：读状态

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
| 全部 status=完成 | 循环结束 |
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

进入循环后按以下子步骤推进，直到无 task 可推进或全部完成。

### 循环流程

```
进入循环
    │
    ├─ 有可跑 task → 进入子步骤 3.1（派 op-coder）
    │
    ├─ op-coder 完成（Sub Agent 前台返回）→ 进入子步骤 3.2（派 review）
    │
    ├─ 两个 review 都完成（后台 Sub Agent 都返回）→ 读 verdict
    │     ├─ 双 PASS → 进入子步骤 3.4（收口）
    │     └─ FAIL → 进入子步骤 3.5（FAIL 轮）
    │
    └─ 无 task 可推进 → 循环结束
```

Sub Agent 直接返回结果给 leader，不需要标记文件、不需要轮询。后台 Sub Agent 完成时自动回报。

### 子步骤 3.1：派 op-coder

```bash
git worktree add .worktrees/{TID} -b feat/{TID}
```

**派活**（前台 Sub Agent，leader 阻塞等待返回）：

```js
Agent({ name: "op-coder", subagent_type: "op-coder", model: "haiku",
  prompt: "cd <project_root>/.worktrees/{TID} && pwd\n在此目录 TDD 实现 T{n}。读 docs/op_execution/tasks/{TID}/ 下的 spec/plan/steps。完成后回报结果。" })
```

```bash
bash skills/op-start/scripts/op-status.sh {TID} 进行中
```

op-coder 返回后，验证产出（context.md 已更新），进入子步骤 3.2。

### 子步骤 3.2：派 review

op-coder 完成后立即并行派两个后台 Sub Agent：

```bash
bash skills/op-start/scripts/op-status.sh {TID} 审阅中
```

```js
Agent({ name: "op-code-reviewer", subagent_type: "op-code-reviewer", model: "sonnet",
  background: true,
  prompt: "cd <project_root>/.worktrees/{TID} && pwd\nreview T{n}。git diff + context.md → 写 review_code.md。首行 verdict: PASS 或 FAIL。FAIL 时每条问题标等级（CRITICAL/HIGH/MEDIUM/LOW），默认不暂存。重审时在末尾纯追加 ### Round N verdict: PASS/FAIL，不覆盖已有行。" })

Agent({ name: "op-test-reviewer", subagent_type: "op-test-reviewer", model: "sonnet",
  background: true,
  prompt: "cd <project_root>/.worktrees/{TID} && pwd\nreview T{n} tests。读 tests/ + context.md → 写 review_test.md。首行 verdict: PASS 或 FAIL。重审时在末尾纯追加 ### Round N verdict: PASS/FAIL，不覆盖已有行。" })
```

两个后台 Sub Agent 完成时自动回报结果给 leader。leader 等两个都返回后进入子步骤 3.3。

**任一 reviewer 出错（返回 InternalError / 未正常返回 / 超时无响应）：**
- 只重试出错的那个 reviewer，已成功的那个保留结果等待
- 重试仍失败（max 3）：该 reviewer 对应的 review 文件手动写 `verdict: FAIL`，进入 FAIL 轮处理
- 两个都成功后一起进入子步骤 3.3

### 子步骤 3.3：处理 review 结果

两个 review 都返回后：

```bash
bash skills/op-start/scripts/op-read-verdict.sh {TID}
# exit 0 = 最后一条 verdict 为 PASS, exit 1 = FAIL
```

> reviewer 重审时在 review_*.md 末尾**纯追加** `### Round N verdict: PASS/FAIL`，不覆盖已有行。leader 读**最后一条** verdict 行判定。

- **双 PASS** → `bash skills/op-start/scripts/op-status.sh {TID} 收口中`，进入子步骤 3.4
- **任一 FAIL** → 进入子步骤 3.5

### 子步骤 3.4：收口

leader 串行执行以下 5 小步：

#### 3.4.1 派 op-closer（前台 Sub Agent）

```js
Agent({ name: "op-closer", subagent_type: "op-closer", model: "haiku",
  prompt: "cd <project_root>/.worktrees/{TID} && pwd\n收口 T{n} \"{title}\"。暂存项：[{列表}。]决策：[{内容}。]specs 归属：{feature}。" })
```

op-closer 做 spec 盖戳 + git mv 归档 + git add -A。不碰控制平面文件。leader 保存返回内容供后续用。

#### 3.4.2 提交代码

```bash
cd <project_root>/.worktrees/{TID} && pwd || { echo "[FAIL] 切 worktree 失败" >&2; exit 1; }
git commit -m "feat({TID}): {title}"
```

#### 3.4.3 merge + 删 worktree

```bash
cd <project_root> && pwd
git merge feat/{TID} --ff-only -m "merge({TID}): {title}"
git worktree remove .worktrees/{TID}
```

#### 3.4.4 更新控制平面

```bash
git status --short | grep -qv '^$' && { echo "[FAIL] 主 repo 不干净" >&2; exit 1; }

bash skills/op-start/scripts/op-status.sh {TID} 完成

# 用 op-closer 返回的内容追加 progress.md / decisions.md / tech_debt.md
# 整理 specs/{feature}.md
# 按需更新 docs/op_blueprint/ 下受影响文档（prd/architecture/domain/conventions/spec 等）

HASH=$(git rev-parse HEAD)
# checkpoint 格式见 docs_template/omni_powers/op_execution/leader_checkpoint.md
```

#### 3.4.5 验收 + 提交

```bash
bash skills/op-start/scripts/close_check.sh {TID} || { echo "[FAIL] close_check 不通过" >&2; exit 1; }

git add docs/op_execution/ docs/op_record/ docs/op_blueprint/
git commit -m "chore(omni_powers): {TID} 收口记录"
```

回到循环顶部。

### 子步骤 3.5：FAIL 轮

max 3 轮。

**第 1-2 轮 FAIL**：重新 dispatch 一个 op-coder Sub Agent（前台）：

```js
Agent({ name: "op-coder", subagent_type: "op-coder", model: "haiku",
  prompt: "cd <project_root>/.worktrees/{TID} && pwd\nT{n} review FAIL。blockers: {...}。读 review_*.md 改代码——只针对 blocker 改实现和补测试，不扩展到 blocker 之外的新行为和新测试。在 review_*.md 末尾追加修改记录（禁碰 context.md）。完成后回报结果。" })
```

op-coder 返回后 → 重新派 review（回到子步骤 3.2）。reviewer 在 review_*.md 末尾**纯追加** `### Round N verdict: PASS/FAIL`，不覆盖已有行。leader 读**最后一条** verdict 行判定。

**第 3 轮仍 FAIL**：

```bash
bash skills/op-start/scripts/op-status.sh {TID} 阻塞 quality
# 写 docs/op_execution/issues/{TID}_quality.md
```

**下游传播**：

```bash
bash skills/op-start/scripts/op-status.sh --batch "{下游TID1},{下游TID2}" 跳过
```

回到循环顶部。

---

## 循环结束

- **全部完成**：检查 tech_debt.md，有未偿债项则提示 `/op-debt2tasks`
- **全部阻塞**：输出原因，等外部解除后 `/op-start`

## compact 恢复

1. 读 `RULES.md`
2. jq 查 tasks_list.json
3. 若有未归档 `tasks/{TID}/` 则从 context.md + review_*.md 重建状态，按步骤一状态判定表恢复
4. 重新选 task 进入循环

Sub Agent 每次重新 dispatch，不需要恢复 agent 实例。

## 相关文件

| 文件 | 用途 |
|---|---|
| `RULES.md` | 规则手册 |
| `RULES_DETAIL.md` | 操作细则 |
| `docs_template/omni_powers/` | 文档模板 |
| `skills/op-start/scripts/op-status.sh` | 状态流转 |
| `skills/op-start/scripts/op-read-verdict.sh` | verdict 读取 |
| `skills/op-start/scripts/close_check.sh` | 收口验收 |
| `skills/op-start/scripts/dag_gen.sh` | DAG 生成 |
| `skills/op-start/scripts/op-new-task.sh` | 工作区创建 |
| `skills/op-debt2tasks/SKILL.md` | 技术债偿还 |
