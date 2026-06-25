---
name: harness-start
description: >
  统一工作流入口——用户只需 /harness-start，leader 进入自治循环。
  触发：/harness-start、继续、下一步、干活。
---

# Harness Start Skill

`/harness-start` 是启动按钮。leader 读状态、确保 Agent Team 存在，进入自治循环自动推进。只在等外部（coder 完成、review 返回）时暂停。

**用户再触发 `/harness-start` 只在**：compact 恢复、crash 恢复、想查进度。

协议规则、状态机、review 判定、并发约束等见 `docs/harness/agent_protocol.md`。

## 步骤 0：读状态 + 确保 Agent Team

**读三件套**：

1. `docs/harness_execution/leader_checkpoint.md` —— 上次断在哪
2. `docs/harness_execution/tasks_list.json` —— 状态源（⚠️ 严禁 Read 整文件，必须用 jq 查询）
3. `docs/harness/agent_protocol.md` —— 规则手册

**确保 Agent Team 存在**（不创建 team 不进循环）：

- 已有 teammate → SendMessage 唤醒确认存活
- 无 teammate → TeamCreate + spawn（首次必须先创建，见下方"Spawn"段）
- compact 后消失 → 查 config 清残留 → 重新 spawn

**状态判定**：

| 条件 | 动作 |
|---|---|
| 所有 task status=完成 | → 循环结束 |
| 存在 status=审阅中 | → 恢复：等 review 返回 |
| 存在 status=进行中 | → 恢复：等 coder 完成 |
| 存在可跑 task（待开始 + 依赖全完成） | → 进入自治循环 |
| 全部阻塞 | → 输出阻塞原因，等外部解除 |

## 自治循环

```
while (存在待开始 task 且依赖全完成) {
  1. 选波次
  2. 拆 task（task 太大时）
  3. 派 coder
  4. coder 完成 → 立即派 review
  5. review 返回 → 立即处理结果
  6. 收口 → 自动下一波次
}
→ 循环结束
```

### 1. 选波次

```bash
jq '[.tasks[] | select(.status == "待开始")]' docs/harness_execution/tasks_list.json
```

选 task（4 条全满足，取 ID 最小）：status=待开始、依赖全完成、不在阻塞范围、ID 最小。

重算 DAG 层宽（每次必做，不靠 checkpoint）：拓扑分层 → 层宽决定串行/并发（上限 3）。

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

**派活**：leader 先读 plan 拆 steps.md（由 leader 维护进度），只给 coder 当前 step + 相关 spec 段，不给整份 plan。小 task 可一次给全 plan。

```js
SendMessage({ to: "coder-1", message: "在 {worktree_path} 中 TDD 实现 T{a} step {N}。spec: {path}/spec.md（相关段）。plan: {path}/plan.md（当前 step）。完成后报告。" })
```

tasks_list.json 波次内所有 task status → 进行中。

### 4. coder 完成 → 立即派 review（事件驱动）

**不等全波次完成。** 每个 coder 完成后立即派 review，先到先审。

完成判断：coder 回复含 "完成"/"done"，且 context.md 非空、当前 Round 含 "### 完成状态"。coder 报错/阻塞 → status=阻塞，退出波次。

```js
SendMessage({ to: "code-reviewer", message: "review T{a}。worktree: {path}。git diff + context.md → 写 review_code.md。首行 verdict: PASS 或 FAIL。" })
SendMessage({ to: "test-reviewer", message: "review T{a} tests。worktree: {path}。读 tests/ + context.md → 写 review_test.md。首行 verdict: PASS 或 FAIL。" })
```

tasks_list.json status → 审阅中。leader idle 等返回。

### 5. review 返回 → 处理结果（事件驱动）

review 完成判断：review_code.md 和 review_test.md 都存在且首行含 `verdict:`。

leader 读首行判定（不 grep 正文）。review 分类体系为 CRITICAL/HIGH/MEDIUM/LOW 四级，每条问题默认不暂存（当场修），满足暂存条件（跨 scope/需环境变更/架构决策/依赖未来 task）才标【暂存:原因】。

**双 PASS → 收口**（PASS 门槛：所有未标暂存的问题必须修完才 PASS，LOW 不是放过理由）

**任一 FAIL → FAIL 轮**

### 6. 收口

并发时按依赖顺序收口，先合被依赖的 task，每合一跑全量测试，全部合并完再做共享文档收口。合并冲突时：leader 读冲突段，按依赖优先规则解决（后者适配），解决后跑全量测试，冲突记录写入 decisions.md。

每个 task 的收口分两部分——closer 做机械读写，leader 做状态变更和提交：

**closer 执行（Subagent，一次性，不加入 team）**：
1. 追加 progress.md
2. 有决策追加 decisions.md
3. 提取 review_*.md 中标了【暂存】的项写入 tech_debt.md
4. 整理 specs/{feature}.md（读 task spec 全文，整理当前生效规格进功能 specs）
5. 归档 spec 盖戳
6. git mv 归档到 record/tasks/{TID}

```js
Agent({ name: "closer", subagent_type: "harness-closer", model: "haiku", prompt: "收口 T{n} \"{title}\"。暂存项：[{列表}。]决策：[{内容}。]specs 归属：{feature}。worktree: {path}。" })
```

**leader 执行（closer 回报后）**：
7. 更新 tasks_list.json：status → 完成
8. 写 leader_checkpoint.md
9. git 提交（严禁 `git add -A`，一个 task 一次 commit）
10. 验收：`bash docs/harness/skills/harness-start/scripts/close_check.sh {TID}`
11. hash 回填（延迟到下一个 task）

### 7. FAIL 轮

- 第 1-2 轮 FAIL → `SendMessage({ to: "coder-N", message: "T{n} review FAIL。blockers: {...}。读 review_*.md 改代码（只针对 blocker，不跑完整 TDD 循环，不扩展范围、不补写新测试），在 review_*.md 追加修改记录（禁碰 context.md），改完报告。" })`。coder 改完后**立即重派 review**
- 第 3 轮仍 FAIL → status=阻塞, blocked_by=quality，写 issues/{TID}_quality.md，退出波次
- **下游顺延**：FAIL task 的下游依赖自动顺延到下一波次

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
Agent({ name: "coder-1", subagent_type: "harness-coder", model: "haiku", prompt: "..." })
Agent({ name: "code-reviewer", subagent_type: "harness-code-reviewer", model: "sonnet", prompt: "..." })
Agent({ name: "test-reviewer", subagent_type: "harness-test-reviewer", model: "sonnet", prompt: "..." })
```

并发扩展：查 config 确认不存在后 `Agent({ name: "coder-2", subagent_type: "harness-coder", model: "haiku", prompt: "..." })`

### 复用与 shutdown

teammate 全程复用，不监控上下文，不主动 shutdown。上下文满了由 Claude Code 自动 compact。

仅在 teammate 完全无响应时 shutdown：SendMessage 含 shutdown_request → 等回复 → jq 清 config 残留 → 重新 spawn。

FAIL 轮唤醒原 coder-N（保留跨轮状态），不换人。

### compact 后恢复

1. 读 leader_checkpoint.md 的 teammate 列表
2. 查 team config：isActive=true → 唤醒；isActive=false → 清残留 → spawn
3. 从 spec/plan/context.md 重建上下文

## 相关文件

| 文件 | 用途 |
|---|---|
| `docs/harness/agent_protocol.md` | 规则手册 |
| `docs/harness/harness_decisions.md` | 决策记录 |
| `docs/harness/findings.md` | 实验发现 |
| `docs/harness_execution/tasks_list.json` | 状态源 |
| `docs/harness_execution/leader_checkpoint.md` | 断点 |
| `docs/harness/skills/harness-start/scripts/close_check.sh` | 收口验收脚本 |
| `docs/harness/skills/debt-to-tasks/SKILL.md` | 技术债偿还 |
