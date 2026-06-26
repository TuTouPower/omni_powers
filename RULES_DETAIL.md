# 操作细则

> 编排操作细节，compact 恢复时不需要，按需查阅。
> 核心规则见 `RULES.md`，决策依据见 `docs/omni_powers/op_decisions.md`。

## jq 查询示例

⚠️ 严禁 Read 整文件 `tasks_list.json`，用 `scripts/op_jq.sh` 或 jq 查询。

```bash
# 查所有待开始 task
bash scripts/op_jq.sh pending

# 查某 task 依赖
bash scripts/op_jq.sh deps {TID}

# 查阻塞/跳过
bash scripts/op_jq.sh blocked
bash scripts/op_jq.sh skipped

# 查下游
bash scripts/op_jq.sh downstream {TID}

# 全部概览
bash scripts/op_jq.sh all
```

状态修改统一用 `bash scripts/op_status.sh <TID> <status> [blocked_by]` 或 `--batch` 模式。

## WIP sub-commit

大 task 跑很久时，允许 `wip({TID}): step{N}` 性质的纯代码落盘 sub-commit——**不触发任何收口动作**（不改 status、不归档、不写 checkpoint、不整理 ref）。收口时由 leader 定 squash 还是保留。与收口完全脱钩。

## tasks_list 拆分预案

默认不拆，单文件靠 jq 查询。task 量大到单文件过大、查询变慢时启用：

- `docs/omni_powers/op_execution/tasks_list.json` — 只留未完成（待开始/进行中/审阅中/收口中/阻塞/跳过）
- `docs/omni_powers/op_record/tasks_done.json` — 已完成 task，裁剪到最小（id/title/depends_on/commit），删 verification
- 依赖检查：活表查不到的依赖 → 查 done 表确认完成
- 收口时 task 从活表移到 done 表

## 阻塞项处理

| 类型 | blocked_by | 处理 |
|---|---|---|
| 外部资源缺失（密钥/端点等） | `resource` | 跳过，标阻塞 |
| 3 轮 FAIL | `quality` | 写 issues/{TID}_quality.md，跳过 |
| spawn 失败 | `spawn` | 退避重试 2 次，仍败则标阻塞 |

### 回滚

不用 reset（会丢历史）。

1. `git revert <commit_hash>` — 反向提交
2. `bash scripts/op_status.sh {TID} 待开始` — 该 task status 回退
3. `bash scripts/op_jq.sh downstream {TID}` 查下游 task，逐一 `op_status.sh {下游TID} 待开始`
4. 若该 task 已归档到 `docs/omni_powers/op_record/tasks/{TID}/`：`git mv docs/omni_powers/op_record/tasks/{TID} docs/omni_powers/op_execution/tasks/{TID}` — 移回工作区
5. 重新进入开发循环

不连锁回滚下游，只重置状态。下游 status 回退后依赖链完整，选 task 规则自然重新调度。

### 下游传播规则

- 某 task 阻塞后，其直接/间接下游 status 改为 `跳过`。
- **绕过**：若下游 task 实际上不依赖被阻塞 task 的产出，leader 可修改该下游 task 的 `depends_on` 移除阻塞节点，并在 decisions.md 记录理由。无此记录则不可绕过。
- 阻塞解除后，`跳过` 的 task 恢复 `待开始`。

**阻塞汇总**：所有可跑 task 跑完后，若仍有阻塞 task，leader 才停下报告阻塞项、缺什么、需用户提供什么。

## tech_debt

只记修不了的问题（跨 scope/依赖环境/需架构决策/需未来 task）。能当场修的进 FAIL 轮，不进 tech_debt。每 task 闭环强制追加（无新增也写一行）。不允许只口头说"记 tech_debt"，必须真写文件，否则 task 不算闭环。

## 执行体系（指向 skill）

协议的**操作**已固化到 skill。此处只列映射关系：

| 环节 | 谁做 | 协议段只记规则 |
|---|---|---|
| 需求→task | `/op-task` | 先改 ref 再建 task |
| 开发循环 | `/op-start` | 自治循环，收口后自动选下一个 |
| review | Sub Agent（op-code-reviewer + op-test-reviewer） | 双 review 后台并行，leader 读 verdict |
| 收口 | op-start 收口段 | op-closer stage 全部产出，leader commit |
| 技术债偿还 | `/op-debt2tasks` | 功能 task 全 done 后触发 |
| spec 生成 | `/op-generate-spec`（或 `/op-task` 和 `/op-debt2tasks` 调用） | op-generate-spec skill |
| plan 生成 | `/op-generate-plan`（或 `/op-task` 和 `/op-debt2tasks` 调用） | op-generate-plan skill |
