# 操作细则

> 编排操作细节，compact 恢复时不需要，按需查阅。
> 核心规则见 `RULES.md`，决策依据见 `docs/op_decisions.md`。

## jq 查询示例

⚠️ 严禁 Read 整文件 `tasks_list.json`，必须用 jq 查询。

```bash
# 查所有待开始 task（选 task）
jq '.tasks[] | select(.status=="待开始")' docs/op_execution/tasks_list.json

# 查某 task 依赖是否全完成
TID=T02
DEPS=$(jq -r '.tasks[] | select(.id=="'$TID'") | .depends_on[]?' docs/op_execution/tasks_list.json)
for d in $DEPS; do
  jq -r '.tasks[] | select(.id=="'$d'") | .status' docs/op_execution/tasks_list.json
done

# 查所有阻塞 task
jq '.tasks[] | select(.status=="阻塞") | {id, blocked_by}' docs/op_execution/tasks_list.json

# 查所有跳过 task
jq '.tasks[] | select(.status=="跳过") | {id, title}' docs/op_execution/tasks_list.json

# 查某 task 的下游（谁依赖它）
TID=T02
jq --arg tid "$TID" '.tasks[] | select(.depends_on != null and (.depends_on | index($tid))) | .id' docs/op_execution/tasks_list.json
```

状态修改统一用 `bash skills/op-start/scripts/op-status.sh <TID> <status> [blocked_by]` 或 `--batch` 模式。

## WIP sub-commit

大 task 跑很久时，允许 `wip({TID}): step{N}` 性质的纯代码落盘 sub-commit——**不触发任何收口动作**（不改 status、不归档、不写 checkpoint、不整理 ref）。收口时由 leader 定 squash 还是保留。与收口完全脱钩。

## tasks_list 拆分预案

默认不拆，单文件靠 jq 查询。task 量大到单文件过大、查询变慢时启用：

- `docs/op_execution/tasks_list.json` — 只留未完成（待开始/进行中/审阅中/收口中/阻塞/跳过）
- `docs/op_record/tasks_done.json` — 已完成 task，裁剪到最小（id/title/depends_on/commit），删 verification
- 依赖检查：活表查不到的依赖 → 查 done 表确认完成
- 收口时 task 从活表移到 done 表

## 阻塞项处理

| 类型 | blocked_by | 处理 |
|---|---|---|
| 外部密钥/凭据缺失 | `key` | 跳过，标阻塞 |
| 域名/外部端点缺失 | `domain` | 同上 |
| 3 轮 FAIL | `quality` | 写 issues/{TID}_quality.md，跳过 |
| spawn 失败 | `spawn` | 退避重试 2 次，仍败则标阻塞 |

### 回滚

不用 reset（会丢历史）。

1. `git revert <代码commit_hash>` — 反向提交（代码平面）
2. `git revert <控制平面commit_hash>` — 反向提交（控制平面）
3. `bash skills/op-start/scripts/op-status.sh {TID} 待开始` — 该 task status 回退
4. 用 jq 查下游 task（`select(.depends_on | index("{TID}"))`），逐一 `op-status.sh {下游TID} 待开始`
5. 若该 task 已归档到 `docs/op_record/tasks/{TID}/`：`git mv docs/op_record/tasks/{TID} docs/op_execution/tasks/{TID}` — 移回工作区
6. 重新进入开发循环

不连锁回滚下游，只重置状态。下游 status 回退后依赖链完整，选 task 规则自然重新调度。

### 下游传播规则

- 某 task 阻塞后，其直接/间接下游 status 改为 `跳过`。
- **绕过**：若下游 task 实际上不依赖被阻塞 task 的产出，leader 可修改该下游 task 的 `depends_on` 移除阻塞节点，并在 decisions.md 记录理由。无此记录则不可绕过。
- 阻塞解除后，`跳过` 的 task 恢复 `待开始`。

**阻塞汇总**：所有可跑 task 跑完后，若仍有阻塞 task，leader 才停下报告阻塞项、缺什么、需用户提供什么。

## plan 分段派活

leader 先读 plan，拆成有序 step 列表（存入 `tasks/{TID}/steps.md`，由 leader 维护进度）。每个 step 是一组相关文件改动。

**派活方式**：leader 只给 op-coder 当前 step + 相关 spec 段，不给整份 plan。op-coder 每 step 完成后 leader 再派下一个。小 task 可一次给全 plan。

**steps.md**：leader 维护，记录当前 step 编号和进度。op-coder 只读不写。

## tech_debt

只记修不了的问题（跨 scope/依赖环境/需架构决策/需未来 task）。能当场修的进 FAIL 轮，不进 tech_debt。每 task 闭环强制追加（无新增也写一行）。不允许只口头说"记 tech_debt"，必须真写文件，否则 task 不算闭环。

格式：按 task 分节，表格列 `| ID | 来源(review-code/review-test/环境) | 债项 | 严重度 | 暂存原因 |`。

## 执行体系（指向 skill）

协议的**操作**已固化到 skill。此处只列映射关系：

| 环节 | 谁做 | 协议段只记规则 |
|---|---|---|
| 需求→task | `/op-task` | 先改 ref 再建 task |
| 开发循环 | `/op-start` | 自治循环，收口后自动选下一个 |
| review | Agent Team（op-code-reviewer + op-test-reviewer） | 双 review 并行，leader 读 verdict |
| 收口 | op-start 收口段 | op-closer stage 全部产出，leader commit |
| 技术债偿还 | `/op-debt2tasks` | 功能 task 全 done 后触发 |
| spec 生成 | `/op-generate-spec`（或 intake 调用） | op-generate-spec skill |
| plan 生成 | `/op-generate-plan`（或 intake 调用） | op-generate-plan skill |
