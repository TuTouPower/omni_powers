# 多 Agent 协作工作流协议

> **唯一编排依据**——所有编排决策以本协议为准。执行流程见 skills。
> compact 恢复：读本文件 + 用 jq 查询 `tasks_list.json`（⚠️ 严禁 Read 整文件）+ 读 `leader_checkpoint.md`。
> 操作细则见 `RULES_DETAIL.md`，决策依据见 `docs/omni_powers/op_decisions.md`，实验记录见 `docs/omni_powers/op_findings.md`。
>
> **核心心智模型**：磁盘是真状态，所有 agent 上下文都是可重建缓存。全线 Sub Agent，每次 fresh dispatch。

## 角色

| 角色          | 类型       | model  | 派发     | 职责                                                                                                |
| ------------- | ---------- | ------ | -------- | --------------------------------------------------------------------------------------------------- |
| leader        | 主会话     | —     | —        | 编排、收口、改共享文档                                                                              |
| op-coder       | Sub Agent | haiku  | 前台     | TDD：写测试→写实现→跑测试→写 context.md。dispatch 前跑 `op-coder-check.sh` 判定模式          |
| op-code-reviewer | Sub Agent | sonnet | 后台并行 | 审 git diff + 安全/架构/错误处理，写 review_code.md                                                 |
| op-test-reviewer | Sub Agent | sonnet | 后台并行 | 审测试是否真能发现问题，写 review_test.md                                                           |
| op-closer        | Sub Agent | haiku  | 前台     | 收口：spec 盖戳 + git mv 归档 + 更新 tasks_list.json + specs/ + tech_debt + git add -A + commit |

全线 Sub Agent。每次 task 重新 dispatch，上下文隔离。所有 agent 共用一个 worktree。收到任务第一件事：`cd <work_dir> && pwd` 硬校验。

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
| `收口中` | 双 PASS 后，op-closer 执行中                 | null                                               |
| `完成`   | op-closer 返回后 commit + close_check 通过     | null                                               |
| `阻塞`   | 3 轮 FAIL 或环境阻塞                        | `resource`/`quality`/`spawn`（必有值） |
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

状态修改：`bash scripts/op_status.sh <TID> <status> [blocked_by]`（详见 `RULES_DETAIL.md`）。

## 文件分层

### task 工作区（全部进 git，不删）

```
docs/omni_powers/op_execution/tasks/{TID}/
├── spec.md           # op-generate-spec 生成
├── plan.md           # op-generate-plan 生成
├── context.md        # op-coder 追加正向进度。FAIL 轮不碰
├── review_code.md    # op-code-reviewer 写 — op-coder 修改记录就近追加（只追加不覆盖）
└── review_test.md    # op-test-reviewer 写 — 同上
```

- context.md = 构建边界（正向进度），review_*.md = 质量边界（FAIL 来回）。二者不重叠。
- task 闭环后 git mv 到 `docs/omni_powers/op_record/tasks/{TID}/` 归档。
- `docs/omni_powers/op_execution/issues/{TID}_quality.md` 记录质量阻塞（3 轮 FAIL）。

### 持久文件

| 路径                                       | 谁写   | 何时                                                |
| ------------------------------------------ | ------ | --------------------------------------------------- |
| `docs/omni_powers/op_execution/tasks_list.json`      | op-closer / leader | 状态流转                                         |
| `docs/omni_powers/op_blueprint/specs/{feature}.md`   | op-closer / leader | 每 task 闭环整理（当前生效规格，按功能聚合）        |
| `docs/omni_powers/op_record/progress.md`             | op-closer / leader | 闭环后追加                                          |
| `docs/omni_powers/op_record/decisions.md`            | op-closer / leader | 有架构决策才追加                                    |
| `docs/omni_powers/op_execution/tech_debt.md`         | op-closer / leader | 闭环后追加                                          |
| `docs/omni_powers/op_execution/leader_checkpoint.md` | leader | 每 task 闭环后写                                    |
| `docs/omni_powers/op_execution/dag.md`               | leader | 每次 /op-start 从 depends_on 重算生成               |
| `docs/omni_powers/op_blueprint/` 下其他文档          | op-closer / leader | 按需更新                                          |

### specs/ 机制

当前真相在 `docs/omni_powers/op_blueprint/specs/{feature}.md`，按功能聚合。task 闭环时把当前生效规格整理进去，只留"现在是什么"，不留方案比较/被否方案。归档 task spec 顶部盖戳冻结——归档后的 task spec 是历史快照，会过时；当前代码"是什么"靠 specs/ 文件。

**整理规则**：每 task 闭环时，把 task spec 里当前生效的接口、数据模型、约束、行为整理进 `docs/omni_powers/op_blueprint` 里相关文档和对应功能 specs 文件和。归档后永不再改。

**新建文件规则**：一律先拷 `docs_template/omni_powers` 下对应模板再填内容。无对应模板才自建。

## 关键规则

### review 判定

- leader 派 op-code-reviewer 和 op-test-reviewer 为后台 Sub Agent 并行 review
- review 文件**最后一行**必须是 `verdict: PASS` 或 `verdict: FAIL`（首轮写一行，重审追加一行）
- 双 PASS → 收口。任一 FAIL → coder 修改后重新 review，同一 task 最多 3 轮
- 第 3 轮仍任一 FAIL → status=阻塞, blocked_by=quality，写 `issues/{TID}_quality.md`，下游 task 改为 `跳过`
- **分类体系**：CRITICAL / HIGH / MEDIUM / LOW 四级
- **暂存标签**：默认不暂存。暂存条件：跨 scope / 需环境变更 / 架构决策 / 依赖未来 task
- **PASS 门槛**：所有未标暂存的问题必须修完才 PASS
- **reviewer 出错处理**：只重试失败的 reviewer（max 3），成功的保留。重试仍失败 → 对应 review 文件写 `verdict: FAIL`

### 工作区

一个 task 一个 commit，在同一个工作目录上操作。

- `/op-start` 启动时问用户：worktree 模式（推荐）还是 master 模式
- worktree 模式：`git worktree add .worktrees/op-dev -b feat/op-dev`，全 session 共用，贯穿所有 task。**所有 task 完成之后**，leader 才切回原分支合并并移除：`git checkout <原分支> && git merge feat/op-dev --ff-only && git worktree remove .worktrees/op-dev`。未完成前不拆 worktree、不 merge 分支
- master 模式：直接在 master 分支工作，不创建 worktree
- leader 将当前工作目录传给所有 subagent 的 dispatch prompt

### DAG 与 depends_on

每个 task 的 `depends_on` 记录其前置依赖（数组，无依赖则 `null`）。每次 `/op-start` 从 `depends_on` 重算拓扑分层，生成 `docs/omni_powers/op_execution/dag.md`。

### compact 恢复

compact 后读本文件 + 用 jq 查询 `tasks_list.json` + 读 `leader_checkpoint.md`。

**checkpoint 只给断点，不给调度结论**——恢复后必须重算 DAG。

**恢复步骤**：读 checkpoint → 用 jq 查询 tasks_list → 读本协议 → 若有未归档 `tasks/{TID}/` 则从 context.md + review_*.md 重建状态 → 重新选 task。Sub Agent 每次重新 dispatch，不需要恢复 agent 实例。

## 不做

- 不停下问用户（除非全部可跑 task 跑完仍剩阻塞）
- Sub Agent 之间不直接通信
- 中间状态不 commit
