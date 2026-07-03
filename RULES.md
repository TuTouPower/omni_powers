# 多 Agent 协作工作流协议（运行时操作手册）

> **定位**：compact 恢复入口 + 跨 agent/skill 的全局运行时视图。只写谁都展开不深的全局规则，**不重复** agent/skill/design 的内容。
> **设计理由**见 `$OP_HOME/docs/omni_powers_design.md`（设计档案，不进运行时）。
> **各 agent 行为**见 `$OP_HOME/agents/*.md`；**各 skill 流程**见 `$OP_HOME/skills/*/SKILL.md`。
> **模板/脚本**通过 `$OP_HOME`（插件安装目录环境变量）引用。
>
> compact 恢复：读本文件 + jq 查 `tasks_list.json`（⚠️ 严禁 Read 整文件）+ 读 `leader_checkpoint.md`。
>
> **核心心智**：磁盘是真状态，所有 agent 上下文都是可重建缓存。全线 Sub Agent，每次 fresh dispatch。

## 角色拓扑

leader（主会话/controller，被 oprun 驱动）+ op-implementer + op-reviewer + op-evaluator + op-closer。职责细节见各 agent.md。全线 Sub Agent，每次 task fresh dispatch，上下文隔离。

模型环境变量：`OP_IMPLEMENTER_MODEL` / `OP_REVIEWER_MODEL` / `OP_EVALUATOR_MODEL` / `OP_CLOSER_MODEL`，值填 `haiku`/`sonnet`/`opus` 之一；未设则继承主会话当前模型。**spec 编写（含设计探索）归 leader 主会话**，不走 dispatch——闸门 A 前 `/model` 切 Opus（错误放大系数最大）。

## 状态机

```
待规划 → 待开始 → 进行中 → 审阅中 → 收口中 → 完成
  ↓             ↑        ↓ (FAIL，max 2 轮)
挂起 ───────────┘        └────────┘
                        第 2 轮仍 FAIL → 阻塞(blocked_by=quality)
```

| status | 含义 | blocked_by |
|---|---|---|
| `待规划` | 刚从需求解析出，只有一句话，无 spec | null |
| `待开始` | spec 就位，未开发 | null |
| `进行中` | implementer 开发或修复轮中 | null |
| `审阅中` | review 进行中 | null |
| `收口中` | 双裁决 PASS 后，closer 执行中 | null |
| `完成` | closer 返回 + leader 审批 + close_check 通过 | null |
| `阻塞` | 2 轮 FAIL 或环境阻塞 | `resource`/`quality`/`spawn`（必有值） |
| `跳过` | 因下游阻塞顺延 | null |
| `挂起` | 用户明确推迟，需用户同意才做 | null |

状态修改：`bash $OP_HOME/scripts/op_status.sh <TID> <status> [blocked_by]`。

### 阻塞项处理

| 类型 | blocked_by | 处理 |
|---|---|---|
| 外部资源缺失（密钥/端点等） | `resource` | 跳过，标阻塞 |
| 2 轮 FAIL | `quality` | 写 issues/{TID}_quality.md，跳过 |
| spawn 失败 | `spawn` | 退避重试 2 次，仍败则标阻塞 |

### 下游传播

- task 阻塞后，其直接/间接下游 status 改 `跳过`。
- **绕过**：下游实际不依赖被阻塞 task 产出时，leader 可改该下游 `depends_on` 移除阻塞节点，decisions.md 记理由。无记录则不可绕过。
- 阻塞解除后，`跳过` 的 task 恢复 `待开始`。
- 所有可跑 task 跑完仍剩阻塞，leader 才停下报告。

### 挂起项处理

`挂起`：用户主动推迟，不自动流转。恢复后据是否已生成 spec 回到 `待开始` 或 `待规划`。

### 回滚

不用 reset（丢历史）。

1. `git revert <commit_hash>` — 反向提交
2. `bash $OP_HOME/scripts/op_status.sh {TID} 待开始` — 该 task 回退
3. `bash $OP_HOME/scripts/op_jq.sh downstream {TID}` 查下游，逐一回退
4. 已归档的 task：`git mv op_record/tasks/{TID} op_execution/tasks/{TID}` 移回工作区

不连锁回滚下游，只重置状态。

## depends_on

每个 task 的 `depends_on` 记前置依赖（数组，无依赖则 `null`）。jq 查 `tasks_list.json` 判拓扑顺序。

## tasks_list 拆分预案

默认不拆，单文件靠 jq 查。task 量大时启用：

- `op_execution/tasks_list.json` — 只留未完成
- `op_record/tasks_done.json` — 已完成，裁剪到最小（id/title/depends_on/commit）
- 活表查不到的依赖 → 查 done 表
- 收口时 task 从活表移到 done 表

## compact 恢复

读本文件 + jq 查 `tasks_list.json` + 读 `leader_checkpoint.md`。

⚠️ 严禁 Read 整文件 `tasks_list.json`，用 `$OP_HOME/scripts/op_jq.sh` 或 jq。

```bash
bash $OP_HOME/scripts/op_jq.sh pending          # 待开始
bash $OP_HOME/scripts/op_jq.sh pending_plan     # 待规划
bash $OP_HOME/scripts/op_jq.sh deps {TID}       # 依赖
bash $OP_HOME/scripts/op_jq.sh blocked          # 阻塞
bash $OP_HOME/scripts/op_jq.sh skipped          # 跳过
bash $OP_HOME/scripts/op_jq.sh suspended        # 挂起
bash $OP_HOME/scripts/op_jq.sh downstream {TID} # 下游
bash $OP_HOME/scripts/op_jq.sh all              # 全部概览
```

**checkpoint 只给断点，不给调度结论**——恢复后必须重算可跑 task。

**恢复步骤**：读 checkpoint → jq 查 tasks_list → 读本协议 → 有未归档 `tasks/{TID}/` 则从 report.md + review.md 重建状态 → 重新选 task。Sub Agent 每次重新 dispatch，不需恢复 agent 实例。

## 跨 agent 铁律

- 磁盘是真状态，agent 上下文是可重建缓存
- 全线 Sub Agent，每次 fresh dispatch，上下文隔离
- 证据由机器产出，无新鲜机器证据的"完成"无效
- task = commit，粒度沿低耦合缝隙切
- review ≤2 轮，两轮修不平是结构问题（详见 op-reviewer.md）
- issue 不直接改代码，转正式 task 走 change type 流程
- 中间状态不 commit；大 task 允许 `wip({TID})` 纯代码 sub-commit，不触发收口
- Sub Agent 之间不直接通信
- worktree/分支模式选择见 oprun/SKILL.md
- 不生成 dag.md

## 不做

- 不停下问用户（除非可跑 task 跑完仍剩阻塞，或契约边界规则触发 spec 变更——见 design.md §5.2）
- op-closer 不直接写 `op_blueprint/`（产提案，leader 审批后写入；decisions.md 直接 append 自决决策）。**decisions.md 两写入者**：spec 编写者（设计探索全文，design §5.2）+ closer（执行期自决决策）
- 其余见"跨 agent 铁律"
