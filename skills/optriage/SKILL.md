---
name: optriage
description: >
  issue 分级与转 task。扫 issues/ 目录，按 P0-P3 分级，将需修的转正式 task 走对应 change type 流程。
  由 leader 收尾时调用（oprun 驱动），或用户显式 /optriage。
---

# optriage：issue 分级与转 task

> **路径前置**：进入 skill 后先执行：
> ```bash
> source "$OP_HOME/scripts/op_paths.sh"
> op_load_paths "" "$(git rev-parse --show-toplevel)"
> ```
> 后文 `$OP_DOCS_DIR` 使用解析后项目相对路径；旧项目无配置自动取 `docs/omni_powers`。


> **运行前检查环境**：`bash "$OP_HOME/scripts/op_check_env.sh"`（jq/git/OP_HOME，缺失 die + 装法）
>
> **profile 感知**：先 `cat "$OP_DOCS_DIR/profile"`。`lite` 项目无 closer（leader 直接调本 skill 收尾）、无闸门 C（P0 进结束报告标注，不事中阻断归档，A18）；异常提示中 `/opintake` 对应换 `/oplintake`。脚本统一在 `$OP_HOME/scripts/`（两版共用）。

## 触发

- leader 收尾时调用（每 task 收尾 triage 一次，oprun 驱动）
- 用户显式 `/optriage`、分诊、处理 issue

## 输入

| 参数 | 默认值 | 说明 |
|---|---|---|
| `issues_dir` | `$OP_DOCS_DIR/op_execution/issues/` | issue 目录 |
| `tasks_list_path` | `$OP_DOCS_DIR/op_execution/tasks_list.json` | ⚠️ 严禁 Read 整文件，用 jq |

issue 文件命名两种（用途不同，非不一致）：`issue_{slug}.md`（泛 issue——evaluator/reviewer/系统层范围外发现，文件名语义 slug）+ `{TID}_quality.md`（绑 review 2 轮 FAIL 的 task，RULES.md 阻塞项 `blocked_by=quality`）。**frontmatter `id` 统一 `I-{YYYYMMDD}-{NN}`**（机器主键，与文件名解耦——id 给机器，文件名给人）。

## issue 文件格式（design §3.2 frontmatter）

```markdown
---
id: I-20260702-01
title: {标题}
source: {review两轮到顶残留 / reviewer范围外 / evaluator范围外 / 系统层夜跑 / 定期体检}
spec: {TID}
severity: P0 | P1 | P2 | P3     # P0阻断上线 / P1下个spec前必修 / P2排期 / P3可容忍
triaged: P0 | P1 | P2 | P3 | closed # triage 结果；未 triage 时省略
tags: [tech-debt]               # 可选，与 P0-P3 正交
status: open | triaged | converted | closed
converted_to: T05               # 转 task 后填对应 TID
blocks_merge: true | false      # P0 默认 true；P1 默认 false；用户显式豁免需记 decisions
---

{内容描述}
```

## 步骤

### step 1：扫 issue

```bash
ls $OP_DOCS_DIR/op_execution/issues/*.md 2>/dev/null || echo "无 issue"
```

逐个读 issue 文件，解析严重度、标签、所属 spec、状态。triage 完成后必须在 frontmatter 写 `triaged: P0 | P1 | P2 | P3 | closed`；`closed` 表示无需继续处理，其他值记录分级结果。

### step 2：分级与过滤

跳过 `状态: closed` 的。对 open issue：

- **P0 进结束报告标注** → 必须转 task，**不事中阻断归档**（A18）：进结束报告 `blocks_merge` 标注，用户事后处置（转修复 task / 显式豁免记 decisions / revert）。design §3.2。
- **P1 下个 spec 前必修** → 转 task，排进下个 spec；进结束报告标注（不事中阻断，A18）。
- **P2 排期** → 标 `tech-debt`，登记不转 task，等用户排期。
- **P3 可容忍** → 标 `tech-debt`，登记不转 task。

技术债（`tech-debt` 标签）与 P0-P3 严重度正交——任何 P 级都可能带 `tech-debt` 标签。

### step 3：转 task（P0/P1）

对要转 task 的 issue：

1. 用 jq 取当前最大 TID，新 task 从 `T%04d` 开始（固定四位宽度，如 T0006）
2. 确定 change type：
   - bug → `fix`（契约=那条回归测试，先红后绿）
   - 改进 → `feat` 或 `refactor`
   - 性能 → `perf`
3. 分配属性：
   - `title`: `修issue: {简要描述}`
   - `status`: `pending`（默认进 `/opintake` 生成新工作 spec——P0/P1 修复应有独立验收标准，避免免检通道；issue 已附带完整工作 spec 路径、AC/INV、workset 且通过闸门 A 时允许 `ready`）
   - `spec`: issue 的所属 spec
   - `depends_on`: 推导
   - `workset`: 从 issue 描述推导
4. 用 jq 追加到 `tasks_list.json`
5. issue 文件状态改 `triaged → 转 task`，记录转到的 TID

```bash
bash "$OP_HOME/scripts/op_new_task.sh" "{TID}"
```

转 task 后的 issue 走标准 `/oprun` 循环，**不走免检通道**——issue 是登记处不是免检通道。

### step 4：P2/P3 登记

不转 task。issue 文件状态改 `triaged`，在终端汇报：

```
=== issue triage 结果 ===

P0（本 spec 必修，已转 task）:
  I-20260702-01 会话列表滚动掉帧 → T0006

P1（下个 spec 前修，已转 task）:
  I-20260702-02 错误格式不统一 → T0007

P2 排期（tech-debt，未转 task）:
  I-20260702-03 日志未脱敏

P3 可容忍（tech-debt，未转 task）:
  I-20260702-04 文档 typo
```

### step 5：闸门 C 呈报

P0/P1 在闸门 C 呈报给用户：P0 默认阻断，P1 默认进入下个 spec 前必修。用户显式豁免时记录 decisions；不阻断 merge 的 P0/P1 留 issue，下个 spec 处理。

## task 数量限制

- 转 task 总数不超过 10 个。超过则优先合并同模块项。
- 每 task 覆盖 issue 不超过 5 个。

## 边界情况

- **无 issue**：输出"无 issue，无需 triage"。
- **issue 全 closed**：输出"所有 issue 已处理"。
- **P0 与当前 spec 无关**：警告"P0 不属于当前 spec，是否仍在本 spec 修？"

## 与其他 skill 的关系

- **leader**：收尾时调本 skill 做分诊。分诊需全局视野，留在此 skill 不并入 closer（信息流相反）。
- **opintake**：`待规划` issue task 先走 `/opintake` 补 spec/验收标准/工作集。
- **oprun**：`待开始` issue task 由 `/oprun` 直接调度执行。

## 注意

- leader 是本 skill 的唯一调用者。
- issue 不直接改代码，转正式 task 后走对应 change type 流程。
- 不在功能 task 跑到一半插 issue task——等当前 task 收口。
