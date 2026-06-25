---
name: harness-start
description: >
  统一工作流入口——用户只需 /harness-start，leader 进入自治循环：读状态 → 选 task → 派 coder → 等完成 → review → 收口 → 自动选下一个。
  循环只在两个点暂停（等 coder 完成、等 review 返回），其余全自动推进。
  触发：/harness-start、继续、下一步、干活。
---

# Harness Start Skill

`/harness-start` 是**启动按钮**，不是每步都要踩的离合器。

leader 读状态、确保 Agent Team 存在，然后进入自治循环。循环自动推进：选 task → 派 coder → 等完成 → review → 收口 → 选下一个。只在等外部（coder 回复、review 返回）时暂停，teammate 完成后系统自动唤醒 leader 继续循环。

**用户再触发 `/harness-start` 只在**：compact 恢复、crash 恢复、想查进度。

## 前置：创建 Agent Team

首次运行时**必须先创建 Agent Team**。

```
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```

**spawn 时必须显式传 model 参数**（不传则继承主会话模型，不是配置文件里的模型）：

```js
Agent({ name: "coder-1", subagent_type: "harness-coder", model: "haiku",
  prompt: "你是 coder。等待 leader 派 TDD 任务：读 spec/plan → 写测试 → 写实现 → 跑测试 → 追加 context.md → 报告完成。" })

Agent({ name: "code-reviewer", subagent_type: "harness-code-reviewer", model: "sonnet",
  prompt: "你是 code-reviewer。等待 leader 派 review 任务：读 git diff + context.md → 审安全/架构/错误处理 → 写 review_code.md，首行 verdict: PASS 或 verdict: FAIL。" })

Agent({ name: "test-reviewer", subagent_type: "harness-test-reviewer", model: "sonnet",
  prompt: "你是 test-reviewer。等待 leader 派 review 任务：读 tests/ + context.md → 判断测试是否能真发现 bug → 写 review_test.md，首行 verdict: PASS 或 verdict: FAIL。" })
```

spawn 后 teammate idle 自动通知 leader。后续用 SendMessage 派活，不重新 spawn。

## 核心原则

- **自治循环**。leader 进入循环后自动推进，不需要用户逐步触发
- **只在两个点暂停**：等 coder 完成、等 review 返回。teammate 完成后系统自动唤醒 leader
- **收口后自动选下一个 task**，不中断不等用户
- **compact 恢复只是入口**——恢复完直接进入循环
- **teammate 全程复用**，不监控上下文，不主动 shutdown（D5）
- **review 由 Agent Team 执行**，不用 Workflow（D4）

## 执行流程

### 阶段 0：读状态 + 确保 Agent Team 存在

**读三件套**：

1. `docs/harness_execution/leader_checkpoint.md` —— 上次断在哪
2. `docs/harness_execution/tasks_list.json` —— 状态源（以它为准）
   ⚠️ **此文件体积大，严禁 Read 整文件。** 必须用 `jq` 按需查询。
3. `docs/harness/agent_protocol.md` —— 规则手册

**确保 Agent Team 存在**：

- compact 前已有 teammate → SendMessage 唤醒，确认存活。活着的复用，死了的重 spawn。
- 全新启动（无 teammate）→ **必须先创建 Agent Team**（见"前置"段）。
- compact 后 in-process teammate 已消失 → 查 config 清残留 → 重新 spawn。

> **不创建 team 不进循环。** 没有 teammate = 没有执行能力。

**状态判定**（决定进哪个步骤）：

| 条件 | 动作 |
|---|---|
| 所有 task status=完成 | → 阶段 6（ALL_DONE） |
| 存在 status=审阅中 | → 恢复循环步骤 4（等 review 返回） |
| 存在 status=进行中 | → 恢复循环步骤 3（等 coder 完成） |
| 存在可跑 task（待开始 + 依赖全完成） | → 进入自治循环步骤 1 |
| 全部阻塞 | → 输出阻塞原因，等外部解除 |

### 自治循环

进入循环后，leader 自动重复以下步骤，直到没有可跑 task。**一个循环迭代 = 从选波次到该波次所有 task 收口完成**（串行时波次只有 1 个 task）。

```
while (存在待开始 task 且依赖全完成) {
  ┌─────────────────────────────────────────────────────────┐
  │ 1. 选波次（DAG 同层可并发 task，上限 3）               │
  │ 2. 派 coder（并发时同时 SendMessage 多个 coder-N）     │
  │ 3. 每个 coder 完成 → 立即派 review（事件驱动）        │
  │ 4. 每个 review 返回 → 立即处理结果 + 收口             │
  │ 5. 波次全部收口完成 → 自动进入下一波次                 │
  └─────────────────────────────────────────────────────────┘
}
→ 循环结束，跳到阶段 6
```

#### 步骤 1：选波次

用 jq 查待开始 task：

```bash
jq '[.tasks[] | select(.status == "待开始")]' docs/harness_execution/tasks_list.json
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
SendMessage({ to: "coder-1", message: "TDD 实现 T{a}。spec: docs/harness_execution/tasks/{TID}/spec.md。plan: docs/harness_execution/tasks/{TID}/plan.md。完成后报告。" })
```

tasks_list.json 波次内所有 task status → 进行中。

#### 步骤 3：coder 完成 → 立即 review（事件驱动）

**不等全波次完成。** 每个 coder 完成后，leader 立即对该 task 派 review。code-reviewer 单实例串行处理——先到先审，后到排队。

**完成判断**：coder 的 SendMessage 回复含 "完成"/"done" 关键词，且 `context.md` 非空、当前 Round 内含 "### 完成状态" 段。coder 报错/阻塞则 status → 阻塞，该 task 退出波次。

**review 派发**：
```js
// coder-1 完成，立即派 review（不等 coder-2/3）
SendMessage({ to: "code-reviewer", message: "review T{a}。worktree: {path}。git diff + context.md → 写 review_code.md。首行 verdict: PASS 或 FAIL。" })
SendMessage({ to: "test-reviewer", message: "review T{a} tests。worktree: {path}。读 tests/ + context.md → 写 review_test.md。首行 verdict: PASS 或 FAIL。" })
```

tasks_list.json 该 task status → 审阅中。leader idle，等 review 返回。**coder-2/3 如果还在跑，不受影响。**

#### 步骤 4：review 返回 → 立即处理 + 收口（事件驱动）

review 完成判断：`review_code.md` 和 `review_test.md` 都存在且首行含 `verdict:`。

leader 读每个 review_*.md **首行**，不 grep 正文。

**双 PASS → 立即收口（步骤 5）**

**任一 FAIL → 立即进 FAIL 轮**

#### 步骤 5：收口

**并发时按依赖顺序收口**：先收口被依赖的 task，合并 worktree，每合一跑全量测试，再收口下一个。无依赖关系的按 TID 升序。

每个 task 的收口步骤：

1. **追加 progress.md**：`docs/harness_record/progress.md` 末尾追加 `## {TID} {title}` 段。commit hash 先写 `<待回填>`。

2. **有决策追加 decisions.md**：无决策跳过。

3. **追加 tech_debt.md**（强制）：从 review_*.md 中提取标了"暂存"的项写入，节标题 `## {TID} {title}`。无新增也写 `| {TID} | - | 无新增技术债 | - |`。节标题格式不可改（close_check.sh 用 `^## {TID}` 校验）。

4. **整理 docs/harness_blueprint/specs/{feature}.md**（强制）：判断归属 feature 文件，把当前生效规格整理进去。只留"现在是什么"。

5. **更新 tasks_list.json**：该 task status → 完成。

6. **归档 task spec 盖戳**：spec.md 顶部加 `> ⚠️ 历史快照，以 docs/harness_blueprint/specs/ 为准。`

7. **git mv 归档**：`git mv docs/harness_execution/tasks/{TID} docs/harness_record/tasks/{TID}`

8. **写 leader_checkpoint.md**：按模板更新所有段。

9. **git 提交**：**严禁 `git add -A`**。逐条判断归属本 task，只 add 本 task 文件。commit 格式：`{type}({TID}): {简述}`

10. **验收**：`bash docs/harness/skills/harness-start/scripts/close_check.sh {TID}`。非 0 拦截。

11. **hash 回填**（延迟到下一个 task）：progress.md 和 leader_checkpoint.md 中的 `<待回填>` 在下一个 task 收口时一并回填并提交。一个 task 只有一次 commit。

#### 步骤 6：FAIL 轮

- 第 1-2 轮 FAIL → `SendMessage({ to: "coder-N", message: "T{n} review FAIL。blockers: {...}。读 review_*.md 改代码，在 review_*.md 追加修改记录（禁碰 context.md），改完报告。" })`。coder 改完后**立即重派 review**（不需要用户介入）。
- 第 3 轮仍 FAIL → status=阻塞, blocked_by=quality，写 `issues/{TID}_quality.md`。**该 task 退出波次，波次内其他 task 继续。**

**波次结束判断**：波次内所有 task 都收口完成（或阻塞退出）→ 自动回到步骤 1 选下一波次。

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

### Spawn（什么时候新建）

**⚠️ spawn 前必须先查 team config**：读 `~/.claude/teams/{team}/config.json` 的 `members` 列表。名字已在列表中 → 跳过 spawn，用 SendMessage 唤醒。名字不在列表中 → 才 spawn。

重复 spawn 同名会被自动加序号（`coder-1` → `coder-1-2`），导致 SendMessage 找不到人。

```bash
cat ~/.claude/teams/{team}/config.json | jq '.members[] | select(.name == "coder-1")'
# 有结果 → 跳过 spawn，SendMessage 唤醒
# 无结果 → spawn
```

| 场景 | 动作 |
|---|---|
| 首次 /harness-start | TeamCreate + spawn（显式传 model） |
| 并发波次需要第 N 路 coder | 查 config，不在列表中才 spawn coder-N |
| compact 后 teammate 消失 | 查 config 清残留 → spawn |

### 复用与 shutdown（D5）

teammate **全程复用**，不监控上下文，不主动 shutdown。上下文满了由 Claude Code 自动 compact/截断。

**仅在 teammate 完全无响应时 shutdown 重建**：
1. SendMessage 含 shutdown_request
2. 等回复
3. jq 清 config 残留
4. 重新 spawn

**FAIL 轮**：一律唤醒原 coder-N（保留跨轮状态），不换人不重建。

### 恢复（compact 后）

1. 读 `leader_checkpoint.md` 中的 teammate 列表
2. 查 team config：确认哪些还在、哪些 isActive=false
3. isActive=true → SendMessage 唤醒
4. isActive=false 或不存在 → 清残留 → spawn（显式传 model）
5. 从 spec/plan/context.md 重建上下文

## 相关文件

| 文件 | 用途 |
|---|---|
| `docs/harness/agent_protocol.md` | 规则手册 |
| `docs/harness/decisions.md` | 决策记录 |
| `docs/harness/findings.md` | 实验发现 |
| `docs/harness_execution/tasks_list.json` | 状态源 |
| `docs/harness_execution/leader_checkpoint.md` | 断点 |
| `docs/harness/skills/harness-start/scripts/close_check.sh` | 收口验收脚本 |
| `docs/harness/template/harness_execution/leader_checkpoint.md` | checkpoint 模板 |
| `docs/harness/skills/debt-to-tasks/SKILL.md` | 技术债偿还 |
