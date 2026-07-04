---
name: optriage
description: >
  issue 分级与转 task。扫 issues/ 目录，按 P0-P3 分级，将需修的转正式 task 走对应 change type 流程。
  由 leader 收尾时调用（oprun 驱动），或用户显式 /optriage。
---

# optriage：issue 分级与转 task

> **运行前检查环境**：`bash "$OP_HOME/scripts/op_check_env.sh"`（jq/git/OP_HOME，缺失 die + 装法）

## 触发

- leader 收尾时调用（每叶子收尾 triage 一次，oprun 驱动）
- 用户显式 `/optriage`、分诊、处理 issue

## 输入

| 参数 | 默认值 | 说明 |
|---|---|---|
| `issues_dir` | `docs/omni_powers/op_execution/issues/` | issue 目录 |
| `tasks_list_path` | `docs/omni_powers/op_execution/tasks_list.json` | ⚠️ 严禁 Read 整文件，用 jq |

issue 文件命名两种（用途不同，非不一致）：`I-{YYYYMMDD}-{NN}.md`（泛 issue——evaluator/reviewer/系统层范围外发现）+ `{TID}_quality.md`（绑 review 2 轮 FAIL 的 task，RULES.md 阻塞项 `blocked_by=quality`）。

## issue 文件格式

```markdown
# I-20260702-01: {标题}
来源: {review两轮到顶残留 / reviewer范围外 / evaluator范围外 / 系统层夜跑 / 定期体检}
所属 spec: {spec前缀}
严重度: P0阻断上线 / P1下个spec前必修 / P2排期 / P3可容忍
标签: tech-debt, {其他}
状态: open → triaged → 转 task → closed
描述: {内容}
```

## 步骤

### step 1：扫 issue

```bash
ls docs/omni_powers/op_execution/issues/*.md 2>/dev/null || echo "无 issue"
```

逐个读 issue 文件，解析严重度、标签、所属 spec、状态。

### step 2：分级与过滤

跳过 `状态: closed` 的。对 open issue：

- **P0 阻断上线** → 必须转 task，本 spec 收尾前必修。闸门 C 呈报，人定阻不阻断 merge。
- **P1 下个 spec 前必修** → 转 task，排进下个 spec。
- **P2 排期** → 标 `tech-debt`，登记不转 task，等用户排期。
- **P3 可容忍** → 标 `tech-debt`，登记不转 task。

技术债（`tech-debt` 标签）与 P0-P3 严重度正交——任何 P 级都可能带 `tech-debt` 标签。

### step 3：转 task（P0/P1）

对要转 task 的 issue：

1. 用 jq 取当前最大 TID，新 task 从 `T{NN+1}` 开始
2. 确定 change type：
   - bug → `fix`（契约=那条回归测试，先红后绿）
   - 改进 → `feat` 或 `refactor`
   - 性能 → `perf`
3. 分配属性：
   - `title`: `修issue: {简要描述}`
   - `status`: `待规划`（有细节直接 `待开始`）
   - `spec`: issue 的所属 spec
   - `depends_on`: 推导
   - `covers_ac` / `touches_inv`: 从 issue 描述推导
4. 用 jq 追加到 `tasks_list.json`
5. issue 文件状态改 `triaged → 转 task`，记录转到的 TID

```bash
bash "$OP_HOME/scripts/op_new_task.sh {TID}
```

转 task 后的 issue 走标准 `/oprun` 循环，**不走免检通道**——issue 是登记处不是免检通道。

### step 4：P2/P3 登记

不转 task。issue 文件状态改 `triaged`，在终端汇报：

```
=== issue triage 结果 ===

P0（本 spec 必修，已转 task）:
  I-20260702-01 会话列表滚动掉帧 → T06

P1（下个 spec 前修，已转 task）:
  I-20260702-02 错误格式不统一 → T07

P2 排期（tech-debt，未转 task）:
  I-20260702-03 日志未脱敏

P3 可容忍（tech-debt，未转 task）:
  I-20260702-04 文档 typo
```

### step 5：闸门 C 呈报

P0/P1 在闸门 C 呈报给用户：人定阻不阻断 merge。不阻断 merge 的 P0/P1 留 issue，下个 spec 处理。

## task 数量限制

- 转 task 总数不超过 10 个。超过则优先合并同模块项。
- 每 task 覆盖 issue 不超过 5 个。

## 边界情况

- **无 issue**：输出"无 issue，无需 triage"。
- **issue 全 closed**：输出"所有 issue 已处理"。
- **P0 与当前 spec 无关**：警告"P0 不属于当前 spec，是否仍在本 spec 修？"

## 与其他 skill 的关系

- **leader**：收尾时调本 skill 做分诊。分诊需全局视野，留在此 skill 不并入 closer（信息流相反）。
- **opintake**：转出的 task 走 `/oprun` 标准循环，与功能 task 流程一致。
- **oprun**：转 task 后由 `/oprun` 调度执行。

## 注意

- leader 是本 skill 的唯一调用者。
- issue 不直接改代码，转正式 task 后走对应 change type 流程。
- 不在功能 task 跑到一半插 issue task——等当前 task 收口。
