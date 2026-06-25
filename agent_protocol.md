# 多 Agent 协作工作流协议

> 总指挥（leader, opus）编排 4 个常驻 teammate 完成 tasks_list.json 中的全部 task。
> 全自主运行，无需用户介入。本协议是唯一编排依据，compact 后靠它 + tasks_list.json + checkpoint 恢复。

## Quick Reference（compact 恢复先读此段）

**角色**：leader(opus, 主会话, 收口改共享文档) / coder(haiku, TDD) / reviewer(sonnet, 写 review_code.md) / test-reviewer(sonnet, 写 review_test.md) / task-splitter(sonnet, 按需, 拆 task 不污染 leader)。无 doc-updater。

**状态机**：`待开始 → 进行中 → 审阅中 → 完成`；FAIL 回进行中（max 3 轮）；3 轮 FAIL → 阻塞。
英文/中文映射：pending=待开始 / coding=进行中 / reviewing=审阅中 / done=完成 / blocked=阻塞。

**单 task 10 步**：①确认 spec/plan 就位 ②拆 steps ③派 coder TDD ④调 task_review.js（或手工派双 review）⑤读 {passed,blockers}（PASS→⑥ / FAIL→发回 Teams coder 改再调 task_review.js，max 3 轮）⑥收口（progress/decisions/tech_debt/ref specs/tasks_list/归档）⑦commit ⑧回填 hash ⑨自检 compact ⑩下一个

**关键路径**：tasks_list.json=状态源 / docs/harness_execution/tasks/{TID}/=进行中 / docs/harness_record/tasks/{TID}/=归档 / docs/harness_blueprint/specs/{功能}.md=当前真相 / docs/harness_execution/leader_checkpoint.md=断点 / **docs/harness/template/=所有文件模板（新建文件拷这里）**

**新建文件规则（强制）**：协议中任何环节要新建文件（task 工作区的 spec/plan/steps/context/review_code/review_test、tasks_list.json、leader_checkpoint、tech_debt、issues/{TID}_*、harness_blueprint/* 等），一律先拷 `docs/harness/template/` 下对应模板再填内容，保证格式一致。无对应模板才自建。

**关键规则**：
- review 判定：脚本模式 task_review.js 返回 `{passed, blockers, techDebt}`；手工模式 review_*.md 首行 `verdict: PASS/FAIL`，leader 只取首行不读正文
- FAIL 默认发回**原 Teams coder**（有状态、跨轮复用），coder 改完写 review_*.md 修改记录，leader 再调 task_review.js，max 3 轮；小修可选 task_review_autofix.js（1 轮 scope 内 autofix，超限 escalate）
- commit 粒度=task，中间状态不 commit；step 不收口不单 commit；大到要多次收口 → 拆 task 派 task-splitter
- 并发=依赖分层+**leader 手动 git worktree 隔离**（不用 isolation:'worktree'，粒度不对），波次=DAG 层全部收口即结束；恢复后必须重算 DAG，不吃 checkpoint 惯性
- teammate idle = 可唤醒资源，FAIL 唤醒原 coder 实例不新 spawn
- spawn 失败重试2次→status=阻塞, blocked_by=spawn；回滚用 git revert 不用 reset

**恢复三件套**：本协议 + docs/harness_execution/tasks_list.json + docs/harness_execution/leader_checkpoint.md

---

## 角色

| 角色 | subagent_type | model | 职责 |
|---|---|---|---|
| leader | （主会话） | opus | 读 tasks、编排、合并审阅、提交、改所有共享文档（progress/decisions/tech_debt/tasks_list.json/ref）、收口 |
| coder | general-purpose | haiku | TDD：写测试→写实现→跑测试→写 context.md |
| reviewer | code-reviewer | sonnet | 审 git diff + 安全/架构/错误处理，写 review_code.md |
| test-reviewer | test-reviewer | sonnet | 审测试是否真能发现问题，写 review_test.md |
| task-splitter | general-purpose | sonnet | **按需启用**：leader 判定某 task 需拆分时派出，执行拆 task 机制（建目录+切 spec/plan+改 tasks_list），全在自己上下文跑，产出落盘后只回报结果，不污染 leader 上下文 |

doc-updater 角色砍掉——改 docs/harness_blueprint/progress/decisions/tasks_list.json 都是共享文件，本就该走 leader 串行收口，中间隔子 agent 纯属多余。

**task-splitter 为什么单列**：拆 task 要读原 spec/plan 全文、切片、重写 tasks_list 片段——这堆中间内容若在 leader 上下文跑会大量挤占编排空间。它是确定性机械操作（不需要 opus 判断力），sonnet 足够。leader 只下"拆 {TID} 成 {TID-a}/{TID-b}，边界在 X"的指令，splitter 干完回报"已建目录/已切 spec/plan/tasks_list 已改"，leader 不读中间过程。**仅在拆分时启用，平时不存在**。

## 状态机（单 task）

```
pending → coding → reviewing → PASS → doc → done
                              └ FAIL → coding（coder 读 review_*.md 自改，max 3 轮）
                              └ 第 3 轮仍 FAIL → 标"status=阻塞, blocked_by=quality"，跳过该 task，继续下一个
```

**英文/中文映射**（状态机图用英文，tasks_list.json 用中文）：

| 状态机（英文） | tasks_list.json（中文） | 含义 |
|---|---|---|
| pending | 待开始 | spec/plan 就位，未开发 |
| coding | 进行中 | coder 开发或修复轮中 |
| reviewing | 审阅中 | coder 完成，reviewer 审阅中 |
| done | 完成 | 双 PASS + 收口提交 |
| （无直接对应） | 阻塞 | 3 轮 FAIL 或环境阻塞 |

第 3 轮仍 FAIL 不停下问用户。标 `docs/harness_execution/issues/{TID}_quality.md`，tasks_list.json 该行 status→阻塞，回到选 task 规则挑下一个。

### tasks_list.json 的 status 值

状态机映射到 `tasks_list.json` 的 `status` 字段，共 5 种。完成的 task 不挪走、不删，留在同一文件靠 status 区分（保持依赖链完整）：

| status | 含义 | 触发时机 | blocked_by |
|---|---|---|---|
| `待开始` | spec/plan 就位，未开发 | leader 建完 task | null |
| `进行中` | coder 开发或修复轮中 | leader 派活 / FAIL 回 coding | null |
| `审阅中` | coder 完成，reviewer 审阅中 | leader 派 review | null |
| `完成` | 双 PASS + 收口提交 | leader 收口 | null |
| `阻塞` | 3 轮 FAIL 或环境阻塞 | leader 标记 | `"key"`/`"domain"`/`"quality"`/`"spawn"`（阻塞态必有值） |

`阻塞` 的 `blocked_by` 完整值：`key`（平台/搜索 key 缺）、`domain`（域名缺）、`quality`（3 轮 FAIL）、`spawn`（spawn 失败）。**status 字段只存 `阻塞`，细分一律靠 blocked_by**——全文不用"阻塞-key"这种复合 status 值，统一写"status=阻塞, blocked_by=key"。阻塞态 blocked_by 必有值，非阻塞态为 null。

## 文件分层

### task 工作区（全部进 git，不删）

```
docs/harness_execution/tasks/{TID}/
├── spec.md           # brainstorming 生成（输入）
├── plan.md           # writing-plans 生成（输入）
├── steps.md          # 大 plan 的 step 拆分 + leader 维护的进度
├── context.md        # coder 每 step 完成追加正向进度：改了哪些文件、测试输出、假设。FAIL 轮不写此文件
├── review_code.md    # reviewer 写：blockers/risks/verdict + coder 修改记录（FAIL 轮就近追加）
└── review_test.md    # test-reviewer 写：假测试/缺失/verdict + coder 修改记录（FAIL 轮就近追加）
```

- **全部进 git，永不删**。review 文档是审计痕迹——coder 改了什么、为什么不改、review 错在哪，都要留。
- **review 文档只追加不覆盖**：reviewer 写审阅意见，coder 在同文件追加"已改 X / 此项不改因为 Y / review 此处判断有误因为 Z"。是来回记录，不是单方结论。
- **context.md 与 review_*.md 的分工（按边界类型切，不按轮次切）**：
  - `context.md` = **构建边界**。coder 每个 step 完成时追加正向进度（改了哪些文件、测试输出、关键假设）；小 task 无 step 拆分则闭环时写一次。作用是给重 spawn 的 coder 和 leader 收口提供"已经改到哪"。**FAIL 轮一律不碰 context.md**。
  - `review_*.md` = **质量边界**。FAIL 轮的所有来回（reviewer 意见 + coder 逐项回应）就近写在对应 review 文件，一个文件看全质量线程。
  - 二者读者/时机/内容不重叠，重审不跨文件找。
- task 闭环后整个 `tasks/{TID}/` 目录挪到 `docs/harness_record/tasks/{TID}/` 归档（git mv，保留历史）。

### 其他持久文件

| 路径 | 谁写 | 何时 |
|---|---|---|
| `src/`、`tests/` | coder | coding 阶段 |
| `docs/harness_execution/tasks_list.json` | leader | 状态流转（task 清单 + 依赖 + status） |
| `docs/index.md` | leader | 文档导航总图（三态模型 + 目录索引），结构变动时同步 |
| `docs/harness_blueprint/spec.md` | leader | 全局总纲 + specs/ 目录索引；需求变更时改 |
| `docs/harness_blueprint/specs/{功能}.md` | leader | 每 task 闭环时整理更新（当前生效规格） |
| `docs/harness_record/progress.md` | leader | 闭环后追加 |
| `docs/harness_record/decisions.md` | leader | 有架构决策才追加 |
| `docs/harness_execution/tech_debt.md` | leader | 闭环后追加 MEDIUM/LOW |
| `docs/harness_execution/leader_checkpoint.md` | leader | 每 task 闭环后写，compact 恢复用 |
| `docs/harness_execution/issues/{TID}_*.md` | leader | 阻塞记录（`{TID}_quality.md` 质量阻塞 / `{TID}_spawn.md` spawn 失败） |

### docs/harness_blueprint/specs/ 机制（当前真相源）

归档的 task spec 是历史快照，会过时，不维护。当前代码"是什么样"靠 `docs/harness_blueprint/specs/`：

- **结构**：`docs/harness_blueprint/specs/{功能}.md`，按功能聚合（auth.md / user_settings.md / db_access.md...），不是 1 task 1 文件。
- **docs/harness_blueprint/spec.md 是目录**：只放全局总纲（技术栈/架构/安全边界）+ 指向 specs/ 各文件的索引。
- **task 闭环时整理**（强制，和 tech_debt 落盘同级）：leader 收口时判断本 task 改的功能对应 `docs/harness_blueprint/specs/` 哪个文件，把 task spec 里**当前生效的规格**（接口/数据模型/约束/行为）整理进去。不是拷贝——过程性内容（方案比较/被否方案/自审）留在归档 task spec，docs/harness_blueprint/specs/ 只留"现在是什么"。
- **多 task 累积更新**：一个功能跨多个 task（如某功能被一个 task 建立、后续 task 加限流、再后续 task 做安全验收），后续 task 在同一 `docs/harness_blueprint/specs/{功能}.md` 追加/更新段落，不新建文件。
- **归档 task spec 冻结**：`docs/harness_record/tasks/{TID}/spec.md` 顶部盖戳"⚠️ 历史快照，以 docs/harness_blueprint/specs/ 为准"，永不再改。

这样归档 spec 过不过时无所谓——当前真相全在 docs/harness_blueprint/specs/，每 task 闭环同步，不漂移。

### review 落盘规则

**review 结论必须落盘**——reviewer/test-reviewer 既 SendMessage 通知 leader，**又**写 `tasks/{TID}/review_code.md` / `review_test.md`。

**verdict 用结构化首行**：文件第一行必须是 `verdict: PASS` 或 `verdict: FAIL`。leader 用 `head -1` / `grep '^verdict:'` 只取这一行判断 PASS/FAIL，**不读 review 正文**。两份都 PASS → 收口；任一 FAIL → 进入 FAIL 轮。

**PASS 门槛（关键）**：只要 reviewer 发现的问题是**能当场解决的**——不分 LOW/MEDIUM/HIGH——coder 必须修完，verdict 才能 PASS。

- LOW 不是放过理由
- 只有"修不了"的才允许标 tech_debt 暂存并 PASS：
  - 跨 scope（动到别的 task 代码）
  - 依赖环境/外部 key
  - 需架构决策
  - 需未来 task 配合
- reviewer 在 review 正文里对每条问题明确标"当场修"或"暂存(原因)"，标"当场修"的没修完 = FAIL

**FAIL 轮（默认交回 Teams coder，真来回）**：task_review.js 返回 FAIL + blockers → leader 把 blockers 发回**原 Teams coder**：
- coder：读 review_*.md 正文 → 改代码 → 在**对应 review_*.md** 同文件追加"修改记录"段（已改 X / 此项不改因为 Y / review 此处判断有误因为 Z）。**禁止写 context.md**——FAIL 轮记录只进 review_*.md。
- leader 再调 `task_review.js`（或手工派双 review）：reviewer/test-reviewer 重读 review_*.md（看 coder 追加的反驳 + 新 git diff）→ 返回新 verdict。

reviewer/test-reviewer 重审后：承认误判则 verdict=PASS；维持原判则保持 FAIL 并追加理由。这样误判能在 1-2 轮内消除，不会白白耗满 3 轮。review 文档是双方来回对话，只追加不覆盖。coder 跨轮留在 Teams 保留状态，不必从 spec 重建。

**review 文档写法参考模板**：`docs/harness/template/harness_execution/tasks/{TID}/review_code.md`、`review_test.md`。每轮拆两段——N-1 = 审阅方（reviewer/test-reviewer）写意见 + verdict，N-2 = coder 修改逐项回应。PASS 止于 N-1；FAIL 进 N-2 修改 → (N+1)-1 重读，max 3 轮。只追加不覆盖。

---

## 需求到 task 的前置流程

开发不是凭空开始，先有需求落 ref，再拆 task：

1. **改 ref**：用户需求进来，leader 先判断影响哪些真相文档（`docs/harness_blueprint/prd.md`、`spec.md`、`architecture.md`、`domain.md`、`test.md`），按需更新。ref 是真相源，必须先于 task 同步。
2. **追加 tasks_list.json**：把需求拆成新 task（或修改现有 task），追加进 `docs/harness_execution/tasks_list.json`——每个 task 含 ID、标题、依赖列、验收标准、阻塞标记。
3. **生成 spec/plan**：对每个新 task，leader 用 `superpowers:brainstorming` 生成 `tasks/{TID}/spec.md`，再用 `superpowers:writing-plans` 生成 `tasks/{TID}/plan.md`。
4. **进入开发循环**：spec/plan 就位后，才走下面的"完整单 task 流程"。

这条流程是**一次性**的（需求来时跑），不是每个 task 都跑。已有 spec/plan 的 task 直接进开发循环。

## 选 task 规则

每次开工 leader 查 tasks_list.json，挑：
1. status = 待开始
2. 依赖列全部 status=完成
3. 不在阻塞项影响范围
4. ID 最小

### tasks_list.json 查询规则（不长读）

tasks_list.json 是结构化数据，**用查询不整体读**，避免文件增大后烧 token：

- 选待开始 task：`jq '.tasks[] | select(.status=="待开始")'`
- 查依赖是否完成：`jq '.tasks[] | select(.id=="{TID}") | .status'`
- 查阻塞清单：`jq '.tasks[] | select(.status=="阻塞")'`
- 只取需要的字段，不全量加载进上下文

leader 用 jq/python 查询片段，不整体读 tasks_list.json 进上下文。

### 量大了再拆（预案）

默认不拆，单文件靠查询。当 task 量真大到几百、查询也慢时，拆成活表 + 归档表：

- `docs/harness_execution/tasks_list.json`：只留未完成（待开始/进行中/审阅中/阻塞）
- `docs/harness_record/tasks_done.json`：已完成 task，裁剪到最小（id/title/dependencies/commit，删 verification）
- 依赖检查：活表查不到的依赖 → 查 done 表确认完成
- 收口时 task 从活表移到 done 表

task 量级不大时不需要拆，靠查询即可。

无可跑 task → 终止，报告阻塞清单。

## 拆 task（task 太大时，派 task-splitter）

leader 拆 steps.md 时若发现某 task 大到"多个独立交付单元、各自需独立 review/回滚"，**不是拆 commit，是拆 task**。判断标准：

| 情况 | 处理 |
|---|---|
| 多改动各自需独立 review + 能独立回滚 | 拆成多 task（{TID-a}/{TID-b}），各自 spec/plan/review/commit |
| 多改动是一个连贯交付、一起 review 才有意义 | 一个 task 多 step，**一次**收口一次 commit |

**时机**：在拆 steps.md 那一刻判断（协议"plan 分段派活规则"），此时刚看清真实体量。别等 coder 写一半再拆——已落盘代码要回切，乱。

**机制（leader 下指令，task-splitter 执行，不污染 leader 上下文）**：

1. leader 判定拆分 + 定边界（哪些 step 归 {TID-a}、哪些归 {TID-b}、依赖关系），SendMessage 给 task-splitter
2. task-splitter 执行（全在自己上下文）：
   - 建 `tasks/{TID-a}/`、`tasks/{TID-b}/` 目录
   - **切**原 spec/plan，不重跑 brainstorming/writing-plans——原 task 的分析已做过，重跑只烧 token + 引漂移。按交付单元把 spec.md / plan.md 切片分给各 sub-task（拆分边界通常正好落在 plan 的 step 分界）
   - 原 task 若已 code 部分 → 那部分进归属 sub-task 的 context.md
   - 改 tasks_list.json：删原 {TID} 行，加 {TID-a}/{TID-b}（含它们之间依赖，通常顺序依赖），写依赖列/验收标准
3. task-splitter 回报"已建目录 / 已切 spec/plan / tasks_list 已改"，leader 不读中间过程，按新 tasks_list 重走选 task 规则

**例外——spec 本身错**：若拆分时发现原 spec 漏/错（不只是大），错的那部分由 leader 走前置流程重跑 brainstorming，正确部分仍交 splitter 切。绝大多数拆分不是这种。

**tasks_list 里原 task 可替换**："完成的 task 不删"针对已完成 task（保依赖链）；被重新 scope 的未完成 task 性质不同，删 {TID} 加 {TID-a}/{TID-b}，否则留个永不完成的 {TID} 误导选 task 规则。

## 标准工作流

单 task 流程是原子单元——不管串行还是并发，每个 task 都走同一套生命周期。区别只在 leader 怎么调度多个 task。

### 第 0 步：开工调度（每次开工做一次）

1. leader 用 jq 查 `tasks_list.json`：`select(.status=="待开始")`，挑依赖全完成、不在阻塞范围、ID 最小的 task。
2. 算依赖 DAG（拓扑分层），写入 `leader_checkpoint.md`。
3. 判断当前波次模式：
   - **波次宽度 = 1**（链式依赖 / 同层只 1 个可跑）→ **串行**，直接走单 task 流程。
   - **波次宽度 > 1** 且 teammate 通信稳、共享文件交集小 → **并发**，波次内每个 task 一个 worktree，同时走单 task 流程。
   - 波次宽度 > 1 但通信不稳 / 共享文件多 → 降并发或退回串行。
4. 波次之间是 barrier：当前波次全部收口提交后，才开下一波次。

**波次定义**：波次 = 当前 DAG 层所有可跑 task（依赖全完成 + 未阻塞）。无最大 task 数、无时间窗口——边界由 DAG 层决定，该层 task 全部收口（或标阻塞跳过）即波次结束。

**并发上限 3**：波次内同时跑的 task ≤ 3（3 coder + 1 reviewer + 1 test-reviewer）。实际并发 = min(层宽, 3)，层宽不够不凑数、不空等。

**共享文件交集约束（选并发 task 前必算）**：列出同波次候选 task 各自会改的共享文件（main.py 路由注册、settings.py、共享测试、共享入口等），交集大 → 收口合并冲突成本高，降并发到 2 或退回串行；交集小才开 3。不能盲选 ID 最小的 3 个——先看交集再定并发数。

### 单 task 流程（原子单元，串行/并发都走这套）

1. **确认 spec/plan**：leader 确认 `tasks/{TID}/` 的 spec.md + plan.md 已就位（由"需求到 task 的前置流程"生成，此处不重新生成）。并发时在各自 worktree 里。
2. **拆 steps**：leader 读 plan，拆 step 列表存 `tasks/{TID}/steps.md`。
3. **派 coder**：leader 按"上下文管理·teammate 层"的 coder 阈值规则决定复用/重 spawn，派活：
   - **大 task**：leader 逐 step 派（每 step：派活 → coder 完成报告 → leader 确认 → 派下一个 step），coder 读 spec + 当前 step → TDD → 跑测试 → 追加 context.md → 报告
   - **小 task**：一次给全 plan，coder 自行跑完
4. **验收 + 派 review**：coder 全部 step 完成 → **leader 验收最小标准**：`tasks/{TID}/context.md` 存在且非空 + 对应 tests/ 有新增/修改文件。缺任一 → 退回 coder 补，不派 review。
   验收通过 → **调 `task_review.js`**（脚本未验证前走手工：派 reviewer + test-reviewer 并行，各写 review_*.md 首行 verdict）：
   - reviewer: 读 git diff + context.md → 写 review_code.md（首行 verdict）
   - test-reviewer: 读 tests/ + context.md → 写 review_test.md（首行 verdict）
   - 脚本返回 `{passed, blockers, techDebt}`（手工模式 leader `head -1` 取两份首行 verdict）
   - 并发时：每个 task 在各自 worktree 内单独调 task_review.js，产出落各自 review_*.md 互不干扰
5. **读 review 结果**：
   - 都 PASS → step 6
   - 任一 FAIL → **默认交回原 Teams coder**（coder 有状态，记得上一轮）：leader 把 blockers 发给 coder → coder 读 review 正文 → 改代码 → 在 review_*.md 追加修改记录段（禁止写 context.md）→ leader **再调 task_review.js** 重审 → max 3 轮
     - 可选：FAIL 项全是 lint/断言/边界/类型小修且在 scope 内 → 调 `task_review_autofix.js`（1 轮 autofix），超限 escalate 回 Teams coder
   - 第 3 轮仍 FAIL → 标"status=阻塞, blocked_by=quality"，写 `issues/{TID}_quality.md`，跳过该 task
6. **收口**（见下"收口"段）
7. **commit**：类型按 task 性质选 feat/fix/refactor/docs，如 `feat({TID}): 简述`
8. **回填 hash**：leader 在 progress.md 回填 commit hash
9. **自检 compact**：每 3 task 强制，或可疑时
10. **下一个**：串行回选 task 规则挑下一个；并发波次内全部收口后开下一波次

### 收口（step 6 展开）

**串行**：leader 直接做下面全部。

**并发**：先按依赖顺序串行合并 worktree，每合一个跑全量测试（绿了再合下一个，共享文件声明此时统一落地），全部合并完再做下面：

- **合并顺序**：依赖在前的 task 先合；同层无依赖的并发 task 按 ID 升序合。
- **合并冲突解决步骤**：① `git merge` 标记冲突文件 ② leader 读冲突段，按依赖优先规则解决（依赖在前的 task 改动保留，后者适配）③ 解决后跑全量测试，绿了才算合完 ④ 冲突解决记录写入 decisions.md。

- 追加 progress.md（含 commit hash 占位）
- 有决策追加 decisions.md
- **追加 tech_debt.md**：从两份 review 的结构化 `## tech_debt` 区块提取（见下"tech_debt 结构化"），不读自由正文
- **整理 docs/harness_blueprint/specs/{功能}.md**（强制：把本 task 当前生效规格整理进去，按功能聚合，多 task 累积更新）
- tasks_list.json 该 task status→完成
- 按需更新 docs/harness_blueprint/（架构/约定受影响时）
- 归档 task spec 顶部盖戳"历史快照，以 docs/harness_blueprint/specs/ 为准"
- git mv tasks/{TID}/ → docs/harness_record/tasks/{TID}/（归档，不删）
- leader 写 leader_checkpoint.md
- （并发时删该 task 的 worktree）

### 收口 git 规则

主树可能有非本 task 改动（并发未合的 worktree、上 task 残留），不能 `-A`。顺序：

1. `git status --short` 列全部改动，逐条判断属本 task（task scope 文件 + coder 在 context.md 声明的共享文件改动 + 本 task 的共享文档）；不属本 task 的不 add，排查来源
2. `git add <属本 task 的具体路径>` — 含新建的 context/review
3. `git mv docs/harness_execution/tasks/{TID} docs/harness_record/tasks/{TID}` — 归档（文件已跟踪，mv 不漏）
4. `git add docs/harness_record/tasks/{TID} docs/harness_execution/tasks_list.json` — 纳入归档移动
5. commit
6. 跑 `bash docs/harness/close_check.sh {TID}` 验收（见下"收口 checklist"）

### 收口 checklist（强制，脚本验收）

收口完必须跑 `docs/harness/close_check.sh {TID}`，非 0 不许进下一个 task。脚本查 4 项：

| 项 | 判定 | 拦截 |
|---|---|---|
| tech_debt.md 含本 task 段（含"无新增"标注） | grep `^## TID` 或 `TID.*无新增` | 必拦 |
| leader_checkpoint.md 含本 task | grep `TID` | 必拦 |
| 归档目录五件齐全（spec/plan/context/review_code/review_test） | `ls docs/harness_record/tasks/{TID}/` | 必拦 |
| git status 非本 task 改动 | `git status --short` 过滤本 task 路径 | 仅提醒不拦 |

**tech_debt 强制写入**：无新增也要追加一行 `| {TID} | - | 无新增技术债 | - | 本 task 所有问题当场修复 |`，否则脚本查不到段会 FAIL。git status 非空只提醒，leader 自查残留属本 task 还是需 stash 隔离。

### tech_debt 结构化

review 文档末尾必须有结构化 `## tech_debt` 区块（reviewer 写），leader 收口时 parse 这段写 tech_debt.md，**不读 review 自由正文**：

```markdown
## tech_debt
| ID | 来源 | 债项 | 严重度 |
|---|---|---|---|
| {TID}-1 | review-code | 示例债项描述 | MEDIUM |
| {TID}-2 | 环境 | 真实环境验收未跑 | HIGH |
```

leader 收口 grep `## tech_debt` 到下一个 `---`/EOF 之间的表格，追加到 docs/harness_execution/tech_debt.md。

### 并发的额外约束（仅波次宽度>1 时生效）

- **隔离靠 leader 手动 git worktree**：每个并发 task 由 leader `git worktree add` 一个独立工作目录，Teams coder 在各自 worktree 工作，task 间天然隔离。**不用** Workflow 的 `isolation:'worktree'`——其粒度是 agent 不是 task，stage 间不可见（详见 `docs/harness/worktree_isolation.md`）。
- **coder 改本 task scope 文件**（含已有代码）；**共享入口/依赖注册/路由注册由 leader 收口时统一改**——coder 在 context.md 声明"我需要在共享文件 X 注册 Y"，leader 合并时落地。
- **合并顺序**：依赖在前的 task 先合，每合一个跑全量测试。
- **并发上限 3**：同时跑的 task ≤ 3（3 coder + 1 reviewer + 1 test-reviewer）。共享文件交集大时降到 2 或 1。
- **每个 worktree 内单独调 `task_review.js`**：单 task 无并发，reviewer 共享该 worktree 直接读 coder 未提交 diff。

### 开工前先算（并发收益判断）

leader 开始并发前评估：
1. 画依赖图看每层宽度。层宽普遍为 1（链式依赖）→ 并发收益低，直接串行。
2. 列同层 task 的共享文件交集，交集大 → 冲突风险高，降并发或拆波次。
3. 用数据决定并发路数，不盲目并发。

## plan 分段派活规则

大 plan coder 单次吃不下。leader 派活时：

1. leader 先读 plan，拆成有序 step 列表（每个 step = 一组相关文件改动）
2. 派 coder 时只给"当前 step + 相关 spec 段"，不是整份 plan
3. coder 做完一个 step 报告，leader 派下一个 step
4. 所有 step 完成 → 进入 review

step 列表存 `tasks/{TID}/steps.md`，leader 维护进度。

## commit 时机

**一个 task 一次 commit**，闭环后立即提交。收口是 **task 级语义动作**——step 凑不齐，不收口、不单独 commit。

- coding 中 / 测试没过 / review 没过 → 不 commit
- PASS + leader 改完共享文档 + task 目录 git mv 到 docs/harness_record/tasks/{TID}/ → commit
- message: `feat({TID}): 简述`

**step 不是交付单元，不收口**：

- step 之间常互相依赖（step2 用 step1 接口），review 看整个 task 的 diff（所有 step 完成才派 review），单独 review 一个 step 没意义、多耗轮次。
- 收口动作全是 task 级（status→完成、归档目录、整理 harness_blueprint/specs、写 checkpoint）。step 没做完整个 task，status 不能→完成、目录不能归档。"step 多次收口"语义自相矛盾。
- 回滚以 task 为粒度。一个 task 一个 commit = 一次 revert。多 commit 多收口 → 回滚要 revert 一串，下游也乱。

**大到要"多次收口" = 拆分粒度错了 → 拆 task，不是拆 commit**（见"拆 task"段）。

**WIP sub-commit 与收口脱钩**：大 task 跑很久、有中途崩溃丢进度风险时，允许 `wip({TID}): stepN` 性质的 sub-commit——**纯代码落盘，不触发任何收口动作**（不改 status、不归档、不写 checkpoint、不整理 ref）。收口时由 leader 定 squash 还是保留。这是上一版"task 内拆 sub-commit"的本意，关键是它和收口完全脱钩。

中间烂状态永不进 git 历史。回滚以 task 为粒度。

## tech_debt 落盘（强制）

tech_debt 只记**修不了的问题**，不是所有 MEDIUM/LOW 的垃圾桶。reviewer 发现的问题分两类：

- **能当场修**（含所有 LOW）→ 不进 tech_debt，进 FAIL 轮让 coder 当场改。coder 手上有上下文，现在改最便宜，记下等以后修纯浪费。
- **修不了才进 tech_debt**：跨 scope（动到别的 task 代码）、依赖环境/外部 key、需架构决策、需未来 task 配合。

每个 task 闭环时，leader 把两份 review 里**标"暂存"的**问题 + 环境限制项追加到 `docs/harness_execution/tech_debt.md`。

- 不允许只口头说"记 tech_debt"——必须真写进文件，否则 task 不算闭环。
- 格式：按 task 分节，表格列 `ID | 来源(review-code/review-test/环境) | 债项 | 严重度 | 暂存原因`。
- 与 progress.md 回填 commit hash 同一步完成，写在收尾 checklist 里。

## tech_debt 偿还

所有技术债都要修。功能 task 全跑完后，leader 读 `docs/harness_execution/tech_debt.md`，按债项分组拆成若干偿还 task，走标准开发循环（spec/plan/coder/review/收口）。

- 环境债（依赖宿主机/CI/外部 key）→ 开 task 时标 `blocked_by`，等环境就位再跑，不停下问。
- 偿还 task 的依赖列：只依赖它要改的代码所属的已完成 task。
- 不在功能 task 跑到一半插偿还 task——等当前波次收口。

---

## 通信协议

leader 是唯一编排者，teammate 之间不直接通信。

- leader → teammate：SendMessage 派任务，附 task ID + workspace 路径（spec/plan 在里面）
- teammate → leader：SendMessage 报告完成 + verdict（PASS/FAIL）
- **review 判定**：脚本模式调 `task_review.js`，读返回 `{passed, blockers, techDebt}`；手工模式 `head -1 review_*.md` / `grep '^verdict:'` 取首行，不读正文。两份 PASS → 收口；任一 FAIL → 进 FAIL 轮。
- **FAIL 轮（默认交回 Teams coder）**：leader 把 blockers 发回原 coder → coder 读 review_*.md 正文改代码 + 在同文件追加"修改记录"段（禁碰 context.md）→ leader 再调 task_review.js 重审（或手工派双 review 重读）。max 3 轮。可选 task_review_autofix.js 处理 scope 内小修（1 轮，超限 escalate 回 coder）。
- PASS：leader 直接收口（改共享文档、提交）

teammate prompt 里只说"读 X 文件、写到 Y 文件、首行 `verdict: PASS/FAIL`"。文件名固定，不靠自然语言传话。

## 上下文管理（自动 compact）

**磁盘是真状态，teammate 和 leader 上下文都是可重建缓存。**

### teammate 层（按角色分阈值，不一刀切）

teammate 无自动 compact，且各角色上下文增长模式不同：coder 累积写代码/测试/多轮改，增长快、跨 task 会污染；reviewer/test-reviewer 每次只读 diff 写意见，增长极慢。所以分角色管理。

**查上下文方法**：`tmux capture-pane -t <paneId>` 读状态栏 `Xk/Yk`（如 `90k/200k`=45%）。paneId 在 team config.json 的 member.tmuxPaneId。

**coder**（每次派活前查）：
- 状态栏读不到 → **强制重 spawn**（保守）
- 200K 窗口 → **每次派活前重 spawn**（窗口太小，必满）
- 1M 窗口 → 占用 **≥40% 才重 spawn**，否则复用
- **只在 task 之间的边界查阈值**。task 内修复轮（FAIL 重做）不 spawn——中途 spawn 会丢已读的 spec/plan/上一轮代码，撑到本 task 闭环。

**reviewer / test-reviewer**：
- **常驻复用，绝不为换窗口而 spawn**。1M 窗口审几十个 task 都用不完，重 spawn 浪费且丢项目理解。
- 仅当占用 **≥70% 才 compact**（不 spawn）。

重 spawn 的 coder 从 spec/plan/context.md 重建上下文，不依赖记忆。

### leader 层（自动 compact）

每 task 闭环后 leader 执行：

1. 写 `docs/harness_execution/leader_checkpoint.md`，内容：
   - 刚完成的 task ID + commit hash
   - tasks_list.json 当前状态快照（哪些 done / 阻塞 / 待开始）
   - 下一个要跑的 task ID
   - team 当前 teammate 状态
   - **team config 路径** `~/.claude/teams/{team-name}/config.json`（compact 恢复时查 team 还在不在、paneId 在哪）
2. 自检：剩余上下文是否够跑完下一个 task（粗估，看已用轮数和对话长度）
3. 可疑或每 3 个 task 强制 → 调 `/compact`

compact 后 leader 从三处恢复：
- `docs/harness/agent_protocol.md`（本文件）
- `docs/harness_execution/tasks_list.json`（状态）
- `docs/harness_execution/leader_checkpoint.md`（断点）

### compact 恢复流程

1. 读 leader_checkpoint.md → 知道断在哪
2. 读 tasks_list.json → 确认状态
3. 读本协议 → 重建编排逻辑
4. 若有 tasks/{TID}/ 存在且未归档 → 该 task 中途断，从 context.md 续；否则从选 task 规则开新 task
5. 重建 team（若 team 还在则复用，否则 TeamCreate）

**⚠️ checkpoint 只给断点，不给调度结论**：

- checkpoint 里写的"串行/并发"是上次的快照，恢复后**必须按"第 0 步：开工调度"重算 DAG 层宽**，不能吃 checkpoint 惯性直接单跑（曾有恢复后该并发却串行的问题）
- teammate idle ≠ 不可用，**idle = 可唤醒资源**：FAIL 轮/新 review 一律 SendMessage 唤醒原实例，绝不新 spawn
- spawn 只用于"全新 task + coder 上下文已满需重建"

---

## 阻塞项处理（全自动，不停下问）

tasks_list.json 中的阻塞项未解决前相关 task 跳过，标记 `status=阻塞, blocked_by={原因}`。阻塞类型由项目实际决定，常见几类：

| 阻塞类型 | blocked_by 值 | 处理 |
|---|---|---|
| 外部密钥/凭据缺失（API key、DB 凭据等） | `key` | 跳过，标"status=阻塞, blocked_by=key" |
| 域名/外部端点缺失 | `domain` | 跳过，标"status=阻塞, blocked_by=domain" |
| 3 轮 review 仍 FAIL | `quality` | 跳过，标"status=阻塞, blocked_by=quality" |
| spawn 失败 | `spawn` | 跳过，标"status=阻塞, blocked_by=spawn" |

依赖被阻塞 task 的下游 task 自动顺延（选 task 规则自然过滤）。可用占位/mock 绕过且不影响核心功能的，记 tech_debt 不阻塞。

第 3 轮 review 仍 FAIL → 写 `docs/harness_execution/issues/{TID}_quality.md`，标"status=阻塞, blocked_by=quality"，跳过继续。

所有可跑 task 跑完后，若仍有阻塞 task，leader 停下报告：哪些阻塞、缺什么、需用户提供什么。

### spawn 失败处理

coder/reviewer spawn 可能因 API 错误、rate limit 失败，协议不假设 spawn 总成功：

1. spawn 失败 → 退避重试 2 次（间隔递增）
2. 仍失败 → 该 task 标"status=阻塞, blocked_by=spawn"（`blocked_by: "spawn"`），写 `docs/harness_execution/issues/{TID}_spawn.md` 记录错误
3. 跳过该 task，继续下一个（同波次其他 task 不受影响）

### 并发波次内 FAIL 语义

- 波次内单 task FAIL（review 轮次中）**不阻塞同波次其他独立 task**——它们各自走自己的 review 流程。
- FAIL task 的**下游依赖 task 自动顺延到下一波次**（依赖未完成，选 task 规则自然过滤）。
- FAIL task 3 轮后标"status=阻塞, blocked_by=quality"，下游依赖若全部依赖它则连锁阻塞，否则可绕过。

### 回滚流程

"回滚以 task 为粒度"的具体操作：

1. `git revert <task_commit>`（生成反向 commit，不改历史，安全）
2. tasks_list.json 该 task status 回 `待开始`
3. 下游依赖该 task 的 task，status 也回 `待开始`（依赖被回滚，需重跑）
4. 若该 task 已归档到 `docs/harness_record/tasks/{TID}/`，git mv 回 `docs/harness_execution/tasks/{TID}/`
5. 重新进入开发循环

不用 `git reset`（会丢历史，危险）。回滚后下游重跑，不连锁回滚下游（只重置状态）。

---

## Workflow 化（review gate 定位）

> ⚠️ 状态：脚本已写，未实跑验证。**验证前仍走手工编排（通信协议 + 单 task 流程 step 4-5）。**
> 验证通过后，`task_review.js` 取代 step 4-5 的"派 review + head-1 取 verdict"那段判定；FAIL 轮仍由 leader 驱动（发回 Teams coder）。

**定位（定死，不再追求全流程自动化）**：Workflow 只做单 task 的 review gate——并行跑 reviewer+test-reviewer、schema 强制 verdict、汇总 blockers/techDebt。**不替代 coder、不替代并发调度、不替代收口、不替代 task 间隔离。**

| 环节 | 谁做 | Workflow 插手？ |
|---|---|---|
| task 间隔离 | leader 手动 `git worktree add` | ❌ git worktree 的活，与 Workflow 无关 |
| 并发调度 | leader 算 DAG layer，手动开多个 worktree | ❌ leader 编排 |
| coder（写代码 + FAIL 轮修复） | Teams teammate（默认） | ❌ 有状态、可介入，留 Teams |
| 单 task review 判定 | **`task_review.js`** | ✅ 无状态 fan-out + schema verdict |
| FAIL 轮小修（可选） | `task_review_autofix.js` | ✅ 仅 scope 内 lint/断言/边界/类型小修 |
| 收口 / commit / 合并 worktree | leader 串行 | ❌ |

**脚本**：`docs/harness/workflows/task_review.js`（主用，单轮 review gate）、`task_review_autofix.js`（可选，1 轮 scope 内 autofix）、`task_full.js`（可选，仅小独立 task 全自动）。并发隔离靠 leader 手动 git worktree，不靠脚本。

接口/参数/返回 + **脚本选择标准**：`docs/harness/workflows/README.md`；设计 why：`docs/harness/workflow_design.md`；隔离决策：`docs/harness/worktree_isolation.md`。

**默认 FAIL 路径（最稳）**：task_review.js 返回 `{passed, blockers}` → 若 FAIL，leader 把 blockers 发回**原 Teams coder** → coder 改代码 + 在 review_*.md 追加修改记录（禁碰 context.md）→ leader **再调 task_review.js** → max 3 轮。coder 跨轮保留状态，不必从 spec 重建。

**autofix 何时用**：FAIL 项全是 lint/测试断言/小边界/类型错误等局部小修，且改动在 task scope 内、不涉及架构/接口/数据模型。超过则 escalate 交回 Teams coder。默认不用 autofix。

落地后协议改动（仅在脚本跑通后）：
- step 4-5 的"派 reviewer+test-reviewer → head-1 取 verdict" → 调 `task_review.js` 读返回 `{passed, blockers, techDebt}`
- FAIL 轮仍按 step 5 走（发回 Teams coder），只是 verdict 判定改由脚本返回
- 并发隔离始终靠 leader 手动 git worktree，**不用** `isolation:'worktree'`（粒度是 agent 不是 task，详见 worktree_isolation.md）
- 落地纪律见 README：脚本先跑通 → 改协议指令 → 真相不写未验证脚本

## 运行模式

开 goal 模式持续运行。每个 task 闭环是天然 checkpoint。遇阻塞跳过不停。全部可跑 task 完成 → 终止报告。

## 不做

- 不停下问用户（除非全部可跑 task 跑完仍剩阻塞）
- teammate 之间不直接通信
- 中间状态不 commit
