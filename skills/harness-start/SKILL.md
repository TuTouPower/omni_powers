---
name: harness-start
description: >
  统一工作流入口——用户只需 /harness-start，leader 进入自治循环：读状态 → 选 task → 派 coder → 等完成 → review → 收口 → 自动选下一个。
  循环只在两个点暂停（等 coder 完成、等 review 完成），其余全自动推进。
  触发：/harness-start、继续、下一步、干活。
---

# Harness Start Skill

`/harness-start` 是**启动按钮**，不是每步都要踩的离合器。

leader 读状态、确保 Agent Team 存在，然后进入自治循环。循环自动推进：选 task → 派 coder → 等完成 → review → 收口 → 选下一个。只在等外部（coder 回复、review 返回）时暂停，teammate 完成后系统自动唤醒 leader 继续循环。

**用户再触发 `/harness-start` 只在**：compact 恢复、crash 恢复、想查进度。

## 前置：创建 Agent Team

首次运行时**必须先创建 Agent Team**。参考：[Claude Code Agent Teams](https://code.claude.com/docs/en/agent-teams)。

```
# 1. 确保环境变量已设（一次性）
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1

# 2. settings.json 设 tmux 或者 auto 模式（可选，方便监控上下文）
"teammateMode": "tmux" / "auto"
```

**创建 team（spawn 三常驻 teammate）：**

```js
Agent({ name: "coder-1", subagent_type: "coder",
  prompt: "你是 coder。等待 leader 派 TDD 任务：读 spec/plan → 写测试 → 写实现 → 跑测试 → 追加 context.md → 报告完成。" })

Agent({ name: "code-reviewer", subagent_type: "code-reviewer",
  prompt: "你是 code-reviewer。等待 leader 派 review 任务：读 git diff + context.md → 审安全/架构/错误处理 → 写 review_code.md。" })

Agent({ name: "test-reviewer", subagent_type: "test-reviewer",
  prompt: "你是 test-reviewer。等待 leader 派 review 任务：读 tests/ + context.md → 判断测试是否能真发现 bug → 写 review_test.md。" })
```

spawn 后 teammate 在独立窗口中运行，idle 后自动通知 leader。后续用 SendMessage 派活，不重新 spawn。

## 核心原则

- **自治循环**。leader 进入循环后自动推进，不需要用户逐步触发
- **只在两个点暂停**：等 coder 完成、等 review 返回。teammate 完成后系统自动唤醒 leader
- **收口后自动选下一个 task**，不中断不等用户
- **compact 恢复只是入口**——恢复完直接进入循环

## 用到的工作流脚本

| 脚本 | 何时调 | 返回 |
|---|---|---|
| `docs/harness/workflows/task_review.js` | coder 完成后（主用） | 默认：`{passed, blockers, techDebt, finalVerdicts}`；autofix 模式额外含 `rounds, escalate` |
| `docs/harness/workflows/task_full.js` | 小独立 task 全自动（可选，默认不用） | `{passed, rounds, sharedFileNeeds, techDebt}` |

## 执行流程

### 阶段 0：读状态 + 确保 Agent Team 存在

**读三件套**：

1. `docs/harness_execution/leader_checkpoint.md` —— 上次断在哪
2. `docs/harness_execution/tasks_list.json` —— 状态源（以它为准）
   ⚠️ **此文件体积大，严禁 Read 整文件。** 必须用 `jq` 按需查询，例如 `jq '[.tasks[] | select(.status == "待开始")]' tasks_list.json`。
3. `docs/harness/agent_protocol.md` —— 规则手册

**确保 Agent Team 存在**：

- compact 前已有 teammate → SendMessage 唤醒，确认存活。活着的复用，死了的重 spawn。
- 全新启动（无 teammate）→ **必须先创建 Agent Team**：spawn coder-1、code-reviewer、test-reviewer（见"前置：创建 Agent Team"段）。
- compact 后 in-process teammate 已消失 → 重新 spawn。

> **不创建 team 不进循环。** 没有 teammate = 没有执行能力。

**状态判定**（决定进哪个步骤）：

| 条件 | 动作 |
|---|---|
| 所有 task status=完成 | → 阶段 6（ALL_DONE） |
| 存在 status=审阅中 | → 恢复循环步骤 5（等 review 返回） |
| 存在 status=进行中 | → 恢复循环步骤 3（等 coder 完成） |
| 存在可跑 task（待开始 + 依赖全完成） | → 进入自治循环步骤 1 |
| 全部阻塞 | → 输出阻塞原因，等外部解除 |

### 自治循环

进入循环后，leader 自动重复以下步骤，直到没有可跑 task。**一个循环迭代 = 一个波次**（串行时波次只有 1 个 task）。

```
while (存在待开始 task 且依赖全完成) {
  ┌─────────────────────────────────────────────────────────┐
  │ 1. 选波次（DAG 同层可并发 task，上限 3）               │
  │ 2. 派 coder（并发时同时 SendMessage 多个 coder-N）     │
  │ 3. await 所有 coder 完成  ← 暂停点（等最慢的）        │
  │ 4. review（并发时每个 worktree 独立调 task_review.js） │
  │ 5. await 所有 review 返回  ← 暂停点                   │
  │ 6. 处理结果（每个 task 独立 PASS/FAIL）                │
  │ 7. 收口（按依赖顺序合并 worktree，逐个收口）          │
  │ 8. 波次收口完成 → 自动进入下一波次                     │
  └─────────────────────────────────────────────────────────┘
}
→ 循环结束，跳到阶段 6
```

#### 步骤 1：选波次

用 jq 查待开始 task：

```bash
cat docs/harness_execution/tasks_list.json | jq '[.tasks[] | select(.status == "待开始")]'
```

**选 task 规则**（4 条全满足，取 ID 最小）：
1. status = 待开始
2. dependencies 全部 status = 完成
3. 不在阻塞项影响范围
4. ID 最小

**重算 DAG 层宽**（每次循环必做，不靠 checkpoint 记忆）：
1. 取所有 status≠完成 的 task
2. 拓扑分层：层 0 = 依赖全完成的
3. 层宽 = 1 → 串行；层宽 > 1 → 看共享文件交集定并发数（上限 3）

层宽决定本波次的 task 数。串行 = 1 个 task，1 个 coder-N；并发 = N 个 task，N 个 coder-N。

**输出**：
```
波次：{串行 / N 路并发}
  T{a} "{title}" → coder-1
  T{b} "{title}" → coder-2  (并发时)
  T{c} "{title}" → coder-3  (并发时)
```

#### 步骤 2：派 coder

**分配规则**：波次内按 TID 升序分配 `coder-1`、`coder-2`、`coder-3`。并发时每个 coder 在独立 worktree 工作。

```js
// 串行：只派 coder-1
SendMessage({ to: "coder-1", message: "TDD 实现 T{a}。spec: docs/harness_execution/tasks/{TID}/spec.md。plan: docs/harness_execution/tasks/{TID}/plan.md。完成后报告。" })

// 并发：同时派多个
// leader 先 git worktree add 为每个 task 创建独立目录，然后 SendMessage 到各自 worktree
SendMessage({ to: "coder-1", message: "在 worktree-{TID-a} 中 TDD 实现 T{a}..." })
SendMessage({ to: "coder-2", message: "在 worktree-{TID-b} 中 TDD 实现 T{b}..." })
```

tasks_list.json 波次内所有 task status → 进行中。

#### 步骤 3：等待 coder 完成（暂停点）

leader idle，等波次内**所有** coder 完成通知。**不需要用户介入，teammate 完成后系统自动唤醒 leader。**

- 串行：等 coder-1
- 并发：等最慢的 coder-N。先完成的 idle 等待，leader 收到全部完成通知后统一进入步骤 4

如果用户主动触发 `/harness-start`（查进度）：
```bash
cat docs/harness_execution/tasks/{TID}/steps.md  # 看 step 进度
```
输出 "波次中：T{a} step {k}/{total}，T{b} step {j}/{total}。coder 完成后自动进入 review。"

#### 步骤 4：review

波次内所有 coder 完成后，自动对每个 task 调 `task_review.js`。完成判断：coder 的 SendMessage 回复含 "完成"/"done" 关键词，且 `docs/harness_execution/tasks/{TID}/context.md` 非空、末尾有 "## 完成状态" 段。coder 报错/阻塞则 status → 阻塞，该 task 退出波次。

```js
// 串行
const result = await Workflow({
  scriptPath: "docs/harness/workflows/task_review.js",
  args: { taskId: "{TID}" }
})

// 并发：每个 worktree 内独立调，互不干扰
```

波次内所有 task status → 审阅中。

#### 步骤 5：等待 review 返回（暂停点）

leader idle，等波次内**所有** `task_review.js` workflow 返回。**不需要用户介入。**

- 串行：等一个 workflow
- 并发：等最慢的 workflow，先完成的 idle

如果用户主动触发 `/harness-start`（查进度）：
输出 "T{a} review 进行中，T{b} review 进行中。review 完成后自动处理结果。"

#### 步骤 6：处理 review 结果

读每个 workflow 返回的 `{passed, blockers, techDebt, finalVerdicts}`，不 grep review_*.md 正文。**每个 task 独立判定**。

- 双 PASS → 该 task 进入收口（步骤 7）
- 任一 FAIL → 该 task 进入 FAIL 轮（步骤 8）
- 波次内 PASS 和 FAIL 可以并存，各自独立处理

#### 步骤 7：收口

**按依赖顺序逐个收口**（并发时：先收口被依赖的 task，合并 worktree，每合一跑全量测试，再收口下一个）。

每个 task 的收口步骤：

1. **追加 progress.md**：`docs/harness_record/progress.md` 末尾追加 `## {TID} {title}` 段。commit hash 先写 `<待回填>`。

2. **有决策追加 decisions.md**：无决策跳过。

3. **追加 tech_debt.md**（强制）：从 workflow 返回的 `techDebt` 数组直接写，节标题 `## {TID} {title}`。无新增也写 `| {TID} | - | 无新增技术债 | - |`。节标题格式不可改（close_check.sh 用 `^## {TID}` 校验）。

4. **整理 docs/harness_blueprint/specs/{feature}.md**（强制）：判断归属 feature 文件，把当前生效规格整理进去。只留"现在是什么"。

5. **更新 tasks_list.json**：该 task status → 完成。

6. **归档 task spec 盖戳**：spec.md 顶部加 `> ⚠️ 历史快照，以 docs/harness_blueprint/specs/ 为准。`

7. **git mv 归档**：`git mv docs/harness_execution/tasks/{TID} docs/harness_record/tasks/{TID}`

8. **写 leader_checkpoint.md**：按模板更新所有段。

9. **git 提交**：**严禁 `git add -A`**。逐条判断归属本 task，只 add 本 task 文件。commit 格式：`{type}({TID}): {简述}`

10. **验收**：`bash docs/harness/skills/harness-start/scripts/close_check.sh {TID}`。非 0 拦截。

11. **回填 commit hash**：progress.md 和 leader_checkpoint.md 中 `<待回填>` → 实际 hash，单独 commit。

12. **波次全部收口完成 → 自动回到步骤 1，选下一波次。**

#### 步骤 8：FAIL 轮

- 第 1-2 轮 FAIL → `SendMessage({ to: "coder-N", message: "T{n} review FAIL。blockers: {...}。读 review_*.md 改代码，在 review_*.md 追加修改记录（禁碰 context.md），改完报告。" })`。coder 改完后**自动回到步骤 4 重调 `task_review.js`**（不需要用户介入）。
- 可选——全是 lint/小边界/类型错误且在 scope 内 → 重调 `task_review.js` 传 `autofix: { scopeFiles }`。
- 第 3 轮仍 FAIL → status=阻塞, blocked_by=quality，写 `issues/{TID}_quality.md`。**该 task 退出波次，波次内其他 task 继续收口。**
- 波次内所有 FAIL 轮处理完后 → 回到步骤 7 收口（PASS 的先收口，FAIL 的跳过）。

### 阶段 6：循环结束

循环结束后（无可跑 task），判断：

- **ALL_DONE**（所有 task 完成）：
  ```
  全部 task 已完成（n/n）。
  ```
  检查是否有未偿还技术债（`grep '^## T' docs/harness_execution/tech_debt.md`）：
  - 有未偿还债项 → "存在技术债。调 /debt-to-tasks 生成偿还 task。"
  - 无债项 → "全部完成，无待偿还技术债。"

- **剩余阻塞**：
  ```
  无可跑 task。阻塞项：
  T{n}: {blocked_by} - {desc}
  ...
  等外部解除后 /harness-start。
  ```

## Agent Team 生命周期

### 固定花名册（6 个 teammate）

| 名称 | 角色 | 数量 | 说明 |
|---|---|---|---|
| leader | 主会话 | 1 | 永远存在，不是 teammate |
| coder-1 | coder | 1-3 | 并发波次决定数量，串行只需 1 个 |
| coder-2 | coder | | 并发第 2 路才 spawn |
| coder-3 | coder | | 并发第 3 路才 spawn |
| code-reviewer | code-reviewer | 1 | 全局单实例，所有 task 共用 |
| test-reviewer | test-reviewer | 1 | 全局单实例，所有 task 共用 |

**通信**：`SendMessage({ to: "coder-1", message: "..." })`。teammate 之间不直接通信。

设 `teammateMode: "tmux"` 用 tmux 窗格，可 `tmux capture-pane` 读上下文占用率。

### Spawn（什么时候新建）

| 场景 | 动作 |
|---|---|
| 首次 /harness-start | spawn code-reviewer + test-reviewer + coder-1（串行） |
| 并发波次需要第 N 路 coder | spawn coder-N（N=2 或 3），不存在才建 |
| compact 后 in-process teammate 消失 | 按需重建（见"恢复"段） |
| tmux 模式 teammate 存活 | 不 spawn，SendMessage 唤醒 |

```js
// 首次启动
Agent({ name: "coder-1", subagent_type: "coder", prompt: "..." })
Agent({ name: "code-reviewer", subagent_type: "code-reviewer", prompt: "..." })
Agent({ name: "test-reviewer", subagent_type: "test-reviewer", prompt: "..." })

// 并发扩展（按需）
Agent({ name: "coder-2", subagent_type: "coder", prompt: "..." })
Agent({ name: "coder-3", subagent_type: "coder", prompt: "..." })
```

### 复用（什么时候唤醒，不重建）

| teammate | 唤醒条件 | 方式 |
|---|---|---|
| coder-N | 下一个 task 分配给它 | `SendMessage({ to: "coder-N", message: "TDD 实现..." })` |
| code-reviewer | 任何 task 进入 review | `SendMessage({ to: "code-reviewer", message: "review T{n}..." })` |
| test-reviewer | 任何 task 进入 review | `SendMessage({ to: "test-reviewer", message: "review T{n}..." })` |

**FAIL 轮**：一律唤醒原 coder-N（保留 spec/plan/上一轮代码上下文），不换人不重建。

### 清理（什么时候压缩上下文）

| teammate | 触发条件 | 动作 |
|---|---|---|
| coder-N | 当前 task 收口完成 + 上下文 ≥40%（1M 窗口） | shutdown，下次需要时重新 spawn |
| code-reviewer | 上下文 ≥70% | compact（不删除，压缩后继续用） |
| test-reviewer | 上下文 ≥70% | compact（不删除，压缩后继续用） |

> 200K 窗口的 coder：每次 task 收口完成直接 shutdown，不复用。

### 删除（什么时候 shutdown）

| 场景 | 动作 |
|---|---|
| coder-N 收口完成 + 无待跑 task 分配给它 | `SendMessage({ to: "coder-N", message: { type: "shutdown_request" } })` |
| 并发波次结束，coder-2/3 不再需要 | 同上 |
| 所有 task 完成（ALL_DONE） | shutdown code-reviewer + test-reviewer + 所有 coder-N |
| 循环结束，剩余阻塞 | shutdown 所有 coder-N，保留 code-reviewer/test-reviewer（解除阻塞后复用） |

### 恢复（compact 后）

1. 读 `leader_checkpoint.md` 中的 teammate 列表
2. tmux 模式 → SendMessage 唤醒，确认存活
3. in-process 模式 → 按需重新 spawn（只建当前循环需要的）
4. 恢复后从 spec/plan/context.md 重建上下文

## 相关文件

| 文件 | 用途 |
|---|---|
| `docs/harness/agent_protocol.md` | 规则手册，每次 /harness-start 必读 |
| `docs/harness_execution/tasks_list.json` | 状态源 |
| `docs/harness_execution/leader_checkpoint.md` | 断点 |
| `docs/harness/workflows/task_review.js` | review gate workflow 脚本（主用，含 autofix 模式） |
| `docs/harness/workflows/README.md` | workflow 接口手册 |
| `docs/harness/skills/harness-start/scripts/close_check.sh` | 收口验收脚本，收口后必跑 |
| `docs/harness/template/harness_execution/leader_checkpoint.md` | checkpoint 模板 |
| `docs/harness/skills/debt-to-tasks/SKILL.md` | 技术债偿还，全 done 后调用 |
