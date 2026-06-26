# 多 Agent 协作工作流协议

> **唯一编排依据**——所有编排决策以本协议为准。执行流程见 skills。
> compact 恢复：读本文件 + 用 jq 查询 `tasks_list.json`（⚠️ 严禁 Read 整文件）+ 读 `leader_checkpoint.md`。
> 操作细则见 `RULES_DETAIL.md`，决策依据见 `docs/op_decisions.md`，实验记录见 `docs/op_findings.md`。
>
> **核心心智模型**：磁盘是真状态，所有 agent 上下文都是可重建缓存。全线使用 Sub Agent——每次 fresh dispatch，无跨 task 状态残留。

## 角色

| 角色          | 类型       | model  | 职责                                                                                                |
| ------------- | ---------- | ------ | --------------------------------------------------------------------------------------------------- |
| leader        | 主会话     | —     | 编排、收口、改共享文档                                                                              |
| op-coder       | Sub Agent | haiku  | TDD：写测试→写实现→跑测试→写 context.md                                                          |
| op-code-reviewer | Sub Agent | sonnet | 审 git diff + 安全/架构/错误处理，写 review_code.md                                                 |
| op-test-reviewer | Sub Agent | sonnet | 审测试是否真能发现问题，写 review_test.md                                                           |
| op-closer        | Sub Agent | haiku  | 按需启用：per-task 收口（spec 盖戳、git mv 归档、git add -A），输出 closer_output。不碰控制平面文件 |

全线 Sub Agent（D15）。每次 task 重新 dispatch，上下文隔离，无跨 task 残留。

## 状态机

```
待开始 → 进行中 → 审阅中 → 收口中 → 完成
                ↑        ↓ (FAIL，max 3 轮)
                └────────┘
                第 3 轮仍 FAIL → 阻塞(blocked_by=quality)
```

tasks_list.json status 值：

| status     | 含义                                        | blocked_by                                         |
| ---------- | ------------------------------------------- | -------------------------------------------------- |
| `待开始` | spec/plan 就位，未开发                      | null                                               |
| `进行中` | op-coder 开发或修复轮中                        | null                                               |
| `审阅中` | review 进行中                               | null                                               |
| `收口中` | 双 PASS 后，op-closer 执行中，leader commit 前 | null                                               |
| `完成`   | commit + close_check 通过                   | null                                               |
| `阻塞`   | 3 轮 FAIL 或环境阻塞                        | `key`/`domain`/`quality`/`spawn`（必有值） |
| `跳过`   | 因下游阻塞顺延，等待阻塞解除                | null                                               |

**英文/中文映射**（compact 恢复、跨文档引用时对照）：

| 英文（状态机/日志） | 中文（tasks_list.json） |
| ------------------- | ----------------------- |
| pending             | 待开始                  |
| coding              | 进行中                  |
| reviewing           | 审阅中                  |
| closing             | 收口中                  |
| done                | 完成                    |
| blocked             | 阻塞                    |
| skipped             | 跳过                    |

状态修改：`bash skills/op-start/scripts/op-status.sh <TID> <status> [blocked_by]`（详见 `RULES_DETAIL.md`）。

## 文件分层

### task 工作区（全部进 git，不删）

```
docs/op_execution/tasks/{TID}/
├── spec.md           # op-generate-spec 生成
├── plan.md           # op-generate-plan 生成
├── steps.md          # leader 维护的 step 进度
├── context.md        # op-coder 每 step 完成追加正向进度。FAIL 轮不碰
├── review_code.md    # op-code-reviewer 写 — op-coder 修改记录就近追加（只追加不覆盖）
└── review_test.md    # op-test-reviewer 写 — 同上
```

- context.md = 构建边界（正向进度），review_*.md = 质量边界（FAIL 来回）。二者不重叠——读者、时机、内容不重叠，重审不跨文件找。review 文档是审计痕迹，全部进 git、永不删，记录 op-coder 改了什么、为什么不改、review 哪里误判。
- task 闭环后 git mv 到 `docs/op_record/tasks/{TID}/` 归档。
- `docs/op_execution/issues/{TID}_quality.md` 记录质量阻塞（3 轮 FAIL）和 spawn 失败等阻塞原因。

### 持久文件（控制平面——仅 leader 在主 repo 写）

| 路径                                       | 谁写   | 何时                                                |
| ------------------------------------------ | ------ | --------------------------------------------------- |
| `docs/op_execution/tasks_list.json`      | leader | 状态流转（含 tasks 数组和 blockers 数组）           |
| `docs/op_blueprint/specs/{feature}.md`   | leader | 每 task 闭环整理（当前生效规格，按功能聚合）        |
| `docs/op_record/progress.md`             | leader | 闭环后追加                                          |
| `docs/op_record/decisions.md`            | leader | 有架构决策才追加                                    |
| `docs/op_execution/tech_debt.md`         | leader | 闭环后追加                                          |
| `docs/op_execution/leader_checkpoint.md` | leader | 每 task 闭环后写                                    |
| `docs/op_execution/dag.md`               | leader | 每次 /op-start 从 depends_on 重算生成               |
| `docs/op_blueprint/spec.md`              | leader | 全局总纲 + specs/ 目录索引，需求变更时改            |
| `docs/index.md`                          | leader | 文档导航总图（三态模型 + 目录索引），结构变动时同步 |

### specs/ 机制

当前真相在 `docs/op_blueprint/specs/{feature}.md`，按功能聚合。task 闭环时把当前生效规格整理进去，只留"现在是什么"，不留方案比较/被否方案。归档 task spec 顶部盖戳冻结——归档后的 task spec 是历史快照，会过时；当前代码"是什么"靠 specs/ 文件。

**整理规则**：每 task 闭环时，leader 必须把 task spec 里当前生效的接口、数据模型、约束、行为整理进对应功能 specs 文件——不是拷贝，过程性内容留在归档 task spec。同一功能跨多个 task 时累积更新同一个文件，不为后续 task 新建文件。归档后永不再改。

**新建文件规则**：一律先拷 `template/` 下对应模板再填内容。无对应模板才自建。

## 关键规则

### review 判定

- leader 派 op-code-reviewer 和 op-test-reviewer 为后台 Sub Agent 并行 review（D15）
- op-code-reviewer 写 `review_code.md`，op-test-reviewer 写 `review_test.md`
- 每个 review_*.md 首行必须是 `verdict: PASS` 或 `verdict: FAIL`
- leader 读首行判定，不 grep 正文
- 双 PASS → 收口。任一 FAIL → FAIL 轮。
- **分类体系**：CRITICAL / HIGH / MEDIUM / LOW 四级
- **暂存标签**：每条问题默认不暂存（当场修）。需要暂存时标【暂存:原因】。暂存条件：跨 scope / 需环境变更 / 架构决策 / 依赖未来 task
- **PASS 门槛**：所有未标暂存的问题必须修完才 PASS。LOW 不是放过理由。
- **reviewer 出错处理**：后台 Sub Agent 出错时，只重试失败的那个（max 3），已成功的保留结果等待。重试仍失败则对应 review 文件手动写 `verdict: FAIL`，进入 FAIL 轮。
- **FAIL 轮**（max 3）：leader 派新 op-coder Sub Agent（含 blockers + review 文件路径）→ 改代码（只针对 blocker 改实现和补测试，不扩展到 blocker 之外的新行为和新测试）+ 在 review_*.md 追加修改记录（禁碰 context.md）→ leader 重派 review。**重审后**：reviewer 在 review_*.md 末尾追加 `### Round {N} verdict: PASS` 或 `### Round {N} verdict: FAIL`（纯追加，不覆盖已有 verdict 行）。leader 读**最后一条** verdict 行判定。第 3 轮仍 FAIL → status=阻塞, blocked_by=quality，写 `issues/{TID}_quality.md`。**下游传播**：FAIL task 的下游依赖 task status 改为 `跳过`，等待阻塞解除后恢复。

### commit 时机

**一个 task 两个 commit**。一次 task commit（仅代码平面），一次 control plane commit（控制平面收口记录）。

**代码平面**（per-task，不冲突，进 feat 分支）：

- `src/`、`tests/` — op-coder 产出
- `docs/op_execution/tasks/{TID}/` — task 工作区
- 归档目录 `docs/op_record/tasks/{TID}/` — op-closer 归档

**控制平面**（全局共享，仅 leader 在主 repo 串行写，永不进 feat 分支）：

- `tasks_list.json` — 状态源
- `leader_checkpoint.md` — 断点
- `docs/op_blueprint/` — 按需更新：specs/{feature}.md（每 task 累积）、prd.md、architecture.md、domain.md、conventions.md、spec.md 等
- `progress.md`、`decisions.md`、`tech_debt.md` — 记录

收口分两阶段：(A) op-closer 在 worktree 做 per-task 操作 → leader commit 代码提交 → merge 回主线；(B) leader 在主 repo 串行更新控制平面文件 → control plane commit。

### DAG 与 depends_on

每个 task 的 `depends_on` 记录其前置依赖（数组，无依赖则 `null`）。**所有新增 task 的入口**（op-task、op-debt2tasks）都必须填 `depends_on`。

每次 `/op-start` 从 `depends_on` 重算拓扑分层，生成 `docs/op_execution/dag.md`（Mermaid 图 + 分层表），给人看。dag.md 是衍生文件，不存 checkpoint。

### 工作区与 worktree

task 串行执行，一次只跑一个 task。每个 task 在独立 git worktree 中开发：

```bash
git worktree add .worktrees/{TID} -b feat/{TID}
```

收口时 `git merge feat/{TID} --ff-only` 合回主线，然后 `git worktree remove .worktrees/{TID}`。

**控制平面文件仅在主 repo 由 leader 串行写**——op-closer 和 feat 分支不碰 tasks_list.json / specs/ / progress.md / decisions.md / tech_debt.md / leader_checkpoint.md。

### Agent 派发

全线 Sub Agent（D15）。leader 每次 dispatch 新的 Sub Agent：

**op-coder**（前台，一次一个）：
```js
Agent({ name: "op-coder", subagent_type: "op-coder", model: "haiku",
  prompt: "cd <project_root>/.worktrees/{TID} && pwd\nTDD 实现 T{n}。..." })
```

**op-code-reviewer + op-test-reviewer**（后台，并行两个）：
```js
Agent({ name: "op-code-reviewer", subagent_type: "op-code-reviewer", model: "sonnet",
  background: true,
  prompt: "cd <project_root>/.worktrees/{TID} && pwd\nreview T{n}。..." })
Agent({ name: "op-test-reviewer", subagent_type: "op-test-reviewer", model: "sonnet",
  background: true,
  prompt: "cd <project_root>/.worktrees/{TID} && pwd\nreview T{n} tests。..." })
```

后台 Sub Agent 完成时自动回报结果给 leader。leader 不需要轮询、不需要信号文件。

**op-closer**（前台）：
```js
Agent({ name: "op-closer", subagent_type: "op-closer", model: "haiku",
  prompt: "cd <project_root>/.worktrees/{TID} && pwd\n收口 T{n} \"{title}\"。..." })
```

**每个 op-coder/op-reviewer 收到任务第一件事**：`cd <project_root>/.worktrees/{TID} && pwd`。**硬校验**：pwd 输出必须等于目标路径。不匹配 → 立即回报 leader "路径错误"，不继续干活。

### compact 恢复

compact 后读本文件 + 用 jq 查询 `tasks_list.json` + 读 `leader_checkpoint.md`。

**checkpoint 只给断点，不给调度结论**——恢复后必须重算 DAG，不能吃 checkpoint 惯性。

**恢复步骤**：读 checkpoint → 用 jq 查询 tasks_list → 读本协议 → 若有未归档 `tasks/{TID}/` 则从 context.md 续，否则重新选 task。Sub Agent 每次重新 dispatch，不需要恢复 agent 状态。

**checkpoint 格式**见 `template/op_execution/leader_checkpoint.md`，写完后跑 `bash skills/op-start/scripts/close_check.sh {TID}` 验收。

## 不做

- 不停下问用户（除非全部可跑 task 跑完仍剩阻塞）
- Sub Agent 之间不直接通信
- 中间状态不 commit
