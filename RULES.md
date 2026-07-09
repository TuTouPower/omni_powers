# 多 Agent 协作工作流协议（运行时操作手册）

> **定位**：compact 恢复入口 + 跨 agent/skill 的全局运行时视图。只写谁都展开不深的全局规则，**不重复** agent/skill/design 的内容。
> **设计理由**见 `$OP_HOME/docs/omni_powers_design.md`（设计档案，不进运行时）。
> **各 agent 行为**见 `$OP_HOME/agents/*.md`；**各 skill 流程**见 `$OP_HOME/skills/*/SKILL.md`。
> **模板/脚本**通过 `$OP_HOME`（插件安装目录环境变量）引用。
>
> compact 恢复：先读 `docs/omni_powers/profile`（判定 heavy/lite）→ 按 profile 选状态机（见「profile 分叉」段）→ jq 查 `tasks_list.json`（⚠️ 严禁 Read 整文件）+ 读 `leader_checkpoint.md`。
>
> **核心心智**：磁盘是真状态，所有 agent 上下文都是可重建缓存。全线 Sub Agent，每次 fresh dispatch。

## 角色拓扑

leader（主会话/controller，被 oprun 驱动）+ op-implementer + op-reviewer + op-evaluator + op-closer。职责细节见各 agent.md。全线 Sub Agent，每次 task fresh dispatch，上下文隔离。

模型环境变量：`OP_IMPLEMENTER_MODEL` / `OP_REVIEWER_MODEL` / `OP_EVALUATOR_MODEL` / `OP_CLOSER_MODEL`，值填 `haiku`/`sonnet`/`opus` 之一；未设则**不传 model 参数，继承主会话当前模型——dispatch 绝不准自行指定 model**（推荐档仅作用户配置参考）。**spec 编写（含设计探索）归 leader 主会话**，不走 dispatch——闸门 A 前 `/model` 切 Opus（错误放大系数最大）。

## 状态机

```
pending → ready → in_progress → reviewing → closing → done
  ↓             ↑        ↓ (FAIL，max 2 轮)
suspended ───────────┘        └────────┘
                        第 2 轮仍 FAIL → blocked(blocked_by=quality)

obsolete（方案调整废弃，不参与流转，spec 移 op_record/specs/obsolete/）
```

| status | 含义 | blocked_by |
|---|---|---|
| `pending` | 刚从需求解析出，只有一句话，无 spec | null |
| `ready` | spec 就位，未开发 | null |
| `in_progress` | implementer 开发或修复轮中 | null |
| `reviewing` | review 进行中 | null |
| `closing` | 双裁决 PASS + merge gate PASS 后，leader 跑 `op_close_pre.sh` 标此态，closer per-task 收口进行中（heavy 独有） | null |
| `done` | review PASS + merge gate PASS + closer append decisions.md 且 commit + leader 跑 `op_close_post.sh`（归档 + 标完成）；**evaluator 验收 PASS 是前置** | null |
| `blocked` | 2 轮 FAIL 或环境阻塞 | `resource`/`quality`/`spawn`（必有值） |
| `obsolete` | 方案调整废弃、未开始；spec 移 `op_record/specs/obsolete/`；TID 不复用 | null |
| `suspended` | 用户明确推迟，需用户同意才做 | null |

状态修改：`bash $OP_HOME/scripts/op_status.sh <TID> <status> [blocked_by]`。

### 阻塞项处理

| 类型 | blocked_by | 处理 |
|---|---|---|
| 外部资源缺失（密钥/端点等） | `resource` | 跳过，标阻塞 |
| 2 轮 FAIL | `quality` | 写 issues/{TID}_quality.md，跳过 |
| spawn 失败 | `spawn` | 退避重试 2 次，仍败则标阻塞 |

### 下游传播（A16：不设 skipped 态，调度器派生）

- task 阻塞后，下游**保持 `ready`**（调度器依 depends_on 不选中，不另设 skipped 态）。
- **绕过**：下游实际不依赖被阻塞 task 产出时，leader 可改该下游 `depends_on` 移除阻塞节点，decisions.md 记理由。无记录则不可绕过。
- 阻塞解除后，下游可被调度器选中。
- 所有可跑 task 跑完仍剩阻塞，leader 才停下报告。

### 挂起项处理

`挂起`：用户主动推迟，不自动流转。恢复后据是否已生成 spec 回到 `待开始` 或 `待规划`。

### 回滚

不用 reset（丢历史）。

1. `git revert <commit_hash>` — 反向提交
2. `bash $OP_HOME/scripts/op_status.sh {TID} ready` — 该 task 回退
3. `bash $OP_HOME/scripts/op_jq.sh downstream {TID}` 查下游，逐一回退
4. 已归档的 task：`git mv docs/omni_powers/op_record/tasks/{TID} docs/omni_powers/op_execution/tasks/{TID}` 移回工作区

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
- **入口检查环境**：任何 skill/agent 入口先跑 `bash "$OP_HOME/scripts/op_check_env.sh"`（jq/git/OP_HOME，缺失 die + 装法提示），绝不闷头失败——Windows 无 jq 是常见坑
- task = commit，粒度沿低耦合缝隙切
- **决策记录策略（design §2.2）**：执行期决策 agent 自决，不阻塞等人。判据=是否需要进 spec——小决策（选库/算法/路径，不进 spec）直接做，**不记 decisions.md**；需进 spec 的→leader 改 task spec + 记 decisions.md（spec-delta）+ 事后报告（闸门 C）。closer 只收红灯归因（red-attribution），spec-delta 归 leader 子流程写。
- review ≤2 轮；per-task 验收 ≤3 轮（到顶分流详见 `skills/oprun/SKILL.md` 验收段与 design §2.4/§2.5）
- issue 不直接改代码，转正式 task 走 change type 流程
- 中间状态不 commit；大 task 允许 `wip({TID})` 纯代码 sub-commit，不触发收口
- Sub Agent 之间不直接通信
- **worktree sparse-checkout 隔离已落地（advisory）**：evaluator worktree 无 `src/`、implementer worktree 无 `e2e/`（git 2.25+，design §0.2 能力矩阵）。**能力边界（design §0.1）**：sparse-checkout 只控制工作目录物化、不是访问控制——worktree 共享主 repo object store，`git show`/`git log -p` 可绕过；它防的是"正常读文件流程无意抄实现/顺手改 e2e"，不防有意规避。**真正的硬底线**：写入侧是 merge gate（design §3.4，受保护路径零 diff，P1 生效）。旧 git（<2.25）sparse-checkout 退化为纪律 + WARN，merge gate 不受影响
- 不生成 dag.md

## profile 分叉（heavy / lite 两模式）

项目 `docs/omni_powers/profile` 单行值 `heavy` | `lite`。**compact 恢复第一步先读它**判断走哪套。设计详见 `$OP_HOME/docs/omni_powers_design.md` §5。

> **安全声明（design §0.1）**：两版同靠 reviewer 双裁决 + evaluator 验收兜底；heavy 多 merge gate 写入硬底线（design §3.4），lite 无。lite 是 degraded mode，不是 heavy 同等安全版。

**heavy**（现状默认）：本文件通篇规则原样生效。

**lite**（零侵入版，入口 `/oplintake` `/oplrun`。lite 也需 `--set-ophome`——全局 `~/.claude/` 不算侵入，零侵入指不修改项目级 `.claude/` 配置与文件结构）。差异声明：

| 维度 | lite 分叉 |
|---|---|
| 脚本寻址 | `$OP_HOME/scripts/`（与 heavy 统一，两版共用一份脚本） |
| 状态机 | heavy 全态（含 `obsolete`/`suspended`/`blocked`）；**仅删「收口中」态**（`closing`）——收口在 lite 是 leader 瞬时操作 |
| 完成 | `done` = evaluator 裸评 PASS → leader commit + 归档 + P0 检查过 |
| 收口 | **无 op-closer**，leader 机械执行：evaluator 裸评 PASS → `git add workset` + commit → 归档（`op_close_post.sh`），无「收口中」中间态、无 per-task append decisions |
| 闸门 | 无闸门 C（裸评 PASS + P0 检查后 leader 直接归档，无 blueprint 合入——lite 无 blueprint 真相源） |
| decisions 来源 | 闭集加入 `leader-close`（leader 代 closer append 时标记） |
| spec 写保护 | 降级为约定 + git diff 可回溯（无 hook 强制拦截） |
| evaluator | 裸评退化（per-task）：无 worktree 隔离、无 baseline 对照、无跨迭代回归，每 task 裸评一次 |
| 证据校验 | 无 hook——leader 每 task 亲自跑测试 + 读 diff |
| compact 恢复 | 先读 `profile` → 读本文件 + `bash "$OP_HOME/scripts/op_jq.sh" all` + 读 `leader_checkpoint.md` |

## 不做

- 不停下问用户（除非可跑 task 跑完仍剩阻塞，或契约边界规则触发 spec 变更——见 design.md §2.2）
- op-closer per-task 权限红线（design §2.4，一段式）：仅写 `decisions.md` + 转暂存 issue 到 `issues/` + 写 `acceptance/{TID}/blueprint_update.md` 提案；**不跑脚本、不碰 git、不改 status、不 stage、不碰 spec、不碰 op_blueprint**（提案由 leader 闸门 C 审批后写入）。**decisions.md 多写入者**（均 append-only，带来源标记，design §2.4 append 协议）：红灯归因（red-attribution）/ 解锁（BUG-*·锁定文件归因）/ leader 降级 delta / spec-delta / closer 收口 / lite leader-close
- 其余见"跨 agent 铁律"
