---
name: harness-start
description: >
  统一工作流入口——用户每次回来只需 /harness-start。自动判断当前状态（刚 compact/选 task/coder 进度/review/收口/全 done）
  并执行对应动作，输出下一步。review 阶段调 task_review.js workflow 脚本自动化。收口自动衔接到选 task，形成闭环。
  触发：/harness-start、继续、下一步、干活。
---

# Harness Start Skill

用户每次回来只需一句话：`/harness-start`。skill 自己判断当前处于什么状态、该做什么、输出下一步。

## 前置：创建 Agent Team

首次运行 `/harness-start` 时，**必须先创建 Agent Team**。参考：[Claude Code Agent Teams](https://code.claude.com/docs/en/agent-teams)。

```
# 1. 确保环境变量已设（一次性）
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1

# 2. settings.json 设 tmux 模式（可选，方便监控上下文）
"teammateMode": "tmux"
```

**创建 team（spawn 三常驻 teammate）：**

```js
// 同时 spawn 三个 teammate，各自在独立窗口中运行
Agent({ name: "coder", subagent_type: "coder",
  prompt: "你是 coder。等待 leader 派 TDD 任务：读 spec/plan → 写测试 → 写实现 → 跑测试 → 追加 context.md → 报告完成。" })

Agent({ name: "reviewer", subagent_type: "code-reviewer",
  prompt: "你是 reviewer。等待 leader 派 review 任务：读 git diff + context.md → 审安全/架构/错误处理 → 写 review_code.md。" })

Agent({ name: "test-reviewer", subagent_type: "test-reviewer",
  prompt: "你是 test-reviewer。等待 leader 派 review 任务：读 tests/ + context.md → 判断测试是否能真发现 bug → 写 review_test.md。" })
```

spawn 后 teammate 在独立窗口中运行，idle 后自动通知 leader。后续用 SendMessage 派活，不重新 spawn。

## 核心原则

- **不让用户记流程**。状态判断、步骤衔接全由 skill 完成
- **收口后自动选下一个 task**，不中断等用户再发指令
- **compact 恢复只是入口**，不是独立阶段——恢复完直接进入工作流
- **review 走 Workflow 脚本**。`task_review.js` 返回结构化 `{passed, blockers, techDebt}`，leader 直接读返回值

## 状态机

```
                    compact/新开
                         │
                         ▼
                  创建 Agent Team（如未存在）
                         │
                         ▼
                   ┌─ 选 task ──→ 派 coder ──→ 调 task_review.js ──┐
                   │                                                 │
                   │           ┌── FAIL 轮 ←──┐                     │
                   │           │  (coder 改后重调 task_review.js)    │
                   │           │              │                     │
                   └── 收口 ←──┴── PASS ←── review 完成 ───────────┘
                         │
                         ▼
                      全 done → 提示 /debt-to-tasks
```

## 用到的工作流脚本

| 脚本 | 何时调 | 返回 |
|---|---|---|
| `docs/harness/workflows/task_review.js` | coder 完成后（主用） | 默认：`{passed, blockers, techDebt, finalVerdicts}`；autofix 模式额外含 `rounds, escalate` |
| `docs/harness/workflows/task_full.js` | 小独立 task 全自动（可选，默认不用） | `{passed, rounds, sharedFileNeeds, techDebt}` |

## 执行流程

每步执行完后判断是否继续下一步，形成链式推进。

### 阶段 0：读状态 + 确保 Agent Team 存在

**读三件套**：

1. `docs/harness_execution/leader_checkpoint.md` —— 上次断在哪
2. `docs/harness_execution/tasks_list.json` —— 状态源（以它为准）
   ⚠️ **此文件体积大，严禁 Read 整文件。** 必须用 `jq` 按需查询，例如 `jq '[.tasks[] | select(.status == "待开始")]' tasks_list.json`。
3. `docs/harness/agent_protocol.md` —— 规则手册

**确保 Agent Team 存在**：

- compact 前已有 teammate → SendMessage 唤醒，确认存活。活着的复用，死了的重 spawn。
- 全新启动（无 teammate）→ **必须先创建 Agent Team**：spawn coder、reviewer、test-reviewer 三个 teammate（见"前置：创建 Agent Team"段）。
- compact 后 in-process teammate 已消失 → 重新 spawn。

> **不创建 team 不进工作流。** 没有 teammate = 没有执行能力。

**状态判定规则**（按优先级，命中即停）：

| 条件 | 状态 |
|---|---|
| 所有 task status=完成 | `ALL_DONE` |
| 存在 status=审阅中 且 review_*.md 已有 verdict 首行 | `REVIEW_DONE` |
| 存在 status=审阅中 且 review_*.md 不存在或无 verdict | `REVIEW_PENDING` |
| 存在 status=进行中 | `CODING` |
| 存在 status=待开始（依赖全完成） | `READY` |
| 存在 status=阻塞 | `BLOCKED` + 跳过阻塞项继续查 |

### 阶段 1：ALL_DONE

```
全部 task 已完成（n/n）。
```

检查是否有未偿还技术债（`grep '^## T' docs/harness_execution/tech_debt.md`）：

- 有未偿还债项 → "存在技术债。调 /debt-to-tasks 生成偿还 task。"
- 无债项 → "全部完成，无待偿还技术债。"

### 阶段 2：READY（选 task + 重算 DAG）

用 jq 查待开始 task：

```bash
cat docs/harness_execution/tasks_list.json | jq '[.tasks[] | select(.status == "待开始")]'
```

**选 task 规则**（4 条全满足，取 ID 最小）：
1. status = 待开始
2. dependencies 全部 status = 完成
3. 不在阻塞项影响范围
4. ID 最小

**重算 DAG 层宽**（每次必做，不靠 checkpoint 记忆）：
1. 取所有 status≠完成 的 task
2. 拓扑分层：层 0 = 依赖全完成的
3. 层宽 = 1 → 串行；层宽 > 1 → 看共享文件交集定并发数（上限 3）

**并发时**：leader 为每个并发 task `git worktree add` 独立工作目录，每个 worktree 内独立派 coder。

**输出**：
```
当前波次：{串行 / 2 路并发}，下一个 T{n} "{title}"
spec/plan 就位。派 coder 中...
```

**选完 task 立即派 coder**：

```js
SendMessage({ to: "coder", message: "TDD 实现 T{n}。spec: docs/harness_execution/tasks/{TID}/spec.md。plan: docs/harness_execution/tasks/{TID}/plan.md。完成后报告。" })
```

tasks_list.json 该 task status → 进行中。

### 阶段 3：CODING（检查 coder 进度）

```bash
ls docs/harness_execution/tasks/ | head          # 找进行中的 TID
cat docs/harness_execution/tasks/{TID}/steps.md  # 看 step 进度
```

- **coder 还在跑** → SendMessage(to: "coder", ...) 确认进度。仍在进行中 → "T{n} step {k}/{total} 进行中。等 coder 完成后 /harness-start。"
- **coder 已完成**（context.md 非空且 tests/ 有改动）→ 调 `task_review.js`：

```js
const result = await Workflow({
  scriptPath: "docs/harness/workflows/task_review.js",
  args: { taskId: "{TID}" }
})
```

调用后 tasks_list.json 该 task status → 审阅中。

> 并发时：在目标 task 的 worktree 内发起 Workflow。

### 阶段 4：REVIEW_PENDING

`task_review.js` workflow 正在跑。leader 无需动作：

```
T{n} review 进行中（task_review.js workflow 跑中）。完成后 /harness-start。
```

### 阶段 5：REVIEW_DONE（处理 review 结果）

读 workflow 返回的 `{passed, blockers, techDebt, finalVerdicts}`，不 grep review_*.md 正文。

**双 PASS → 收口（阶段 5a）**

**任一 FAIL → FAIL 轮（阶段 5b）**

#### 5a：收口

双 PASS 后自动执行收口。techDebt 从 workflow 返回值直接取。

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

12. **收口完成后立即衔接到阶段 6。**

#### 5b：FAIL 轮

- 第 1-2 轮 FAIL → `SendMessage({ to: "coder", message: "T{n} review FAIL。blockers: {...}。读 review_*.md 改代码，在 review_*.md 追加修改记录（禁碰 context.md），改完报告。" })`。coder 改完重调 `task_review.js`。
- 可选——全是 lint/小边界/类型错误且在 scope 内 → 重调 `task_review.js` 传 `autofix: { scopeFiles }`。
- 第 3 轮仍 FAIL → status=阻塞, blocked_by=quality，写 `issues/{TID}_quality.md`，跳到阶段 6。

### 阶段 6：收口后自动选下一个

回到阶段 2 重算 DAG 选下一个 task。输出：

```
T{n} 收口完成，已 commit。
下一个：T{m} "{title}"（波次: {串行/n路并发}）
派 coder 后 /harness-start。
```

## 并发场景

- 波次宽度 > 1 → leader 为每个 task `git worktree add` 独立工作目录
- 每个 worktree 内独立派 coder + 调 `task_review.js`
- 收口时按依赖顺序合并 worktree（每合一跑全量测试），再走收口步骤

## Agent Team 生命周期

> 参考：[Claude Code Agent Teams](https://code.claude.com/docs/en/agent-teams)

**spawn**：用 Agent tool 创建 teammate，`name` 命名，`subagent_type` 指定角色：

```js
Agent({ name: "coder", subagent_type: "coder", prompt: "..." })
Agent({ name: "reviewer", subagent_type: "code-reviewer", prompt: "..." })
Agent({ name: "test-reviewer", subagent_type: "test-reviewer", prompt: "..." })
```

teammate 在独立窗口中运行。设 `teammateMode: "tmux"` 用 tmux 窗格，可 `tmux capture-pane` 读上下文占用率。

**通信**：`SendMessage({ to: "coder", message: "..." })`。teammate 之间不直接通信。

**生命周期**：
- idle = 可唤醒资源。FAIL 轮/新 review 一律 SendMessage 唤醒，不新 spawn。
- spawn 仅用于"全新 task + coder 上下文已满需重建"。
- coder 阈值：1M 窗口 ≥40% 重 spawn，200K 窗口每次重 spawn。reviewer/test-reviewer 常驻复用，≥70% compact。
- compact 恢复：in-process teammate 已消失→重新 spawn；tmux 模式 teammate 存活→SendMessage 唤醒。

**关机**：全部 task 完成后告知 teammate 关闭：`SendMessage({ to: "coder", message: { type: "shutdown_request" } })`。

> 首次使用需设 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` 环境变量。

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
