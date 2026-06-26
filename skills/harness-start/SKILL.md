---
name: harness-start
description: >
  统一工作流入口——用户只需 /harness-start，leader 进入自治循环。
  触发：/harness-start、继续、下一步、干活。
---

# Harness Start Skill

`/harness-start` 是启动按钮。leader 读状态、确保 Agent Team 存在，进入自治循环自动推进。只在等外部（coder 完成、review 返回）时暂停。

**用户再触发 `/harness-start` 只在**：compact 恢复、crash 恢复、想查进度。

协议规则、状态机、review 判定、并发约束等见 `agent_protocol.md`。

## 步骤 0：前置校验 + 读状态 + 确保 Agent Team

**Agent Teams 前置校验**：检查 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` 环境变量是否已设为 `1`。未设置则输出提示并退出：

```
[错误] Agent Teams 未启用。

请设置环境变量：export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
然后重新运行 /harness-start。
```

**禁止**自行修改用户配置文件。

**读三件套**：

1. `docs/harness_execution/leader_checkpoint.md` —— 上次断在哪
2. `docs/harness_execution/tasks_list.json` —— 状态源（⚠️ 严禁 Read 整文件，必须用 jq 查询）
3. `agent_protocol.md` —— 规则手册

**确保 Agent Team 存在**（不创建 team 不进循环）：

- 已有 teammate → SendMessage 唤醒确认存活
- 无 teammate → TeamCreate + spawn（首次必须先创建，见下方"Spawn"段）
- compact 后消失 → 查 config 清残留 → 重新 spawn

**状态判定**：

| 条件 | 动作 |
|---|---|
| 所有 task status=完成 | → 循环结束 |
| 存在 status=收口中 | → 恢复：从 checkpoint 判断 closer 完成否，未完成则重走收口 |
| 存在 status=审阅中 | → 恢复：等 review 返回 |
| 存在 status=进行中 | → 恢复：等 coder 完成 |
| 存在可跑 task（待开始 + 依赖全完成） | → 进入自治循环 |
| 全部阻塞/跳过 | → 输出阻塞原因，等外部解除 |

## 自治循环

```
while (存在 status 为 待开始/进行中/审阅中/收口中 的 task) {
  0. 按状态分发：
     收口中 → 恢复收口流程
     审阅中/进行中 → 扫标记文件 → 推进
     待开始 → 跳过（下面处理）
  1. 选波次
  2. 拆 task（task 太大时）
  3. 派 coder
  4. coder 完成 → 立即派 review
  5. review 返回 → 立即处理结果
  6. 收口 → 自动下一波次
}

→ 无 task 可推进（都在等）
  → ScheduleWakeup(180s) → 唤醒后跳回步骤 0
```

### 1. 生成 DAG + 选波次

**每次 /harness-start 从 `depends_on` 重算，不靠 checkpoint。**

```bash
bash skills/harness-start/scripts/dag_gen.sh
```
**失败处理**：exit 非 0 → 禁止继续。检查 stderr 信息，修复后重跑，直到通过才能进自治循环。

> 先用 `(.tasks[])` 生成全部节点（含状态），再用 `select(...length>0)` 生成边。depends_on 为 null 或空数组的任务不出边，但作为孤立节点出现在图中。依赖关系表列出所有 task。

**选 task**（4 条全满足，取 ID 最小）：status=待开始、`depends_on` 中所有 task 均为 `完成`、不在阻塞范围、ID 最小。

层宽 1 → 串行；层宽 > 1 → 同层并发（上限 3，>3 则取 ID 升序前 3，其余等下波次）。不做文件冲突预检，合并冲突在收口阶段解决。

### 2. 拆 task（task 太大时）

选中 task 后，读 plan 拆 steps.md。若发现"多个独立交付单元、各自需独立 review/回滚"，先拆再派。

**判断**：多改动各自需独立 review + 能独立回滚 → 拆。连贯交付一起 review → 不拆，一个 task 多 step。

**操作**：
1. leader 定边界（哪些 step 归子 task A、哪些归子 task B、依赖关系）
2. Subagent task-splitter 执行（建目录、切 spec/plan、改 tasks_list.json）
3. task-splitter 回报后，leader 按新 tasks_list 重走步骤 1

**不能等 coder 写一半再拆**——已落盘代码要回切会乱。

### 3. 派 coder

波次内按 TID 升序分配 coder-1/2/3。并发时每个 coder 在独立 worktree 工作。

**创建 worktree**：统一路径 `.worktrees/{TID}`，分支 `feat/{TID}`：

```bash
git worktree add .worktrees/{TID} -b feat/{TID}
```

**派活**：leader 先读 plan 拆 steps.md（由 leader 维护进度），只给 coder 当前 step + 相关 spec 段，不给整份 plan。小 task 可一次给全 plan。

**派活消息必须首行切绝对路径**（上一个 task 的 worktree 可能已删除，teammate cwd 是死路径）：

```js
SendMessage({ to: "coder-1", message: "cd <project_root>/.worktrees/{TID} && pwd\n在此目录中 TDD 实现 T{a} step {N}。spec: docs/harness_execution/tasks/{TID}/spec.md（相关段）。plan: docs/harness_execution/tasks/{TID}/plan.md（当前 step）。完成后报告。" })
```

tasks_list.json 波次内所有 task status → 进行中。

### 4. coder 完成 → 立即派 review（事件驱动）

**不等全波次完成。** 每个 coder 完成后立即派 review，先到先审。

完成判断：检查 `.worktrees/{TID}/.harness/signals/coder_done` 存在（唯一判定依据，详见 `agent_protocol.md` 通知机制）。coder 报错/阻塞 → status=阻塞，退出波次。

**leader 扫到标记文件 → 删 `coder_done` → 派 review：**

```js
SendMessage({ to: "code-reviewer", message: "cd <project_root>/.worktrees/{TID} && pwd\nreview T{a}。git diff + context.md → 写 review_code.md。首行 verdict: PASS 或 FAIL。" })
SendMessage({ to: "test-reviewer", message: "cd <project_root>/.worktrees/{TID} && pwd\nreview T{a} tests。读 tests/ + context.md → 写 review_test.md。首行 verdict: PASS 或 FAIL。" })
```

tasks_list.json status → 审阅中。leader idle 等返回。

### 5. review 返回 → 处理结果（事件驱动）

review 完成判断：`.worktrees/{TID}/.harness/signals/reviewer_code_done` 和 `reviewer_test_done` 同时存在（唯一判定依据）。leader 扫到两文件 → 删两文件 → 读 review_code.md 和 review_test.md 首行 verdict。

leader 读首行判定，按协议 review 规则处理（verdict/PASS 门槛/暂存标签/分类体系，详见 `agent_protocol.md`）。

**双 PASS → 收口**，**任一 FAIL → FAIL 轮**。

### 6. 收口

每个 task 独立 closer + 独立 commit。并发波次按依赖顺序收口：先合被依赖 task 的代码回主线。合并冲突时：leader 读冲突段，按依赖优先规则解决（后者适配），冲突记录写入 decisions.md。

每个 task 的收口分两部分——closer 做机械读写（步骤详见 `agents/harness-closer.md`），leader 做状态变更和提交：

**closer 执行（Subagent，一次性，不加入 team）**：

```js
Agent({ name: "closer", subagent_type: "harness-closer", model: "haiku", prompt: "cd <project_root>/.worktrees/{TID} && pwd\n收口 T{n} \"{title}\"。暂存项：[{列表}。]决策：[{内容}。]specs 归属：{feature}。" })
```

**leader 执行（closer 回报后，全程在 worktree 内操作）**：

> closer 的 `git add -A` 操作的是 worktree 的 index。leader 必须切到 worktree 再 commit，回主 repo 后看不到那些 staged 内容。

```
cd <project_root>/.worktrees/{TID} && pwd || { echo "[FAIL] 切 worktree 失败" >&2; exit 1; }

# 1. 更新 tasks_list.json：status → 完成
jq --arg tid "{TID}" '.tasks |= map(if .id == $tid then .status = "完成" else . end)' \
  docs/harness_execution/tasks_list.json > docs/harness_execution/tasks_list.json.tmp \
  && mv docs/harness_execution/tasks_list.json.tmp docs/harness_execution/tasks_list.json

# 2. 提交（closer 已 stage 全部产出）
git commit -m "feat({TID}): {title}"

# 3. 写 leader_checkpoint.md（当场写入 hash，不延迟）
HASH=$(git rev-parse HEAD)

# 更新 checkpoint：追加已完成 task 行 + 更新其他段
# （checkpoint 格式见 agent_protocol.md compact 恢复段）

# 4. 验收
bash skills/harness-start/scripts/close_check.sh {TID} || { echo "[FAIL] close_check 不通过" >&2; exit 1; }

# 切回主 repo → merge → 删 worktree → 选下个 task
cd <project_root> && pwd
git merge feat/{TID} --ff-only -m "merge({TID}): {title}"
# 并发波次用 --no-ff，串行用 --ff-only（协议约定）
git worktree remove .worktrees/{TID}
```

### 7. FAIL 轮

按协议 FAIL 轮规则执行（max 3 轮，下游顺延，详见 `agent_protocol.md`）。

- 第 1-2 轮 FAIL → `SendMessage({ to: "coder-N", message: "cd <project_root>/.worktrees/{TID} && pwd\nT{n} review FAIL。blockers: {...}。读 review_*.md 改代码（只针对 blocker），在 review_*.md 追加修改记录（禁碰 context.md），改完报告。" })`。coder 改完后**立即重派 review**
- 第 3 轮仍 FAIL → status=阻塞, blocked_by=quality，写 issues/{TID}_quality.md，退出波次

波次内所有 task 收口完成（或阻塞退出）→ 自动回到步骤 1。

## 循环结束

- **全部完成**：检查 tech_debt.md 有无未偿还债项，有则提示 /debt-to-tasks
- **剩余阻塞**：输出阻塞项，等外部解除后 /harness-start

## Agent Team 管理

### 花名册

| 名称 | 数量 | 说明 |
|---|---|---|
| coder-1/2/3 | 1-3 | 并发波次决定，串行只需 1 个 |
| code-reviewer | 1 | 全局单实例 |
| test-reviewer | 1 | 全局单实例 |

### Spawn

**spawn 前必须查 config**：同名 spawn 会被自动加序号。名字已在列表中 → SendMessage 唤醒，不在 → 才 spawn。

```bash
cat ~/.claude/teams/{team}/config.json | jq '.members[] | select(.name == "coder-1")'
# 有结果 → 唤醒，无结果 → spawn
```

首次启动：
```js
Agent({ name: "coder-1", team_name: "harness-{project}", subagent_type: "harness-coder", model: "haiku", prompt: "..." })
Agent({ name: "code-reviewer", team_name: "harness-{project}", subagent_type: "harness-code-reviewer", model: "sonnet", prompt: "..." })
Agent({ name: "test-reviewer", team_name: "harness-{project}", subagent_type: "harness-test-reviewer", model: "sonnet", prompt: "..." })
```

并发扩展：查 config 确认不存在后 `Agent({ name: "coder-2", team_name: "harness-{project}", subagent_type: "harness-coder", model: "haiku", prompt: "..." })`

### 复用与 shutdown

按协议 Agent Team 生命周期规则（详见 `agent_protocol.md`）。仅在 teammate 完全无响应时 shutdown。

### compact 后恢复

按协议 compact 恢复步骤（详见 `agent_protocol.md`）。

## 相关文件

| 文件 | 用途 |
|---|---|
| `agent_protocol.md` | 规则手册 |
| `harness_decisions.md` | 决策记录 |
| `findings.md` | 实验发现 |
| `docs/harness_execution/tasks_list.json` | 状态源 |
| `docs/harness_execution/leader_checkpoint.md` | 断点 |
| `skills/harness-start/scripts/close_check.sh` | 收口验收脚本 |
| `skills/debt-to-tasks/SKILL.md` | 技术债偿还 |
