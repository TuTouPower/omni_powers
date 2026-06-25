# 多 Agent 协作工作流协议

> 规则手册——定义角色、状态机、文件分层、关键约束。执行流程见 skills。
> compact 恢复：直接读本文件 + `tasks_list.json` + `leader_checkpoint.md`。
> 决策依据见 `docs/harness/decisions.md`，实验记录见 `docs/harness/findings.md`。

## 角色

| 角色 | 类型 | model | 职责 |
|---|---|---|---|
| leader | 主会话 | — | 编排、收口、改共享文档 |
| coder-1/2/3 | **Agent Team** | haiku | TDD：写测试→写实现→跑测试→写 context.md |
| code-reviewer | **Agent Team** | sonnet | 审 git diff + 安全/架构/错误处理，写 review_code.md |
| test-reviewer | **Agent Team** | sonnet | 审测试是否真能发现问题，写 review_test.md |
| task-splitter | **Subagent** | sonnet | 按需启用：拆 task，不污染 leader 上下文 |

### 为什么用 Agent Team

- 跨 task 存活，上下文复用，不每次重填（D4, D5）
- FAIL 轮唤醒同一实例，保留 spec/plan/上一轮代码上下文
- compact 后 teammate 消失需重 spawn，但 context.md/ review_*.md 在文件系统，恢复不丢

### 为什么 task-splitter 用 Subagent

- 一次性操作：建目录→切 spec/plan→改 tasks_list→回报消失
- 无需持久，无需 FAIL 轮，无需跨 task 复用
- 中间内容不污染 leader 上下文

## 状态机

```
待开始 → 进行中 → 审阅中 → 完成
                ↑        ↓ (FAIL，max 3 轮)
                └────────┘
                第 3 轮仍 FAIL → 阻塞(blocked_by=quality)
```

tasks_list.json status 值：

| status | 含义 | blocked_by |
|---|---|---|
| `待开始` | spec/plan 就位，未开发 | null |
| `进行中` | coder 开发或修复轮中 | null |
| `审阅中` | review 进行中 | null |
| `完成` | 双 PASS + 收口提交 | null |
| `阻塞` | 3 轮 FAIL 或环境阻塞 | `key`/`domain`/`quality`/`spawn`（必有值） |

## 文件分层

### task 工作区（全部进 git，不删）

```
docs/harness_execution/tasks/{TID}/
├── spec.md           # spec-generator 生成
├── plan.md           # plan-generator 生成
├── steps.md          # leader 维护的 step 进度
├── context.md        # coder 每 step 完成追加正向进度。FAIL 轮不碰
├── review_code.md    # code-reviewer 写 — coder 修改记录就近追加（只追加不覆盖）
└── review_test.md    # test-reviewer 写 — 同上
```

- context.md = 构建边界（正向进度），review_*.md = 质量边界（FAIL 来回）。二者不重叠。
- task 闭环后 git mv 到 `docs/harness_record/tasks/{TID}/` 归档。

### 持久文件

| 路径 | 谁写 | 何时 |
|---|---|---|
| `docs/harness_execution/tasks_list.json` | leader | 状态流转 |
| `docs/harness_blueprint/specs/{feature}.md` | leader | 每 task 闭环整理（当前生效规格，按功能聚合） |
| `docs/harness_record/progress.md` | leader | 闭环后追加 |
| `docs/harness_record/decisions.md` | leader | 有架构决策才追加 |
| `docs/harness_execution/tech_debt.md` | leader | 闭环后追加 |
| `docs/harness_execution/leader_checkpoint.md` | leader | 每 task 闭环后写 |

### specs/ 机制

当前真相在 `docs/harness_blueprint/specs/{feature}.md`，按功能聚合。task 闭环时把当前生效规格整理进去，只留"现在是什么"，不留方案比较/被否方案。归档 task spec 顶部盖戳冻结。

**新建文件规则**：一律先拷 `docs/harness/template/` 下对应模板再填内容。无对应模板才自建。

## 关键规则

### review 判定

review 由 Agent Team 执行（D4），不用 Workflow。

- leader SendMessage 派 code-reviewer 和 test-reviewer 并行 review
- code-reviewer 写 `review_code.md`，test-reviewer 写 `review_test.md`
- 每个 review_*.md 首行必须是 `verdict: PASS` 或 `verdict: FAIL`
- leader 读首行判定，不 grep 正文
- 双 PASS → 收口。任一 FAIL → FAIL 轮。
- **PASS 门槛**：能当场修的问题（不分 LOW/MEDIUM/HIGH）必须修完才 PASS。只有修不了的（跨 scope/依赖环境/需架构决策）才标暂存进 tech_debt。
- **FAIL 轮**（max 3）：leader 把 blockers 发回原 coder-N → coder-N 改代码 + 在 review_*.md 追加修改记录（禁碰 context.md）→ leader 重派 review。coder-N 跨轮保留状态。第 3 轮仍 FAIL → status=阻塞, blocked_by=quality。

### commit 时机

**一个 task 一次 commit**。收口是 task 级语义动作——step 不收口、不单 commit。大到需多次收口 → 拆 task。WIP sub-commit 允许但脱钩收口（纯代码落盘，不改 status/不归档）。

### 并发与 worktree

- 波次 = DAG 同层所有可跑 task。层宽 1 → 串行；层宽 > 1 → 看共享文件交集定并发数（上限 3）。
- 隔离靠 leader 手动 `git worktree add`。
- 收口时按依赖顺序合并 worktree，每合一跑全量测试。波次全部收口后开下一波次。

### Agent Team 管理

coder-1/2/3、code-reviewer、test-reviewer 是 **Agent Team**——用 `Agent` 工具 spawn，跨 task 常驻。

**创建**（首次 /harness-start 时，必须显式传 model 参数）：

```
Agent({ name: "coder-1", subagent_type: "harness-coder", model: "haiku",
  prompt: "等待 leader 派 TDD 任务..." })

Agent({ name: "code-reviewer", subagent_type: "harness-code-reviewer", model: "sonnet",
  prompt: "等待 leader 派 review 任务..." })

Agent({ name: "test-reviewer", subagent_type: "harness-test-reviewer", model: "sonnet",
  prompt: "等待 leader 派 review 任务..." })
```

**通信**：`SendMessage(to: "coder-N", message: "...")`。teammate 之间不直接通信。

**生命周期**（D5）：
- teammate 全程复用，不主动 shutdown，不监控上下文
- 上下文满了由 Claude Code 自动 compact/截断
- idle 后不消失，SendMessage 即可唤醒。FAIL 轮发回原 teammate，保留跨轮状态
- **shutdown 仅用于 teammate 完全无响应**：SendMessage 含 shutdown_request → 等回复 → 清 config 残留
- **spawn 前必须查 config**：名字已存在则唤醒，不存在才 spawn。同名 spawn 会被自动加序号

**compact 后恢复**：teammate 消失需重 spawn。恢复前查 config.json，isActive=false 的先清残留再 spawn。恢复后从 spec/plan/context.md 重建上下文。

> 首次使用需设 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`。参考：[Agent Teams](https://code.claude.com/docs/en/agent-teams)

### tech_debt

只记修不了的问题（跨 scope/依赖环境/需架构决策/需未来 task）。能当场修的进 FAIL 轮，不进 tech_debt。每 task 闭环强制追加（无新增也写一行）。

### compact 恢复

compact 后直接读本文件 + `tasks_list.json` + `leader_checkpoint.md`。

**checkpoint 只给断点，不给调度结论**——恢复后必须重算 DAG 层宽，不能吃 checkpoint 惯性。

## 阻塞项处理

| 类型 | blocked_by | 处理 |
|---|---|---|
| 外部密钥/凭据缺失 | `key` | 跳过，标阻塞 |
| 域名/外部端点缺失 | `domain` | 同上 |
| 3 轮 FAIL | `quality` | 写 issues/{TID}_quality.md，跳过 |
| spawn 失败 | `spawn` | 退避重试 2 次，仍败则标阻塞 |

回滚：`git revert <task_commit>` + 该 task 及下游 status 回 `待开始`。不用 reset。

## 执行体系（指向 skill）

协议的**操作**已固化到 skill。此处只列映射关系：

| 环节 | 谁做 | 协议段只记规则 |
|---|---|---|
| 需求→task | `/intake` | 先改 ref 再拆 task |
| 开发循环 | `/harness-start` | 自治循环，收口后自动选下一个 |
| review | Agent Team（code-reviewer + test-reviewer） | 双 review 并行，leader 读 verdict |
| 收口 | harness-start 收口段 | git add 禁 `-A`，跑 close_check.sh |
| 技术债偿还 | `/debt-to-tasks` | 功能 task 全 done 后触发 |
| spec 生成 | `/spec-gen`（或 intake 调用） | spec-generator skill |
| plan 生成 | `/plan-gen`（或 intake 调用） | plan-generator skill |

## 不做

- 不停下问用户（除非全部可跑 task 跑完仍剩阻塞）
- teammate 之间不直接通信
- 中间状态不 commit
