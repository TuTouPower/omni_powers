# 多 Agent 协作工作流协议

> **唯一编排依据**——所有编排决策以本协议为准。执行流程见 skills。
> compact 恢复：读本文件 + 用 jq 查询 `tasks_list.json`（⚠️ 严禁 Read 整文件）+ 读 `leader_checkpoint.md`。
> 决策依据见 `harness_decisions.md`，实验记录见 `findings.md`。
>
> **核心心智模型**：磁盘是真状态，teammate 和 leader 上下文都是可重建缓存。

## 角色

| 角色 | 类型 | model | 职责 |
|---|---|---|---|
| leader | 主会话 | — | 编排、收口、改共享文档 |
| coder-1/2/3 | **Agent Team** | haiku | TDD：写测试→写实现→跑测试→写 context.md |
| code-reviewer | **Agent Team** | sonnet | 审 git diff + 安全/架构/错误处理，写 review_code.md |
| test-reviewer | **Agent Team** | sonnet | 审测试是否真能发现问题，写 review_test.md |
| task-splitter | **Subagent** | sonnet | 按需启用：拆 task，不污染 leader 上下文 |
| closer | **Subagent** | haiku | 按需启用：收口机械步骤（progress/decisions/tech_debt/specs 整理/归档），不污染 leader 上下文 |

### 为什么用 Agent Team

- 跨 task 存活，上下文复用，不每次重填（D4, D5）
- FAIL 轮唤醒同一实例，保留 spec/plan/上一轮代码上下文
- compact 后 teammate 消失需重 spawn，但 context.md/ review_*.md 在文件系统，恢复不丢

### 为什么 task-splitter 和 closer 用 Subagent

- 一次性操作：执行完回报消失
- 无需持久，无需 FAIL 轮，无需跨 task 复用
- 中间内容不污染 leader 上下文
- 拆 task / 收口要读原 spec/plan 全文、切片、重写——这些中间内容若在 leader 上下文跑会大量挤占编排空间
- 确定性机械操作，sonnet 足够。leader 只给指令，subagent 干完回报结果，leader 不读中间过程

> doc-updater 角色已砍——共享文件应由 leader 串行收口，额外 agent 增加复杂度。

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

- context.md = 构建边界（正向进度），review_*.md = 质量边界（FAIL 来回）。二者不重叠——读者、时机、内容不重叠，重审不跨文件找。review 文档是审计痕迹，全部进 git、永不删，记录 coder 改了什么、为什么不改、review 哪里误判。
- task 闭环后 git mv 到 `docs/harness_record/tasks/{TID}/` 归档。
- `docs/harness_execution/issues/{TID}_quality.md` 记录质量阻塞（3 轮 FAIL）和 spawn 失败等阻塞原因。

### 持久文件

| 路径 | 谁写 | 何时 |
|---|---|---|
| `docs/harness_execution/tasks_list.json` | leader | 状态流转（含 tasks 数组和 blockers 数组） |
| `docs/harness_blueprint/specs/{feature}.md` | leader | 每 task 闭环整理（当前生效规格，按功能聚合） |
| `docs/harness_record/progress.md` | leader | 闭环后追加 |
| `docs/harness_record/decisions.md` | leader | 有架构决策才追加 |
| `docs/harness_execution/tech_debt.md` | leader | 闭环后追加 |
| `docs/harness_execution/leader_checkpoint.md` | leader | 每 task 闭环后写 |
| `docs/harness_execution/dag.md` | leader | 每次 /harness-start 从 depends_on 重算生成 |
| `docs/harness_blueprint/spec.md` | leader | 全局总纲 + specs/ 目录索引，需求变更时改 |
| `docs/index.md` | leader | 文档导航总图（三态模型 + 目录索引），结构变动时同步 |

### specs/ 机制

当前真相在 `docs/harness_blueprint/specs/{feature}.md`，按功能聚合。task 闭环时把当前生效规格整理进去，只留"现在是什么"，不留方案比较/被否方案。归档 task spec 顶部盖戳冻结——归档后的 task spec 是历史快照，会过时；当前代码"是什么"靠 specs/ 文件。

**整理规则**：每 task 闭环时，leader 必须把 task spec 里当前生效的接口、数据模型、约束、行为整理进对应功能 specs 文件——不是拷贝，过程性内容留在归档 task spec。同一功能跨多个 task 时累积更新同一个文件，不为后续 task 新建文件。归档后永不再改。

**新建文件规则**：一律先拷 `template/` 下对应模板再填内容。无对应模板才自建。

## 关键规则

### review 判定

review 由 Agent Team 执行（D4），不用 Workflow。

- leader SendMessage 派 code-reviewer 和 test-reviewer 并行 review
- code-reviewer 写 `review_code.md`，test-reviewer 写 `review_test.md`
- 每个 review_*.md 首行必须是 `verdict: PASS` 或 `verdict: FAIL`
- leader 读首行判定，不 grep 正文
- 双 PASS → 收口。任一 FAIL → FAIL 轮。
- **分类体系**：CRITICAL / HIGH / MEDIUM / LOW 四级
- **暂存标签**：每条问题默认不暂存（当场修）。需要暂存时标【暂存:原因】。暂存条件：跨 scope / 需环境变更 / 架构决策 / 依赖未来 task
- **PASS 门槛**：所有未标暂存的问题必须修完才 PASS。LOW 不是放过理由。
- **FAIL 轮**（max 3）：leader 把 blockers 发回原 coder-N → coder-N 改代码（只针对 blocker 改实现和补测试，不扩展到 blocker 之外的新行为和新测试）+ 在 review_*.md 追加修改记录（禁碰 context.md）→ leader 重派 review。coder-N 跨轮保留状态。**重读后**：reviewer 承认误判则首行改 PASS，维持原判则保持 FAIL 并追加理由。第 3 轮仍 FAIL → status=阻塞, blocked_by=quality，写 `issues/{TID}_quality.md`，该 task 退出波次，波次内其他 task 继续。**下游顺延**：FAIL task 的下游依赖自动顺延到下一波次；3 轮后 blocked_by=quality，下游按依赖关系连锁阻塞或绕过。

### commit 时机

**一个 task 一次 commit**。hash 回填延迟到下一个 task 收口时一并提交。收口是 task 级语义动作——step 不收口、不单 commit（step 互相依赖，review 应看整个 task diff；回滚以 task 为粒度，一个 task 一个 commit 便于 revert）。大到需多次收口 → 拆 task。WIP sub-commit 允许但脱钩收口（纯代码落盘，不改 status/不归档）。

### DAG 与 depends_on

每个 task 的 `depends_on` 记录其前置依赖（数组，无依赖则 `null`）。**所有新增 task 的入口**（intake、debt-to-tasks、task-splitter）都必须填 `depends_on`。

每次 `/harness-start` 从 `depends_on` 重算拓扑分层，生成 `docs/harness_execution/dag.md`（Mermaid 图 + 分层表），给人看。dag.md 是衍生文件，不存 checkpoint。

### 并发与 worktree

- 波次 = DAG 同层所有可跑 task。层宽 1 → 串行；层宽 > 1 → 按文件冲突判定并发（上限 3）。
- **并发判定算法**：
  1. 从每个 task 的 plan.md"文件结构"段提取要修改的文件路径列表
  2. 两两计算交集——有公共文件即冲突对，必须串行
  3. 构建无向冲突图（节点=task，边=冲突对），每个连通分量内串行，分量间可并发
  4. 并发数 = min(3, 连通分量数)。若分量数 > 3，按分量内 task 数降序取前 3 个分量，其余等下个波次
- 隔离靠 leader 手动 `git worktree add .worktrees/{TID} -b feat/{TID}`。所有 worktree 统一在项目根 `.worktrees/` 下，分支名 `feat/{TID}`。
- 收口时按依赖顺序合并 worktree，每合一跑全量测试，**全部合并完再做共享文档收口**。合并冲突时：leader 读冲突段，按依赖优先规则解决（后者适配），解决后跑全量测试，冲突记录写入 decisions.md。波次全部收口后开下一波次。

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

**双通道通知**：teammate 完成工作后同时 (a) SendMessage 回报 leader (b) 在 worktree 写标记文件。coder 写 `.coder_done`，code-reviewer 写 `.reviewer_code_done`，test-reviewer 写 `.reviewer_test_done`。leader 不单靠 SendMessage，同时检查标记文件存在才判定完成。

**生命周期**（D5）：
- teammate 全程复用，不主动 shutdown，不监控上下文
- 上下文满了由 Claude Code 自动 compact/截断
- idle 后不消失，SendMessage 即可唤醒。FAIL 轮发回原 teammate，保留跨轮状态
- **派新 task 前必须强制切目录**：上一个 task 收口后 worktree 已删除，teammate 的 shell cwd 是死路径。leader 在派活消息首行写 `cd <绝对路径> && pwd`，coder 收到消息第一件事执行 cd + 验证 pwd
- **shutdown 仅用于 teammate 完全无响应**：SendMessage 含 shutdown_request → 等回复 → 清 config 残留
- **spawn 前必须查 config**：名字已存在则唤醒，不存在才 spawn。同名 spawn 会被自动加序号

**compact 后恢复**：teammate 消失需重 spawn。恢复前查 config.json，isActive=false 的先清残留再 spawn。恢复后从 spec/plan/context.md 重建上下文。

> 首次使用需设 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`。参考：[Agent Teams](https://code.claude.com/docs/en/agent-teams)

### tech_debt

只记修不了的问题（跨 scope/依赖环境/需架构决策/需未来 task）。能当场修的进 FAIL 轮，不进 tech_debt。每 task 闭环强制追加（无新增也写一行）。不允许只口头说"记 tech_debt"，必须真写文件，否则 task 不算闭环。

格式：按 task 分节，表格列 `| ID | 来源(review-code/review-test/环境) | 债项 | 严重度 | 暂存原因 |`。

### compact 恢复

compact 后读本文件 + 用 jq 查询 `tasks_list.json` + 读 `leader_checkpoint.md`。

**checkpoint 字段**：刚完成 task + commit hash、tasks_list 状态快照、下一个 task、team teammate 状态、team config 路径。

**checkpoint 只给断点，不给调度结论**——恢复后必须重算 DAG 层宽，不能吃 checkpoint 惯性。

**恢复步骤**：读 checkpoint → 读 tasks_list → 读本协议 → 若有未归档 `tasks/{TID}/` 则从 context.md 续（判断 coder 进行到哪了），否则重新选 task → 重建/复用 team。

## 阻塞项处理

| 类型 | blocked_by | 处理 |
|---|---|---|
| 外部密钥/凭据缺失 | `key` | 跳过，标阻塞 |
| 域名/外部端点缺失 | `domain` | 同上 |
| 3 轮 FAIL | `quality` | 写 issues/{TID}_quality.md，跳过 |
| spawn 失败 | `spawn` | 退避重试 2 次，仍败则标阻塞 |

回滚：`git revert <task_commit>` + 该 task 及下游 status 回 `待开始`。不用 reset（会丢历史）。不连锁回滚下游，只重置状态。

**阻塞汇总**：所有可跑 task 跑完后，若仍有阻塞 task，leader 才停下报告阻塞项、缺什么、需用户提供什么。

### 拆 task（task 太大时，派 task-splitter）

leader 拆 steps.md 时若发现某 task 大到"多个独立交付单元、各自需独立 review/回滚"，拆成多 task。agent 定义见 `agents/harness-task-splitter.md`。

**判断标准**：

| 情况 | 处理 |
|---|---|
| 多改动各自需独立 review + 能独立回滚 | 拆成多 task（T{n}a/T{n}b），各自 spec/plan/review/commit |
| 多改动是一个连贯交付、一起 review 才有意义 | 一个 task 多 step，一次收口一次 commit |

**时机**：在拆 steps.md 那一刻判断，不能等 coder 写一半再拆——已落盘代码要回切会乱。

**机制**（task-splitter 子代理执行，不污染 leader 上下文）：
1. leader 定边界（哪些 step 归 T{n}a、哪些归 T{n}b、依赖关系），Agent 调 task-splitter subagent
2. task-splitter 执行：建子目录、切原 spec/plan（不重跑 generator）、已写代码归入 context.md、改 tasks_list.json（删原未完成 task 行、加子 task 行）
3. task-splitter 回报结果，leader 不读中间过程，按新 tasks_list 重走选 task 规则

**未完成原 task 可替换**：已完成 task 不删是为保依赖链；被重新 scope 的未完成 task 可删原 task 加子 task，避免永不完成的原 task 误导选 task。

**例外**：拆分时发现原 spec 本身漏/错，错的部分由 leader 走 intake 重跑，正确部分仍交 splitter 切。

### plan 分段派活

leader 先读 plan，拆成有序 step 列表（存入 `tasks/{TID}/steps.md`，由 leader 维护进度）。每个 step 是一组相关文件改动。

**派活方式**：leader 只给 coder 当前 step + 相关 spec 段，不给整份 plan。coder 每 step 完成后 leader 再派下一个。小 task 可一次给全 plan。

**steps.md**：leader 维护，记录当前 step 编号和进度。coder 只读不写。

## 执行体系（指向 skill）

协议的**操作**已固化到 skill。此处只列映射关系：

| 环节 | 谁做 | 协议段只记规则 |
|---|---|---|
| 需求→task | `/intake` | 先改 ref 再拆 task |
| 开发循环 | `/harness-start` | 自治循环，收口后自动选下一个 |
| review | Agent Team（code-reviewer + test-reviewer） | 双 review 并行，leader 读 verdict |
| 收口 | harness-start 收口段 | closer stage 全部产出，leader commit |
| 技术债偿还 | `/debt-to-tasks` | 功能 task 全 done 后触发 |
| spec 生成 | `/spec-gen`（或 intake 调用） | spec-generator skill |
| plan 生成 | `/plan-gen`（或 intake 调用） | plan-generator skill |

## 不做

- 不停下问用户（除非全部可跑 task 跑完仍剩阻塞）
- teammate 之间不直接通信
- 中间状态不 commit

## Quick Reference（compact 后速查）

**单 task 生命周期**：确认 spec/plan → 拆 steps → 派 coder TDD → 派 review（Agent Team 并行）→ 读 verdict 首行（PASS→收口 / FAIL→coder 改→重审 max 3 轮）→ 收口（progress/decisions/tech_debt/specs/tasks_list/归档）→ commit → 下一个

**关键路径**：tasks_list.json = 状态源 / dag.md = 依赖图（衍生） / tasks/{TID}/ = 进行中 / record/tasks/{TID}/ = 归档 / specs/{功能}.md = 当前真相 / leader_checkpoint.md = 断点

**关键规则**：
- review 首行 `verdict: PASS/FAIL`，leader 只取首行不读正文
- 每条问题标暂存标签，默认不暂存（当场修）
- 一个 task 一次 commit，hash 回填延迟到下一个 task
- 磁盘是真状态，上下文都是可重建缓存
