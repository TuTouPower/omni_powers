# 多 Agent 协作工作流协议

> **唯一编排依据**——所有编排决策以本协议为准。执行流程见 skills。
> compact 恢复：读本文件 + 用 jq 查询 `tasks_list.json`（⚠️ 严禁 Read 整文件）+ 读 `leader_checkpoint.md`。
> 决策依据见 `docs/omni_powers/op_decisions.md`，实验记录见 `docs/omni_powers/op_findings.md`。
>
> **核心心智模型**：磁盘是真状态，所有 agent 上下文都是可重建缓存。全线 Sub Agent，每次 fresh dispatch。

## 角色

| 角色             | 类型      | model  | 派发     | 职责                                                                                            |
| ---------------- | --------- | ------ | -------- | ----------------------------------------------------------------------------------------------- |
| leader           | 主会话    | —     | —       | 编排、commit、写 checkpoint                                                                     |
| op-coder         | Sub Agent | haiku  | 前台     | TDD：写测试→写实现→跑测试→写 context.md。                                                    |
| op-code-reviewer | Sub Agent | sonnet | 后台并行 | 审 git diff + 安全/架构/错误处理，写 review_code.md                                             |
| op-test-reviewer | Sub Agent | sonnet | 后台并行 | 审测试是否真能发现问题，写 review_test.md                                                       |
| op-spec-reviewer | Sub Agent | sonnet | 后台并行 | 逐条核对实现是否与 spec/plan 一致，写 review_spec.md                                             |
| op-closer        | Sub Agent | haiku  | 前台     | 收口全流程：spec 盖戳 + git mv 归档 + 更新 tasks_list.json + 整理 op_blueprint/ 下所有相关文档 + tech_debt + progress/decisions + git add -A + commit |

全线 Sub Agent。每次 task 重新 dispatch，上下文隔离。

## 状态机

```
待规划 → 待开始 → 进行中 → 审阅中 → 收口中 → 完成
  ↓             ↑        ↓ (FAIL，max 3 轮)
挂起 ───────────┘        └────────┘
                        第 3 轮仍 FAIL → 阻塞(blocked_by=quality)
```

tasks_list.json status 值：

| status     | 含义                                       | blocked_by                                   |
| ---------- | ------------------------------------------ | -------------------------------------------- |
| `待规划` | 刚从需求解析出 task，只有一句话，没有 spec/plan | null                                         |
| `待开始` | spec/plan 就位，未开发                     | null                                         |
| `进行中` | op-coder 开发或修复轮中                    | null                                         |
| `审阅中` | review 进行中                              | null                                         |
| `收口中` | 三 PASS 后，op-closer 执行中               | null                                         |
| `完成`   | op-closer 返回后 commit + close_check 通过 | null                                         |
| `阻塞`   | 3 轮 FAIL 或环境阻塞                       | `resource`/`quality`/`spawn`（必有值） |
| `跳过`   | 因下游阻塞顺延，等待阻塞解除               | null                                         |
| `挂起`   | 用户明确指示暂时不做，需用户同意才能做     | null                                         |

状态修改：`bash scripts/op_status.sh <TID> <status> [blocked_by]`。

### 阻塞项处理

| 类型                        | blocked_by   | 处理                             |
| --------------------------- | ------------ | -------------------------------- |
| 外部资源缺失（密钥/端点等） | `resource` | 跳过，标阻塞                     |
| 3 轮 FAIL                   | `quality`  | 写 issues/{TID}_quality.md，跳过 |
| spawn 失败                  | `spawn`    | 退避重试 2 次，仍败则标阻塞      |

### 下游传播

- 某 task 阻塞后，其直接/间接下游 status 改为 `跳过`。
- **绕过**：若下游 task 实际上不依赖被阻塞 task 的产出，leader 可修改该下游 task 的 `depends_on` 移除阻塞节点，并在 decisions.md 记录理由。无此记录则不可绕过。
- 阻塞解除后，`跳过` 的 task 恢复 `待开始`。
- 所有可跑 task 跑完后仍有阻塞，leader 才停下报告阻塞项、缺什么、需用户提供什么。

### 挂起项处理

- `挂起`：用户主动推迟。不自动流转，除非用户要求恢复。恢复后根据是否已生成 spec/plan，回到 `待开始` 或 `待规划`。

不用 reset（会丢历史）。

1. `git revert <commit_hash>` — 反向提交
2. `bash scripts/op_status.sh {TID} 待开始` — 该 task status 回退
3. `bash scripts/op_jq.sh downstream {TID}` 查下游 task，逐一 `op_status.sh {下游TID} 待开始`
4. 若该 task 已归档到 `docs/omni_powers/op_record/tasks/{TID}/`：`git mv docs/omni_powers/op_record/tasks/{TID} docs/omni_powers/op_execution/tasks/{TID}` — 移回工作区

不连锁回滚下游，只重置状态。下游 status 回退后依赖链完整，选 task 规则自然重新调度。

## 文件分层

### task 工作区（全部进 git，不删）

```
docs/omni_powers/op_execution/tasks/{TID}/
├── spec.md           # op-generate-spec 生成
├── plan.md           # op-generate-plan 生成
├── context.md        # op-coder 追加正向进度。FAIL 轮不碰
├── review_spec.md    # op-spec-reviewer 写 — 逐条核对 spec 合规
├── review_code.md    # op-code-reviewer 写 — op-coder 修改记录就近追加（只追加不覆盖）
└── review_test.md    # op-test-reviewer 写 — 同上
```

- context.md = 构建边界（正向进度），review_*.md = 质量边界（FAIL 来回）。二者不重叠。
- task 闭环后 git mv 到 `docs/omni_powers/op_record/tasks/{TID}/` 归档。
- `docs/omni_powers/op_execution/issues/{TID}_quality.md` 记录质量阻塞（3 轮 FAIL）。

### 持久文件

| 路径                                                   | 谁写               | 何时                                         |
| ------------------------------------------------------ | ------------------ | -------------------------------------------- |
| `docs/omni_powers/op_execution/tasks_list.json`      | op-closer | 状态流转                                     |
| `docs/omni_powers/op_blueprint/specs/{feature}.md`   | op-closer | 每 task 闭环整理（当前生效规格，按功能聚合） |
| `docs/omni_powers/op_record/progress.md`             | op-closer | 闭环后追加                                   |
| `docs/omni_powers/op_record/decisions.md`            | op-closer | 有架构决策才追加                             |
| `docs/omni_powers/op_execution/tech_debt.md`         | op-closer | 闭环后追加                                   |
| `docs/omni_powers/op_execution/leader_checkpoint.md` | leader    | 每 task 闭环后写                             |
| `docs/omni_powers/op_execution/dag.md`               | leader    | 每次 /op-start 从 depends_on 重算生成        |
| `docs/omni_powers/op_blueprint/` 下其他文档          | op-closer | 按需更新                                     |

### 闭环整理

task 闭环时，op-closer 检查 `docs/omni_powers/op_blueprint/` 下所有相关文档（specs/{feature}.md、prd.md、architecture.md、domain.md、conventions.md 等），把本 task 当前生效的接口、数据模型、约束、行为整理进去。只留"现在是什么"，不留方案比较/被否方案。

归档 task spec 顶部盖戳冻结——归档后的 task spec 是历史快照，会过时；当前代码"是什么"靠 `op_blueprint/` 下的文件。

**新建文件规则**：一律先拷 `docs_template/omni_powers` 下对应模板再填内容。无对应模板才自建。

### tech_debt

只记修不了的问题（跨 scope/依赖环境/需架构决策/需未来 task）。能当场修的进 FAIL 轮，不进 tech_debt。每 task 闭环强制追加（无新增也写一行 "无新增"）。不允许只口头说"记 tech_debt"，必须真写文件，否则 task 不算闭环。

## 关键规则

### review 判定

- leader 派 op-spec-reviewer、op-code-reviewer、op-test-reviewer 为后台 Sub Agent 并行 review
- review 文件**最后一行**必须是 `verdict: PASS` 或 `verdict: FAIL`（首轮写一行，重审追加一行）
- 三 PASS → 收口。任一 FAIL → coder 修改后重新 review，同一 task 最多 3 轮
- 第 3 轮仍任一 FAIL → status=阻塞, blocked_by=quality，写 `issues/{TID}_quality.md`，下游 task 改为 `跳过`
- **分类体系**：CRITICAL / HIGH / MEDIUM / LOW 四级
- **暂存标签**：默认不暂存。暂存条件：跨 scope / 需环境变更 / 架构决策 / 依赖未来 task
- **PASS 门槛**：所有未标暂存的问题必须修完才 PASS
- **reviewer 出错处理**：只重试失败的 reviewer（max 3），成功的保留。重试仍失败 → 对应 review 文件写 `verdict: FAIL`

### 工作区

一个 task 一个 commit，在同一个工作目录上操作。

- `/op-start` 启动时查仓库主分支名（main/master），问用户：worktree（推荐）/ 主分支 / 当前分支
- worktree 模式：`git worktree add .worktrees/op-dev -b feat/op-dev`，全 session 共用，贯穿所有 task。**所有 task 完成之后**，leader 才切回原分支合并并移除：`git checkout <原分支> && git merge feat/op-dev --ff-only && git worktree remove .worktrees/op-dev`。未完成前不拆 worktree、不 merge 分支
- 主分支模式：直接在主分支（main/master）工作，不创建 worktree
- 当前分支模式：不动分支，在当前分支直接工作
- leader 将当前工作目录传给所有 subagent 的 dispatch prompt

大 task 跑很久时，允许 `wip({TID})` 性质的纯代码落盘 sub-commit——**不触发任何收口动作**（不改 status、不归档、不写 checkpoint、不整理 ref）。收口时由 leader 定 squash 还是保留。

### DAG 与 depends_on

每个 task 的 `depends_on` 记录其前置依赖（数组，无依赖则 `null`）。每次 `/op-start` 从 `depends_on` 重算拓扑分层，生成 `docs/omni_powers/op_execution/dag.md`。

### tasks_list 拆分预案

默认不拆，单文件靠 jq 查询。task 量大到单文件过大、查询变慢时启用：

- `docs/omni_powers/op_execution/tasks_list.json` — 只留未完成（待开始/进行中/审阅中/收口中/阻塞/跳过）
- `docs/omni_powers/op_record/tasks_done.json` — 已完成 task，裁剪到最小（id/title/depends_on/commit），删 verification
- 依赖检查：活表查不到的依赖 → 查 done 表确认完成
- 收口时 task 从活表移到 done 表

### compact 恢复

compact 后读本文件 + 用 jq 查询 `tasks_list.json` + 读 `leader_checkpoint.md`。

⚠️ 严禁 Read 整文件 `tasks_list.json`，用 `scripts/op_jq.sh` 或 jq 查询。

```bash
bash scripts/op_jq.sh pending      # 查所有待开始 task
bash scripts/op_jq.sh pending_plan # 查所有待规划 task
bash scripts/op_jq.sh deps {TID}   # 查某 task 依赖
bash scripts/op_jq.sh blocked      # 查阻塞
bash scripts/op_jq.sh skipped      # 查跳过
bash scripts/op_jq.sh suspended    # 查挂起
bash scripts/op_jq.sh downstream {TID}  # 查下游
bash scripts/op_jq.sh all          # 全部概览
```

**checkpoint 只给断点，不给调度结论**——恢复后必须重算 DAG。

**恢复步骤**：读 checkpoint → 用 jq 查询 tasks_list → 读本协议 → 若有未归档 `tasks/{TID}/` 则从 context.md + review_*.md 重建状态 → 重新选 task。Sub Agent 每次重新 dispatch，不需要恢复 agent 实例。

## 不做

- 不停下问用户（除非全部可跑 task 跑完仍剩阻塞）
- Sub Agent 之间不直接通信
- 中间状态不 commit
