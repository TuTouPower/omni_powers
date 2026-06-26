---
name: op-start
description: >
  统一工作流入口——用户只需 /op-start，leader 进入自治循环。
  触发：/op-start、继续、下一步、干活。
---
# Op Start Skill

`/op-start` 是启动按钮。leader 读状态、确保 Agent Team 存在，进入自治循环自动推进。只在等外部（coder 完成、review 返回）时暂停。

**用户再触发 `/op-start` 只在**：compact 恢复、crash 恢复、想查进度。

协议规则、状态机、review 判定、并发约束等见 `RULES.md`。

## 步骤 0：前置校验 + 读状态 + 确保 Agent Team

**Agent Teams 前置校验**：检查 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` 环境变量是否已设为 `1`。未设置则输出提示并退出：

```
[错误] Agent Teams 未启用。

请设置环境变量：export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
然后重新运行 /op-start。
```

**禁止**自行修改用户配置文件。

**读三件套**：

1. `docs/op_execution/leader_checkpoint.md` —— 上次断在哪
2. `docs/op_execution/tasks_list.json` —— 状态源（⚠️ 严禁 Read 整文件，必须用 jq 查询）
3. `RULES.md` —— 规则手册

**确保 Agent Team 存在**（不创建 team 不进循环）：

- 已有 teammate → SendMessage 唤醒确认存活
- 无 teammate → 先 TeamCreate 再 spawn

```js
// 查 config 确认 team 是否已存在
// 不存在则创建，team_name 用项目名避免冲突
TeamCreate({ team_name: "op-{project}-team", description: "omni_powers 开发团队" })
```

> TeamCreate 只需一次。后续 /op-start 查 config 发现 team 已存在就跳过，直接进入 spawn 检查。
>
> compact 后 teammate 可能消失 → 查 config 清残留 → 重新 spawn（不重建 team）

- compact 后消失 → 查 config 清残留 → 重新 spawn

**状态判定**：

| 条件                                 | 动作                                                        |
| ------------------------------------ | ----------------------------------------------------------- |
| 所有 task status=完成                | → 循环结束                                                 |
| 存在 status=收口中                   | → 恢复：从 checkpoint 判断 closer 完成否，未完成则重走收口 |
| 存在 status=审阅中                   | → 恢复：等 review 返回                                     |
| 存在 status=进行中                   | → 恢复：等 coder 完成                                      |
| 存在可跑 task（待开始 + 依赖全完成） | → 进入自治循环                                             |
| 全部阻塞/跳过                        | → 输出阻塞原因，等外部解除                                 |

## 自治循环

```
while (存在 status 为 待开始/进行中/审阅中/收口中 的 task) {
  0. 按状态分发：
     收口中 → 恢复收口流程
     审阅中/进行中 → for TID in 进行中+审阅中: op-scan-signals.sh {TID} → 推进
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

**每次 /op-start 从 `depends_on` 重算，不靠 checkpoint。**

```bash
bash skills/op-start/scripts/dag_gen.sh
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
SendMessage({ to: "coder-1", message: "cd <project_root>/.worktrees/{TID} && pwd\n在此目录中 TDD 实现 T{a} step {N}。spec: docs/op_execution/tasks/{TID}/spec.md（相关段）。plan: docs/op_execution/tasks/{TID}/plan.md（当前 step）。完成后报告。" })
```

```bash
# 波次内所有 task → 进行中
bash skills/op-start/scripts/op-status.sh --batch "{TID1},{TID2}" 进行中
```

### 4. coder 完成 → 立即派 review（事件驱动）

**不等全波次完成。** 每个 coder 完成后立即派 review，先到先审。

完成判断：`bash skills/op-start/scripts/op-scan-signals.sh {TID}` 输出 `coder_done` 即完成（唯一判定依据，详见 `RULES.md` 通知机制）。coder 报错/阻塞 → `bash skills/op-start/scripts/op-status.sh {TID} 阻塞 spawn`，退出波次。

**leader 扫到 coder_done → 删信号文件 → 更新状态 → 派 review：**

```bash
rm -f .worktrees/{TID}/.harness/signals/coder_done
bash skills/op-start/scripts/op-status.sh {TID} 审阅中
```

```js
SendMessage({ to: "code-reviewer", message: "cd <project_root>/.worktrees/{TID} && pwd\nreview T{a}。git diff + context.md → 写 review_code.md。首行 verdict: PASS 或 FAIL。" })
SendMessage({ to: "test-reviewer", message: "cd <project_root>/.worktrees/{TID} && pwd\nreview T{a} tests。读 tests/ + context.md → 写 review_test.md。首行 verdict: PASS 或 FAIL。" })
```

### 5. review 返回 → 处理结果（事件驱动）

review 完成判断：`bash skills/op-start/scripts/op-scan-signals.sh {TID}` 输出 `reviews_done` 即完成（唯一判定依据）。leader 扫到两文件 → 删除信号：

```bash
rm -f .worktrees/{TID}/.harness/signals/reviewer_code_done .worktrees/{TID}/.harness/signals/reviewer_test_done
```

然后读 verdict：

```bash
bash skills/op-start/scripts/op-read-verdict.sh {TID}
# exit 0 = PASS, exit 1 = FAIL
```

**双 PASS → 收口**：

```bash
bash skills/op-start/scripts/op-status.sh {TID} 收口中
```

**任一 FAIL → FAIL 轮**。

### 6. 收口

每个 task 独立收口。并发波次按依赖顺序：先合被依赖 task 的代码回主线。合并冲突时 leader 读冲突段，按依赖优先规则解决（后者适配），冲突记录写入 decisions.md。

leader 按以下 5 步串行执行：

**第 1 步：派 closer（sub agent）做机械归档**

closer 在 worktree 内做 spec 盖戳 + git mv 归档 + git add -A，输出 `.harness/signals/closer_output`。不碰 tasks_list.json / specs/ / progress.md / decisions.md / tech_debt.md。

```js
Agent({ name: "closer", subagent_type: "op-closer", model: "haiku", prompt: "cd <project_root>/.worktrees/{TID} && pwd\n收口 T{n} \"{title}\"。暂存项：[{列表}。]决策：[{内容}。]specs 归属：{feature}。" })
```

**第 2 步：leader 在 worktree 内提交代码**

```bash
cd <project_root>/.worktrees/{TID} && pwd || { echo "[FAIL] 切 worktree 失败" >&2; exit 1; }
git commit -m "feat({TID}): {title}"
```

**第 3 步：leader 切回主 repo，merge + 删 worktree**

```bash
cd <project_root> && pwd
git merge feat/{TID} --ff-only -m "merge({TID}): {title}"
# 并发波次用 --no-ff，串行用 --ff-only
git worktree remove .worktrees/{TID}
```

**第 4 步：leader 更新控制平面**（全部在主 repo 操作）

```bash
git status --short | grep -qv '^$' && { echo "[FAIL] 主 repo 不干净" >&2; exit 1; }

# 从 closer_output 读取 closer 产出（worktree 已删，提前读好了）
CLOSER_OUT=$(cat /tmp/closer_output_{TID})  # 第 1 步回报时存的

# 更新 tasks_list.json
bash skills/op-start/scripts/op-status.sh {TID} 完成

# 追加 progress.md / decisions.md / tech_debt.md（用 CLOSER_OUT 内容）
# 整理 specs/{feature}.md（CLOSER_OUT 中的 spec 摘要）

# 写 leader_checkpoint.md
HASH=$(git rev-parse HEAD)
```

**第 5 步：验收 + 提交控制平面**

```bash
bash skills/op-start/scripts/close_check.sh {TID} || { echo "[FAIL] close_check 不通过" >&2; exit 1; }

git add docs/op_execution/ docs/op_record/ docs/op_blueprint/
git commit -m "chore(harness): {TID} 收口记录"
```

### 7. FAIL 轮

按协议 FAIL 轮规则执行（max 3 轮，下游顺延，详见 `RULES.md`）。

- 第 1-2 轮 FAIL → `SendMessage({ to: "coder-N", message: "cd <project_root>/.worktrees/{TID} && pwd\nT{n} review FAIL。blockers: {...}。读 review_*.md 改代码（只针对 blocker），在 review_*.md 追加修改记录（禁碰 context.md），改完报告。" })`。coder 改完后**立即重派 review**
- 第 3 轮仍 FAIL → `bash skills/op-start/scripts/op-status.sh {TID} 阻塞 quality`，写 issues/{TID}_quality.md，退出波次

波次内所有 task 收口完成（或阻塞退出）→ **下游传播**：

```bash
# 阻塞 task 的所有下游 → 跳过
bash skills/op-start/scripts/op-status.sh --batch "{下游TID1},{下游TID2}" 跳过
```

→ 自动回到步骤 1。

## 循环结束

- **全部完成**：检查 tech_debt.md 有无未偿还债项，有则提示 /op-debt2tasks
- **剩余阻塞**：输出阻塞项，等外部解除后 /op-start

## Agent 类型

omni_powers 用两种 Agent，`Agent()` 调用时用 `team_name` 区分：

**Agent Team 成员（平等，无 `team_name` ≠ Sub Agent）**：

- SendMessage 互发消息，独立上下文，独立进程
- 调用：`Agent({ name: "...", team_name: "op-{project}-team", subagent_type: "op-xxx" })`

**Sub Agent（父子，无 `team_name`）**：

- 继承主 Agent 上下文，只和主 Agent 通信，不能和 teammate 互发消息
- 调用：`Agent({ name: "...", subagent_type: "op-xxx" })`  —— 注意**没有 `team_name`**

### 花名册

| 名称          | 类型                | 数量 | 说明                              |
| ------------- | ------------------- | ---- | --------------------------------- |
| leader        | Team Leader         | 1    | 永远在主会话，不 spawn            |
| coder-1/2/3   | Team 成员           | 1-3  | 并发波次决定，串行只需 1 个       |
| code-reviewer | Team 成员           | 1    | 全局单实例                        |
| test-reviewer | Team 成员           | 1    | 全局单实例                        |
| closer        | **Sub Agent** | 按需 | 收口时临时 spawn，完成即消失      |
| task-splitter | **Sub Agent** | 按需 | task 太大时临时 spawn，完成即消失 |

### Spawn

**spawn 前必须查 config**：同名 spawn 会被自动加序号。名字已在列表中 → SendMessage 唤醒，不在 → 才 spawn。

```bash
cat ~/.claude/teams/{team}/config.json | jq '.members[] | select(.name == "coder-1")'
# 有结果 → 唤醒，无结果 → spawn
```

**team_name 约定**：`op-{项目目录名}-team`。从当前项目根目录名自动提取，避免多项目间冲突。

**Team 成员 spawn**（首次启动，team 不存在时 `步骤 0` 已创建）：

```js
Agent({ name: "coder-1", team_name: "op-{project}-team", subagent_type: "op-coder", model: "haiku", prompt: "就绪，等待 leader 派 task。" })
Agent({ name: "code-reviewer", team_name: "op-{project}-team", subagent_type: "op-code-reviewer", model: "sonnet", prompt: "就绪，等待 review 任务。" })
Agent({ name: "test-reviewer", team_name: "op-{project}-team", subagent_type: "op-test-reviewer", model: "sonnet", prompt: "就绪，等待 test review 任务。" })
```

并发扩展：查 config 确认不存在后 spawn。

```js
Agent({ name: "coder-2", team_name: "op-{project}-team", subagent_type: "op-coder", model: "haiku", prompt: "就绪，等待 leader 派 task。" })
```

**Sub Agent 调用**（无 `team_name`，临时工，用即弃）：

```js
// 收口时（步骤 6）
Agent({ name: "closer", subagent_type: "op-closer", model: "haiku", prompt: "cd <project_root>/.worktrees/{TID} && pwd\n收口..." })

// 拆 task 时（步骤 2）
Agent({ name: "splitter", subagent_type: "op-task-splitter", model: "haiku", prompt: "cd <project_root> && pwd\n拆分..." })
```

> Sub Agent 不挂 team，不回 SendMessage，只返回结果给 leader。

按协议 Agent Team 生命周期规则（详见 `RULES.md`）。仅在 teammate 完全无响应时 shutdown。

### compact 后恢复

按协议 compact 恢复步骤（详见 `RULES.md`）。

## 相关文件

| 文件                                           | 用途         |
| ---------------------------------------------- | ------------ |
| `RULES.md`                                   | 规则手册     |
| `op_decisions.md`                            | 决策记录     |
| `op_findings.md`                             | 实验发现     |
| `docs/op_execution/tasks_list.json`          | 状态源       |
| `docs/op_execution/leader_checkpoint.md`     | 断点         |
| `skills/op-start/scripts/close_check.sh`     | 收口验收     |
| `skills/op-start/scripts/op-status.sh`       | 状态流转     |
| `skills/op-start/scripts/op-scan-signals.sh` | 信号扫描     |
| `skills/op-start/scripts/op-read-verdict.sh` | verdict 读取 |
| `skills/op-start/scripts/op-new-task.sh`     | 工作区创建   |
| `skills/op-start/scripts/dag_gen.sh`         | DAG 生成     |
| `skills/op-debt2tasks/SKILL.md`              | 技术债偿还   |
