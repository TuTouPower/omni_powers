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

## 步骤一：校验 + 读状态 + 确保 Agent Team

### 1.1 校验

检查 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` 是否已设为 `1`。未设置则输出：

```
[错误] Agent Teams 未启用。
请设置环境变量：export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
然后重新运行 /op-start。
```

**禁止**自行修改用户配置文件。

### 1.2 读状态

```bash
# 上次断在哪
cat docs/op_execution/leader_checkpoint.md

# 当前 task 状态（⚠️ 严禁 Read 整文件，用 jq 查）
jq '[.tasks[] | {id, status, depends_on}]' docs/op_execution/tasks_list.json

# 规则手册（compact 恢复必读）
cat RULES.md
```

### 1.3 确保 Agent Team

**Agent Team 成员** vs **Sub Agent**：

| 类型 | 区分 | 通信 | 上下文 |
|---|---|---|---|
| Agent Team 成员 | 有 `team_name` | SendMessage 互发 | 独立 |
| Sub Agent | 无 `team_name` | 同步返回给 leader | 继承 leader |

先查 team 是否存在，不存在则创建：

```js
TeamCreate({ team_name: "op-{project}-team", description: "omni_powers 开发团队" })
// {project} = 当前项目根目录名，避免多项目冲突
// 已存在 → 跳过
```

team 存在后，查成员并 spawn：

```bash
cat ~/.claude/teams/op-{project}-team/config.json | jq '.members[] | select(.name == "coder")'
# 有结果 → SendMessage 唤醒
# 无结果 → spawn
```

compact 后 teammate 可能消失 → 查 config 清残留 → 重新 spawn（不重建 team）。

**花名册**：

| 名称 | 类型 | 数量 | spawn 命令 |
|---|---|---|---|
| coder | Team 成员 | 1 | `Agent({ name: "coder", team_name: "op-{project}-team", subagent_type: "op-coder", model: "haiku", prompt: "就绪，等待 leader 派 task。" })` |
| code-reviewer | Team 成员 | 1 | `Agent({ name: "code-reviewer", team_name: "op-{project}-team", subagent_type: "op-code-reviewer", model: "sonnet", prompt: "就绪，等待 review 任务。" })` |
| test-reviewer | Team 成员 | 1 | `Agent({ name: "test-reviewer", team_name: "op-{project}-team", subagent_type: "op-test-reviewer", model: "sonnet", prompt: "就绪，等待 test review 任务。" })` |
| closer | Sub Agent | 按需 | `Agent({ name: "closer", subagent_type: "op-closer", model: "haiku", prompt: "cd .../worktrees/{TID} && pwd\n收口..." })` |

> closer 无 `team_name`，同步返回，只在收口时临时 spawn。

### 1.4 状态判定

| 条件 | 动作 |
|---|---|
| 全部 status=完成 | 循环结束 |
| 存在 status=收口中 | 从 checkpoint 恢复，跳到收口子步骤 |
| 存在 status=审阅中/进行中 | 进入循环，先扫标记 |
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

### 标记文件机制

每次循环顶部先扫标记：

| 文件 | 谁写 | 含义 |
|---|---|---|
| `.worktrees/{TID}/.harness/signals/coder_done` | coder | 代码写完 |
| `.worktrees/{TID}/.harness/signals/reviewer_code_done` | code-reviewer | 代码审查完成 |
| `.worktrees/{TID}/.harness/signals/reviewer_test_done` | test-reviewer | 测试审查完成 |

> closer 是 sub agent（同步返回），不需要标记文件。

标记规则：
- **标记文件是唯一真相源**。teammate 先 touch 文件再 SendMessage——文件先落盘，消息丢了也能恢复
- **不主动轮询**。只在循环顶部扫一次，扫不到就 ScheduleWakeup 等
- teammate 完成工作后 idle，leader 靠 ScheduleWakeup 醒来扫文件。SendMessage 是派活通道，不是通知通道
- **teammate 连续 3 次 SendMessage 无回复** → shutdown → 重 spawn

### 循环流程

```
进入循环
    │
    ▼
  扫标记文件
  for TID in 进行中+审阅中: op-scan-signals.sh {TID}
    │
    ├─ 有 coder_done → 删标记文件 → 进入子步骤 3.2（派 review）
    │
    ├─ 有 reviews_done → 删两标记文件 → 读 verdict
    │     ├─ 最后一条 verdict 为 PASS → 进入子步骤 3.4（收口）
    │     └─ 最后一条 verdict 为 FAIL → 进入子步骤 3.5（FAIL 轮）
    │
    └─ 皆无标记
        ├─ 有可跑 task → 进入子步骤 3.1（派 coder）
        └─ 无 task 可跑 → ScheduleWakeup(180s) → 唤醒后回到循环顶部
```

### 子步骤 3.1：派 coder

```bash
git worktree add .worktrees/{TID} -b feat/{TID}
```

**派活**：只给 coder 当前 step + 相关 spec 段，不给整份 plan。小 task 可一次给全。

首行必须切绝对路径（上一个 task 的 worktree 可能已删除，teammate cwd 是死路径）：

```js
SendMessage({ to: "coder", message: "cd <project_root>/.worktrees/{TID} && pwd\n在此目录 TDD 实现 T{n} step {N}。完成后 touch coder_done 标记文件。" })
```

```bash
bash skills/op-start/scripts/op-status.sh {TID} 进行中
```

回到循环顶部。

### 子步骤 3.2：派 review

扫到 `coder_done` 后立即派 review：

```bash
rm -f .worktrees/{TID}/.harness/signals/coder_done
bash skills/op-start/scripts/op-status.sh {TID} 审阅中
```

```js
SendMessage({ to: "code-reviewer", message: "cd <project_root>/.worktrees/{TID} && pwd\nreview T{n}。git diff + context.md → 写 review_code.md。首行 verdict: PASS 或 FAIL。FAIL 时每条问题标等级（CRITICAL/HIGH/MEDIUM/LOW），默认不暂存。重审时在末尾纯追加 ### Round N verdict: PASS/FAIL，不覆盖已有行。完成后 touch reviewer_code_done 标记文件。" })
SendMessage({ to: "test-reviewer", message: "cd <project_root>/.worktrees/{TID} && pwd\nreview T{n} tests。读 tests/ + context.md → 写 review_test.md。首行 verdict: PASS 或 FAIL。重审时在末尾纯追加 ### Round N verdict: PASS/FAIL，不覆盖已有行。完成后 touch reviewer_test_done 标记文件。" })
```

回到循环顶部。

### 子步骤 3.3：处理 review 结果

扫到 `reviews_done` 后：

```bash
rm -f .worktrees/{TID}/.harness/signals/reviewer_code_done .worktrees/{TID}/.harness/signals/reviewer_test_done
```

```bash
bash skills/op-start/scripts/op-read-verdict.sh {TID}
# exit 0 = 最后一条 verdict 为 PASS, exit 1 = FAIL
```

> reviewer 重审时在 review_*.md 末尾**纯追加** `### Round N verdict: PASS/FAIL`，不覆盖已有行。leader 读**最后一条** verdict 行判定。

- **双 PASS** → `bash skills/op-start/scripts/op-status.sh {TID} 收口中`，进入子步骤 3.4
- **任一 FAIL** → 进入子步骤 3.5

### 子步骤 3.4：收口

leader 串行执行以下 5 小步：

#### 3.4.1 派 closer（sub agent，同步等待）

```js
Agent({ name: "closer", subagent_type: "op-closer", model: "haiku", prompt: "cd <project_root>/.worktrees/{TID} && pwd\n收口 T{n} \"{title}\"。暂存项：[{列表}。]决策：[{内容}。]specs 归属：{feature}。" })
```

closer 做 spec 盖戳 + git mv 归档 + git add -A。不碰 tasks_list.json / specs/ / progress.md / decisions.md / tech_debt.md。leader 保存 closer 返回的内容供后续用。

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

# 用 closer 返回的内容追加 progress.md / decisions.md / tech_debt.md
# 整理 specs/{feature}.md

HASH=$(git rev-parse HEAD)
# checkpoint 格式见 template/op_execution/leader_checkpoint.md
```

#### 3.4.5 验收 + 提交

```bash
bash skills/op-start/scripts/close_check.sh {TID} || { echo "[FAIL] close_check 不通过" >&2; exit 1; }

git add docs/op_execution/ docs/op_record/ docs/op_blueprint/
git commit -m "chore(harness): {TID} 收口记录"
```

回到循环顶部。

### 子步骤 3.5：FAIL 轮

max 3 轮。

**第 1-2 轮 FAIL**：

```bash
# 先确保三个标记文件已清空
rm -f .worktrees/{TID}/.harness/signals/coder_done \
      .worktrees/{TID}/.harness/signals/reviewer_code_done \
      .worktrees/{TID}/.harness/signals/reviewer_test_done
```

```js
SendMessage({ to: "coder", message: "cd <project_root>/.worktrees/{TID} && pwd\nT{n} review FAIL。blockers: {...}。读 review_*.md 改代码——只针对 blocker 改实现和补测试，不扩展到 blocker 之外的新行为和新测试。在 review_*.md 末尾追加修改记录（禁碰 context.md）。改完 touch coder_done 标记文件。" })
```

coder 改完 → 回到循环顶部，下一轮扫到 coder_done 再重派 review。reviewer 在 review_*.md 末尾**纯追加** `### Round N verdict: PASS/FAIL`，不覆盖已有行。leader 读**最后一条** verdict 行判定。

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
3. **清理残留标记**：compact 后旧标记文件不可信。所有进行中/审阅中 task 的 `signals/` 目录清空，从 context.md / review_*.md 重建状态
4. 查 teammate 存活，消失则重新 spawn
5. 按步骤一 1.4 状态判定表恢复

## 相关文件

| 文件 | 用途 |
|---|---|
| `RULES.md` | 规则手册 |
| `RULES_DETAIL.md` | 操作细则 |
| `template/` | 文档模板 |
| `skills/op-start/scripts/op-status.sh` | 状态流转 |
| `skills/op-start/scripts/op-scan-signals.sh` | 标记扫描 |
| `skills/op-start/scripts/op-read-verdict.sh` | verdict 读取 |
| `skills/op-start/scripts/close_check.sh` | 收口验收 |
| `skills/op-start/scripts/dag_gen.sh` | DAG 生成 |
| `skills/op-start/scripts/op-new-task.sh` | 工作区创建 |
| `skills/op-debt2tasks/SKILL.md` | 技术债偿还 |
