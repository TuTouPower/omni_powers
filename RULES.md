# 多 Agent 协作工作流协议

> **唯一编排依据**——所有编排决策以本协议为准。执行流程见 skills。
> compact 恢复：读本文件 + 用 jq 查询 `tasks_list.json`（⚠️ 严禁 Read 整文件）+ 读 `leader_checkpoint.md`。
> 决策依据见 `docs/omni_powers/op_decisions.md`，实验记录见 `docs/omni_powers/op_findings.md`。
>
> **核心心智模型**：磁盘是真状态，所有 agent 上下文都是可重建缓存。全线 Sub Agent，每次 fresh dispatch。
>
> **v5 对齐**：规格是唯一契约；两层 spec（生效规格 ⟵ 工作 spec 淬炼）；能在 spec 期解决的不留执行期；契约边界规则；测试按耦合物分层；证据由机器产出；plan 是分布式信息无独立文档；task=commit；review ≤2 轮。

## 角色

| 角色             | 类型      | model（环境变量，见下）  | 派发     | 职责                                                                                            |
| ---------------- | --------- | ---------------- | -------- | ----------------------------------------------------------------------------------------------- |
| leader           | 主会话    | —                | —       | **controller 即 leader 主会话**，被 oplead skill 驱动。编排、commit、写 checkpoint、审批 closer 提案后执行生效规格写入 |
| op-implementer   | Sub Agent | `OP_IMPLEMENTER_MODEL` | 前台     | TDD：写测试→写实现→跑测试→写 report。设计 task 复用之（brief 指明"只产方案纸"，临时设为 opus） |
| op-reviewer      | Sub Agent | `OP_REVIEWER_MODEL`    | 前台     | 双裁决：①规格合规（覆盖 AC/不偏航/不自由发挥）②测试可信（防假绿/查危险 expect·assert 变更）。写 review.md |
| op-evaluator     | Sub Agent | `OP_EVALUATOR_MODEL`   | 前台     | 验收方：spec 级真机验收与对抗探索，仅 Stage 5（所有 task 闭环后）介入。评估 → 固化 → 破坏检查，产出 e2e/ |
| op-closer        | Sub Agent | `OP_CLOSER_MODEL`      | 前台     | 收口整理：产 blueprint_update.md 提案 + 直接追加 decisions.md；末 task 顺带叶子归档提案 |

全线 Sub Agent。每次 task 重新 dispatch，上下文隔离。

**模型环境变量**：`OP_IMPLEMENTER_MODEL` / `OP_REVIEWER_MODEL` / `OP_EVALUATOR_MODEL` / `OP_CLOSER_MODEL`。值只能填 `haiku` / `sonnet` / `opus` 三档之一，对应 `settings.json` 里的 `ANTHROPIC_DEFAULT_HAIKU_MODEL` / `ANTHROPIC_DEFAULT_SONNET_MODEL` / `ANTHROPIC_DEFAULT_OPUS_MODEL` 解析出的实际模型。**未设则不传 model 参数，继承主会话当前模型**（用户可用 `/model` 随时切换）。设了哪个就覆盖该 agent 用对应档位。

## 状态机

```
待规划 → 待开始 → 进行中 → 审阅中 → 收口中 → 完成
  ↓             ↑        ↓ (FAIL，max 2 轮)
挂起 ───────────┘        └────────┘
                        第 2 轮仍 FAIL → 阻塞(blocked_by=quality)
```

tasks_list.json status 值：

| status     | 含义                                       | blocked_by                                   |
| ---------- | ------------------------------------------ | -------------------------------------------- |
| `待规划` | 刚从需求解析出 task，只有一句话，没有 spec | null                                         |
| `待开始` | spec 就位，未开发                          | null                                         |
| `进行中` | op-implementer 开发或修复轮中              | null                                         |
| `审阅中` | review 进行中                              | null                                         |
| `收口中` | 双裁决 PASS 后，op-closer 执行中           | null                                         |
| `完成`   | closer 返回 + leader 审批写入 + close_check 通过 | null                                         |
| `阻塞`   | 2 轮 FAIL 或环境阻塞                       | `resource`/`quality`/`spawn`（必有值） |
| `跳过`   | 因下游阻塞顺延，等待阻塞解除               | null                                         |
| `挂起`   | 用户明确指示暂时不做，需用户同意才能做     | null                                         |

状态修改：`bash scripts/op_status.sh <TID> <status> [blocked_by]`。

### 阻塞项处理

| 类型                        | blocked_by   | 处理                             |
| --------------------------- | ------------ | -------------------------------- |
| 外部资源缺失（密钥/端点等） | `resource` | 跳过，标阻塞                     |
| 2 轮 FAIL                   | `quality`  | 写 issues/{TID}_quality.md，跳过 |
| spawn 失败                  | `spawn`    | 退避重试 2 次，仍败则标阻塞      |

### 下游传播

- 某 task 阻塞后，其直接/间接下游 status 改为 `跳过`。
- **绕过**：若下游 task 实际上不依赖被阻塞 task 的产出，leader 可修改该下游 task 的 `depends_on` 移除阻塞节点，并在 decisions.md 记录理由。无此记录则不可绕过。
- 阻塞解除后，`跳过` 的 task 恢复 `待开始`。
- 所有可跑 task 跑完后仍有阻塞，leader 才停下报告阻塞项、缺什么、需用户提供什么。

### 挂起项处理

- `挂起`：用户主动推迟。不自动流转，除非用户要求恢复。恢复后根据是否已生成 spec，回到 `待开始` 或 `待规划`。

### 回滚

不用 reset（会丢历史）。

1. `git revert <commit_hash>` — 反向提交
2. `bash scripts/op_status.sh {TID} 待开始` — 该 task status 回退
3. `bash scripts/op_jq.sh downstream {TID}` 查下游 task，逐一 `op_status.sh {下游TID} 待开始`
4. 若该 task 已归档到 `docs/omni_powers/op_record/tasks/{TID}/`：`git mv docs/omni_powers/op_record/tasks/{TID} docs/omni_powers/op_execution/tasks/{TID}` — 移回工作区

不连锁回滚下游，只重置状态。下游 status 回退后依赖链完整，选 task 规则自然重新调度。

## 文件分层

### task 工作区（全部进 git）

```
docs/omni_powers/op_execution/
├── specs/{前缀}.md           # 工作 spec（叶子共享，全员只读。AC/INV/边界/技术决策/可测性契约）
├── tasks/{TID}/
│   ├── brief.md               # leader 生成（任务卡 + 定向包 + 指向 spec 路径）
│   ├── report.md              # op-implementer 写：顶部总报告（每轮覆盖）+ 分 Round 追加
│   ├── review.md              # op-reviewer 写双裁决，FAIL 轮 implementer 追加 Fix-N
│   └── baselines/             # evaluator 产出的基准快照（临时，待 closer 提案 + leader 审批合入 op_blueprint）
├── tasks_list.json            # 唯一 task 真相源
├── leader_checkpoint.md
└── issues/
```

- spec.md 不在 task 目录——spec 是叶子级共享，放 `op_execution/specs/`。
- report.md 顶部总报告（leader/reviewer 入口，每轮覆盖为累积总结）+ 下方分 Round 追加（审计轨迹，FAIL 轮修复留得住）。
- task 闭环后 git mv 到 `docs/omni_powers/op_record/tasks/{TID}/` 归档。

### 持久文件

| 路径                                                   | 谁写               | 何时                                         |
| ------------------------------------------------------ | ------------------ | -------------------------------------------- |
| `docs/omni_powers/op_execution/tasks_list.json`      | 机械脚本/leader | 状态流转（**唯一 task 真相源**）             |
| `docs/omni_powers/op_blueprint/`（specs/architecture/domain/conventions/prd/test/baselines） | **leader**（基于 closer 提案） | 每 task 闭环后审批写入（最高契约，含基准快照）       |
| `docs/omni_powers/op_record/progress.md`             | 机械脚本        | 闭环后追加                                   |
| `docs/omni_powers/op_record/decisions.md`            | op-closer       | 有决策直接 append（契约边界内自决/架构决策/spec 变更 delta/测试解锁归因） |
| `docs/omni_powers/op_record/tasks/{TID}/blueprint_update.md` | op-closer | 每 task 闭环产「blueprint 更新提案」(diff 形态，覆盖 op_blueprint 全部文档) |
| `docs/omni_powers/op_execution/leader_checkpoint.md` | leader          | 每 task 闭环后写                             |
| `docs/omni_powers/op_execution/issues/`              | leader/reviewer/evaluator/op-closer | 范围外发现、2 轮残留、技术债（加 `tech-debt` 标签） |

技术债登记为 issue，加 `tech-debt` 标签，与 P0-P3 严重度正交，走 optriage 分级。依赖管理通过 `tasks_list.json` 的 `depends_on` + jq 查询判断拓扑顺序。

### 闭环整理（closer 提案制）

task 闭环分三段：

1. `scripts/op_close_pre.sh {TID}`：负责 spec 盖戳和 `status=收口中`。
2. **op-closer 整理**：
   - 产「blueprint 更新提案」写入 `docs/omni_powers/op_record/tasks/{TID}/blueprint_update.md`，diff 形态覆盖 `op_blueprint/` 全部文档（新增/修改/删除各附一句理由）。只留"现在是什么"，过滤被否方案/临时假设。
   - 直接 append 决策到 `docs/omni_powers/op_record/decisions.md`（append-only 历史，不经 leader 审批）。
   - 末 task 顺带做叶子级归档提案（总述关闭、前缀释放）。
   - **铁律**：op-closer 对 `op_blueprint/` 无写权限；不碰 git、不改 status、不归档、不盖戳、不 stage。
3. leader 审批 closer 的 blueprint 提案 → 执行实际写入 `op_blueprint/` → `scripts/op_close_post.sh {TID} {feature}` 确认 review verdict PASS、spec 已盖戳，git mv 归档、追加 progress、`status=完成`、git add 收口文档。

归档 task spec 顶部盖戳冻结——归档后的 task spec 是历史快照，会过时；当前代码"是什么"靠 `op_blueprint/` 下的文件（由 leader 基于 closer 提案维护）。

**新建文件规则**：一律先拷 `docs_template/omni_powers` 下对应模板再填内容。无对应模板才自建。

## 关键规则

### review 判定（双裁决，≤2 轮）

- leader 派 op-reviewer 单 agent 做 review（前台 Sub Agent）
- review 文件**最后一行**必须是 `verdict: PASS` 或 `verdict: FAIL`（首轮写一行，重审追加一行）
- 双裁决 PASS → 收口。任一裁决 FAIL → implementer 修改后重新 review，**同一 task 最多 2 轮**
- 第 2 轮仍 FAIL → status=阻塞, blocked_by=quality，写 `issues/{TID}_quality.md`，下游 task 改为 `跳过`
- **双裁决内容**：①规格合规（覆盖声明 AC？偏离 spec/自由发挥/范围偏航？）②测试可信（测的是 AC 还是 mock？断言用户可观察？命中危险模式？）
- **分类体系**：CRITICAL / HIGH / MEDIUM / LOW 四级
- **暂存标签**：默认不暂存。暂存条件：跨 scope / 需环境变更 / 架构决策 / 依赖未来 task
- **PASS 门槛**：所有未标暂存的问题必须修完才 PASS
- **reviewer 出错处理**：重试（max 3）。重试仍失败 → review.md 写 `verdict: FAIL`
- 两轮修不平大概率是结构问题（方案错/拆分错/规格歧义），继续循环只是烧 token。

### 契约边界规则（执行期决策分流）

执行期一切决策先问一句——**需要改 spec 文本吗？**

- **不需要**（spec 约束内选库/选内部算法/选路径）→ implementer 自决 + 记 decisions.md 打标记 + 闸门 C 批量报审，流水线不停。
- **需要**（INV 守不住/AC 做不到/契约要变）→ spec 变更子流程：agent 提 delta → 人批 → 重新 commit → 受影响 task 失效重拆。执行期唯一允许阻塞等人的情形。

### evaluator 访问隔离与刻薄化调教

防evaluator 读实现源码后照着实现写测试（实现错→测试跟着错→一起绿）。两层隔离：

1. **文件系统层**：初期 worktree + hook——evaluator 在隔离 worktree 中工作，hook 硬拦 Read/Grep 命中 `src/**`（机械可审计，零基建）。后期升级为独立验证环境：CI 构建产打包应用，evaluator 仅接触产物+spec+e2e，源码不在文件系统中。
2. **报告回流层**：oplead 组装 evaluator brief 时，**输入白名单只有 spec + 生效规格 + 应用启动方式**，不含 implementer 的 report、diff、review。反方向信息流是安全的（FAIL 转 bug task）。

> 隔离防"抄实现"，防不了"放水"。放水靠三样：hard-pass gate（evaluator prompt 内置，禁止推论式 PASS）+ 破坏检查（机械的——固化测试必须能红）+ 刻薄化调教循环（以下）。

**刻薄化调教循环**：

stock evaluator 默认对 LLM 产出宽容——能发现 bug 但会说服自己"不太严重"放行，或只测成功路径不探边界。调教目标是让它足够刻薄。操作方式：

1. **每次 spec 验收后，leader 做二阶判断**：从验收报告中随机抽 1-2 条 AC，对照评估证据。评估深度够不够？evaluator 有没有只测了成功路径？证据是否亲眼观察而非推测？
2. **写偏差指令而非评分**：发现放水，在验收报告末尾追加一条具体指令——"AC-N 你只测了提交成功，边界的密码错误转向路径没测。补测后重新判定。" 这种指令型偏差比"上次偏了 12%"更有用——它直接告诉 evaluator 下次遇到同类 AC 要测到什么深度。
3. **积累校准素材**：每积累 5 条偏差指令，从中选 2 条最典型的改写为 few-shot 校准样例，进入 evaluator agent prompt 的"校准样例"段。旧样例可淘汰。
4. **收敛标准**：连续 3 spec 验收中 evaluator 提出的 FAIL 项至少 1 条是 implementer/reviewer 都未发现的真 bug；或系统层夜跑 30 天内抓到 ≥1 次回归。达到 → 标记调校完成，降频为每 5 spec 抽查一次。达不到 → 每次验收都抽查，持续积累偏差指令。

### 工作区

一个 task 一个 commit，在同一个工作目录上操作。当前仅规划阶段可并行；代码执行并行需要独立 worktree + 串行 merge，暂不启用。

- `/oprun` 启动时查仓库主分支名（main/master），问用户：worktree（推荐）/ 主分支 / 当前分支
- worktree 模式：`git worktree add .worktrees/op-dev -b feat/op-dev`，全 session 共用，贯穿所有 task。**所有 task 完成之后**，leader 才切回原分支合并并移除。未完成前不拆 worktree、不 merge 分支
- 主分支模式：直接在主分支（main/master）工作，不创建 worktree
- 当前分支模式：不动分支，在当前分支直接工作
- leader 将当前工作目录传给所有 subagent 的 dispatch prompt

大 task 跑很久时，允许 `wip({TID})` 性质的纯代码落盘 sub-commit——**不触发任何收口动作**。收口时由 leader 定 squash 还是保留。

### depends_on

每个 task 的 `depends_on` 记录其前置依赖（数组，无依赖则 `null`）。依赖通过 jq 查询 `tasks_list.json` 判断拓扑顺序。

### tasks_list 拆分预案

默认不拆，单文件靠 jq 查询。task 量大到单文件过大、查询变慢时启用：

- `docs/omni_powers/op_execution/tasks_list.json` — 只留未完成（待开始/进行中/审阅中/收口中/阻塞/跳过）
- `docs/omni_powers/op_record/tasks_done.json` — 已完成 task，裁剪到最小（id/title/depends_on/commit）
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

**checkpoint 只给断点，不给调度结论**——恢复后必须重算可跑 task。

**恢复步骤**：读 checkpoint → 用 jq 查询 tasks_list → 读本协议 → 若有未归档 `tasks/{TID}/` 则从 report.md + review.md 重建状态 → 重新选 task。Sub Agent 每次重新 dispatch，不需要恢复 agent 实例。

## 不做

- 不停下问用户（除非全部可跑 task 跑完仍剩阻塞，或契约边界规则触发 spec 变更）
- Sub Agent 之间不直接通信
- 中间状态不 commit
- op-closer 不直接写 `op_blueprint/`（产提案，leader 审批后写入；decisions.md 直接追加）
- 不生成 dag.md
