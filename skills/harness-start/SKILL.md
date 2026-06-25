---
name: harness-start
description: >
  统一工作流入口——用户每次回来只需 /harness-start。自动判断当前状态（刚 compact/选 task/coder 进度/review/收口/全 done）
  并执行对应动作，输出下一步。review 阶段调 task_review.js workflow 脚本自动化。收口自动衔接到选 task，形成闭环。
  触发：/harness-start、继续、下一步、干活。
---

# Harness Start Skill

用户每次回来只需一句话：`/harness-start`。skill 自己判断当前处于什么状态、该做什么、输出下一步。

## 核心原则

- **不让用户记流程**。状态判断、步骤衔接全由 skill 完成
- **收口后自动选下一个 task**，不中断等用户再发指令
- **compact 恢复只是入口**，不是独立阶段——恢复完直接进入工作流
- **review 走 Workflow 脚本**，不手工派 reviewer。`task_review.js` 返回结构化 `{passed, blockers, techDebt}`，leader 直接读返回值不 grep

## 状态机

```
                    compact/新开
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

`task_review.js` 是一个脚本两种模式：
- **默认**：`{ taskId }`，首审返回
- **autofix**：`{ taskId, autofix: { scopeFiles: [...] } }`，首审 FAIL 后走 scope 内小修 → 硬校验 → reverify

**调用方式**：
```js
// 默认
Workflow({ scriptPath: "docs/harness/workflows/task_review.js", args: { taskId: "T05" } })

// autofix（仅 FAIL 项全是 lint/断言/小边界/类型错误时用）
Workflow({ scriptPath: "docs/harness/workflows/task_review.js", args: { taskId: "T05", autofix: { scopeFiles: ["src/api/foo.py", "tests/api/test_foo.py"] } } })
```
> 必须在目标 task 的 worktree 内发起。并发时每个 worktree 单独调。

详细接口见 `docs/harness/workflows/README.md`。

## 执行流程

每步执行完后判断是否继续下一步，形成链式推进。

### 阶段 0：读状态

读三件套，判断当前处于哪个状态：

1. `docs/harness_execution/leader_checkpoint.md` —— 上次断在哪
2. `docs/harness_execution/tasks_list.json` —— 状态源（以它为准）
3. `docs/harness/agent_protocol.md` —— 编排逻辑（129 行，全量加载不贵）

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

**并发时**：leader 为每个并发 task `git worktree add` 独立工作目录，Teams coder 在各自 worktree 工作。

**输出**：
```
当前波次：{串行 / 2 路并发}，下一个 T{n} "{title}"
spec/plan 就位。下一步：派 coder，完成后 /harness-start。
```

### 阶段 3：CODING（检查 coder 进度）

```bash
ls docs/harness_execution/tasks/ | head          # 找进行中的 TID
cat docs/harness_execution/tasks/{TID}/steps.md  # 看 step 进度
```

读 checkpoint 查 team config 路径。

- **coder 还在跑** → SendMessage 唤醒确认进度。仍在进行中 → "T{n} step {k}/{total} 进行中。等 coder 完成报告后 /harness-start。"
- **coder 已完成**（context.md 非空且 tests/ 有改动）→ 自动调 `task_review.js` workflow：

```
T{n} coding 完成。调 task_review.js 自动化 review...
```

```js
const result = await Workflow({
  scriptPath: "docs/harness/workflows/task_review.js",
  args: { taskId: "{TID}" }
})
```

调用后 tasks_list.json 该 task status → 审阅中。

> 并发时：在目标 task 的 worktree 内发起 Workflow。脚本不用 isolation，共享 worktree 内 coder 未提交 diff。

### 阶段 4：REVIEW_PENDING

`task_review.js` workflow 正在跑。leader 无需动作，等返回：

```
T{n} review 进行中（task_review.js workflow 跑中）。完成后 /harness-start。
```

### 阶段 5：REVIEW_DONE（处理 review 结果）

读 workflow 返回的结构化结果（`{passed, blockers, techDebt, finalVerdicts}`），不 grep review_*.md 正文。

```
T{n} review 完成。结果：{PASS / FAIL}
```

**双 PASS → 进入收口（阶段 5a）**

**任一 FAIL → 进入 FAIL 轮（阶段 5b）**

#### 5a：收口

双 PASS 后自动执行收口。techDebt 从 workflow 返回值直接取，不 grep review 正文。

**收口步骤**：

1. **追加 progress.md**：`docs/harness_record/progress.md` 末尾追加 `## {TID} {title}` 段，含产物、测试结果、review 结论。commit hash 先写 `<待回填>`。

2. **有决策追加 decisions.md**：无决策跳过。

3. **追加 tech_debt.md**（强制）：从 workflow 返回的 `techDebt` 数组直接写 `docs/harness_execution/tech_debt.md`，节标题 `## {TID} {title}`。无新增也写一行 `| {TID} | - | 无新增技术债 | - | 本 task 所有问题当场修复 |`。节标题格式不可改（close_check.sh 用 `^## {TID}` 校验）。

4. **整理 docs/harness_blueprint/specs/{feature}.md**（强制）：判断本 task 归属哪个 feature 文件，把当前生效规格整理进去。只留"现在是什么"，去掉方案比较/被否方案。多 task 累积更新，不新建文件。

5. **更新 tasks_list.json**：该 task status → 完成。

6. **归档 task spec 盖戳**：spec.md 顶部加 `> ⚠️ 历史快照，以 docs/harness_blueprint/specs/ 为准。`

7. **git mv 归档**：`git mv docs/harness_execution/tasks/{TID} docs/harness_record/tasks/{TID}`

8. **写 leader_checkpoint.md**：按模板 `docs/harness/template/harness_execution/leader_checkpoint.md` 更新所有段（已完成 task、状态、team、compact 计数、DAG、关键上下文）。

9. **git 提交**：**严禁 `git add -A`**。逐条 `git status --short` 判断归属本 task，只 add 本 task 文件。commit 格式：`{type}({TID}): {简述}`

10. **验收**：`bash docs/harness/skills/harness-start/scripts/close_check.sh {TID}`。非 0 拦截，修正直到通过。

11. **回填 commit hash**：progress.md 和 leader_checkpoint.md 中 `<待回填>` → 实际 hash，单独 commit：`chore({TID}): 回填 commit hash`。

12. **收口完成后立即衔接到阶段 6。**

#### 5b：FAIL 轮

```
T{n} review FAIL。
blockers: {从 workflow 返回的 blockers 列表}
```

FAIL 轮处理（max 3 轮）：

- 第 1-2 轮 FAIL → SendMessage 唤醒原 Teams coder，发 blockers。coder 读 review_*.md 正文改代码，在同文件追加修改记录（禁碰 context.md）。coder 改完后 **leader 重调 `task_review.js`** 再审。
- 可选——FAIL 项全是 lint/测试断言/小边界/类型错误且在 scope 内 → 重调 `task_review.js` 传 `autofix: { scopeFiles }`（1 轮 autofix，超限自动 escalate 回 coder）。
- 第 3 轮仍 FAIL → 标 status=阻塞, blocked_by=quality，写 `issues/{TID}_quality.md`，跳到阶段 6。

> `task_review.js` 只做单轮判定，不做 FAIL 轮修复。跨轮计数由 leader 维护。

### 阶段 6：收口后自动选下一个

收口完成（或阻塞跳过）后，回到阶段 2 重算 DAG 选下一个 task。输出：

```
T{n} 收口完成，已 commit。
下一个：T{m} "{title}"（波次: {串行/n路并发}）
spec/plan 就位，派 coder 后 /harness-start。
```

## 并发场景

- 波次宽度 > 1 → leader 为每个 task `git worktree add` 独立工作目录
- 每个 worktree 内独立派 coder + 调 `task_review.js`
- 收口时按依赖顺序合并 worktree（每合一跑全量测试），再走收口步骤
- task 间隔离靠 git worktree，不靠 Workflow 的 `isolation` 参数

## teammate 管理

- **唤醒优先**：idle teammate 一律 SendMessage 唤醒，不新 spawn
- **spawn 条件**：仅"全新 task + coder 上下文已满需重建"
- **查 team config**：从 checkpoint 读 `~/.claude/teams/{team-name}/config.json`

## 相关文件

| 文件 | 用途 |
|---|---|
| `docs/harness/agent_protocol.md` | 规则手册 + 恢复最小集，每次 /harness-start 必读 |
| `docs/harness_execution/tasks_list.json` | 状态源 |
| `docs/harness_execution/leader_checkpoint.md` | 断点 |
| `docs/harness/agent_protocol.md` | 完整协议，按需查 |
| `docs/harness/workflows/task_review.js` | review gate workflow 脚本（主用，含 autofix 模式） |
| `docs/harness/workflows/README.md` | workflow 接口手册 |
| `docs/harness/skills/harness-start/scripts/close_check.sh` | 收口验收脚本，收口后必跑 |
| `docs/harness/template/harness_execution/leader_checkpoint.md` | checkpoint 模板 |
| `docs/harness/skills/debt-to-tasks/SKILL.md` | 技术债偿还，全 done 后调用 |
