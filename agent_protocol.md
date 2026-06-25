# 多 Agent 协作工作流协议

> 规则手册——定义角色、状态机、文件分层、关键约束。执行流程见 skills 和 workflows。
> compact 恢复：`quick_ref.md` + `tasks_list.json` + `leader_checkpoint.md`。

## 角色

| 角色 | subagent_type | model | 职责 |
|---|---|---|---|
| leader | （主会话） | opus | 编排、收口、改共享文档 |
| coder | coder | haiku | TDD：写测试→写实现→跑测试→写 context.md |
| reviewer | code-reviewer | sonnet | 审 git diff + 安全/架构/错误处理，写 review_code.md |
| test-reviewer | test-reviewer | sonnet | 审测试是否真能发现问题，写 review_test.md |
| task-splitter | general-purpose | sonnet | **按需启用**：拆 task（建目录+切 spec/plan+改 tasks_list），不污染 leader 上下文 |

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
├── review_code.md    # reviewer 写 — coder 修改记录就近追加（只追加不覆盖）
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

## 关键规则

### review 判定

- task_review.js workflow 返回 `{passed, blockers, techDebt}`。leader 读返回值，不 grep review 正文。
- 双 PASS → 收口。任一 FAIL → FAIL 轮。
- **PASS 门槛**：能当场修的问题（不分 LOW/MEDIUM/HIGH）必须修完才 PASS。只有修不了的（跨 scope/依赖环境/需架构决策）才标暂存进 tech_debt。
- **FAIL 轮**（max 3）：leader 把 blockers 发回原 Teams coder → coder 改代码 + 在 review_*.md 追加修改记录（禁碰 context.md）→ 重调 task_review.js。coder 跨轮保留状态。第 3 轮仍 FAIL → status=阻塞, blocked_by=quality。

### commit 时机

**一个 task 一次 commit**。收口是 task 级语义动作——step 不收口、不单 commit。大到需多次收口 → 拆 task。WIP sub-commit 允许但脱钩收口（纯代码落盘，不改 status/不归档）。

### 并发与 worktree

- 波次 = DAG 同层所有可跑 task。层宽 1 → 串行；层宽 > 1 → 看共享文件交集定并发数（上限 3）。
- 隔离靠 leader 手动 `git worktree add`。不用 Workflow 的 `isolation:'worktree'`（粒度是 agent 不是 task）。
- 收口时按依赖顺序合并 worktree，每合一跑全量测试。

### teammate 管理

- idle = 可唤醒资源。FAIL 轮/新 review 一律 SendMessage 唤醒，不新 spawn。
- spawn 仅用于"全新 task + coder 上下文已满需重建"。
- coder 阈值：1M 窗口 ≥40% 重 spawn，200K 窗口每次重 spawn。reviewer 常驻复用，≥70% compact。

### tech_debt

只记修不了的问题（跨 scope/依赖环境/需架构决策/需未来 task）。能当场修的进 FAIL 轮，不进 tech_debt。每 task 闭环强制追加（无新增也写一行）。

### compact 恢复

恢复三件套：`quick_ref.md` + `tasks_list.json` + `leader_checkpoint.md`。**checkpoint 只给断点，不给调度结论**——恢复后必须重算 DAG 层宽。

## 阻塞项处理

| 类型 | blocked_by | 处理 |
|---|---|---|
| 外部密钥/凭据缺失 | `key` | 跳过，标阻塞 |
| 域名/外部端点缺失 | `domain` | 同上 |
| 3 轮 FAIL | `quality` | 写 issues/{TID}_quality.md，跳过 |
| spawn 失败 | `spawn` | 退避重试 2 次，仍败则标阻塞 |

回滚：`git revert <task_commit>` + 该 task 及下游 status 回 `待开始`。不用 reset。

## 执行体系（指向 skill/workflow）

协议的**操作**已固化到可执行文件。此处只列映射关系：

| 环节 | 谁做 | 协议段只记规则 |
|---|---|---|
| 需求→task | `/intake` | 先改 ref 再拆 task |
| 开发循环 | `/harness-start` | 状态机驱动，收口后自动选下一个 |
| review 判定 | `task_review.js` workflow | 双 review 并行 + schema verdict |
| 收口 | harness-start 收口段 | git add 禁 `-A`，跑 close_check.sh |
| 技术债偿还 | `/debt-to-tasks` | 功能 task 全 done 后触发 |
| spec 生成 | `/spec-gen`（或 intake 调用） | spec-generator skill |
| plan 生成 | `/plan-gen`（或 intake 调用） | plan-generator skill |

## 不做

- 不停下问用户（除非全部可跑 task 跑完仍剩阻塞）
- teammate 之间不直接通信
- 中间状态不 commit
