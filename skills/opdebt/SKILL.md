---
name: opdebt
description: >
  技术债偿还——扫 tech_debt.md，按主题归类，拆成偿还 task，生成 spec/plan，更新 tasks_list.json。
  默认快速模式（直接归类拆 task），用户说"深度模式/深度讨论"才走深度（逐债项讨论）。
  功能 task 全部完成后由 leader 触发。
---

# opdebt：技术债偿还

## 触发

- 所有功能 task 状态为 `完成` 后，leader 调用本 skill
- 用户显式说 `/opdebt`、还债、偿还技术债

## 模式选择

**默认：快速模式**——直接扫 tech_debt.md → 归类 → 拆 task → 调 opspec/opplan（快速）。

**深度模式**：仅当用户**明确说**以下关键词时才走深度：
- "深度模式"、"深度讨论"、"逐项讨论"、"详细讨论"

进入 skill 后先确认：

```
/opdebt

默认快速归类直接拆。说"深度"则逐债项讨论。开始？
```

## 输入

| 参数 | 默认值 | 说明 |
|---|---|---|
| `tech_debt_path` | `docs/omni_powers/op_execution/tech_debt.md` | 技术债清单 |
| `tasks_list_path` | `docs/omni_powers/op_execution/tasks_list.json` | 当前 task 清单（⚠️ 体积大，严禁 Read 整文件，必须用 `jq` 查询） |
| `tasks_list_template` | `docs_template/omni_powers/op_execution/tasks_list.json` | tasks_list.json 模板 |
| `spec_template` | `docs_template/omni_powers/op_execution/tasks/{TID}/spec.md` | spec 模板 |
| `plan_template` | `docs_template/omni_powers/op_execution/tasks/{TID}/plan.md` | plan 模板 |

## 输出

1. 归类报告（终端输出，不落盘）
2. 更新 `tasks_list.json`（追加偿还 task）
3. 为每个偿还 task 生成 `docs/omni_powers/op_execution/tasks/{TID}/spec.md` + `plan.md`

## 步骤

### step 1：读 tech_debt.md

读 `tech_debt_path`，解析全部债项。

解析规则：
- 跳过注释行（`>` 开头）和空行
- 识别 `## 环境限制` 节下的表格 → 环境债
- 识别 `## {TID} {title}` 节下的表格 → 功能 task 遗留债

每行债项提取字段：

| 字段 | 环境债列 | 功能债列 |
|---|---|---|
| id | `ID` | `ID` |
| task_id | `任务`（如 `T01`） | 从节标题 `## {TID}` 提取 |
| source | — | `来源` |
| debt | `债项` | `债项` |
| severity | — | `严重度` |
| reason | `暂存原因` | `暂存原因` |

### step 2：归类

按以下优先级归类，同一债项可匹配多条规则，取优先级最高的那条：

1. **环境债**：单独成 task，标 `blocked_by`
2. **同文件/模块**：债项描述中提到相同文件或模块 → 合为一个 task
3. **同主题**：跨 scope 但同主题（如"所有错误处理优化"、"统一日志格式"）→ 合为一个 task
4. **来源为 `环境`** 但不在环境限制节下的 → 归入环境债组
5. **剩余独立债项**：每项单独成 task

归类输出格式（终端打印）：

```
=== 技术债归类结果 ===

环境债：
  [E1] T01 真实 DB 集成测试未跑 → 偿还 task: T{next_id}（blocked_by=key）

模块: src/api/auth/
  [T02-3] review-code | 缺少 token 刷新逻辑 | HIGH
  [T02-5] review-test | 未覆盖 token 过期场景 | MEDIUM
  → 偿还 task: T{next_id+1}

主题: 错误处理
  [T03-1] review-code | API 层未统一错误格式 | MEDIUM
  [T05-2] review-test | 异常路径无测试 | MEDIUM
  → 偿还 task: T{next_id+2}

独立:
  [T01-7] review-code | 缺 rate limiting | HIGH → 偿还 task: T{next_id+3}
```

### step 3：确定 task ID

用 jq 查询 `tasks_list.json`，取当前最大 task ID（如 `T05`），新偿还 task 从 `T06` 开始递增。

ID 格式：`T{NN}`，两位数，不足两位前面补零。

### step 4：分配 task 属性

每个偿还 task 确定以下属性：

**depends_on**：
- 环境债：`depends_on` 为 `null`
- 功能遗留债：填该债项所属的原始 task ID。如 `T02-3` 和 `T02-5` 合并，则依赖 `["T02"]`。如合并了多个来源 task，取并集。

**blocked_by**：
- 环境债：按原因填 `key` / `domain` / 其他
- 功能遗留债：填 `null`

**title**：格式为 `还债: {简要描述}`

**verification**：从债项描述推导验收标准，一句话。

**status**：统一填 `待规划`。如果有明确的细节可以直接调用生成并改为 `待开始`。

### step 5：更新 tasks_list.json

用 jq 读取 `tasks_list.json`，在 `tasks` 数组末尾追加新 task。不改已有 task。

如存在环境债，同步更新 `blockers` 数组：

```json
{
  "id": "B{n}",
  "desc": "{环境依赖描述}",
  "affects": ["{TID}"],
  "status": "待提供"
}
```

### step 6：生成 spec + plan

3. 用户确认后，将新 task 追加到 tasks_list.json，初始状态设为 `待规划`。如果有明确的细节可以直接调用生成并改为 `待开始`。

<HARD-GATE>
如果决定要生成详细的 spec 和 plan，spec.md 和 plan.md 的内容必须通过 Skill 工具调用 opspec 和 opplan 生成。禁止手动写。
</HARD-GATE>

对每个需要详细规划的偿还 task：

1. 建目录拷模板：
```bash
bash scripts/op_new_task.sh {TID}
```

2. 调 opspec 生成 spec.md（输入：债项描述 + 严重度 + 暂存原因）

3. 调 opplan 生成 plan.md

**快速模式（默认）**：每个需要详细规划的偿还 task 用子代理并发调用 opspec（快速模式）→ opplan（快速模式）。每个子代理对一个 task 依次完成 spec+plan。生成完成后将状态从 `待规划` 改为 `待开始`。

**深度模式**（用户明确说"深度"时才走）：主会话逐 task 直接调用 `Skill("opspec")`（深度模式）→ `Skill("opplan")`（深度模式）。深度模式需用户一问一答交互，必须在主会话完成，不用子代理，串行处理。生成完成后将状态从 `待规划` 改为 `待开始`。

### step 7：更新 tech_debt.md

从 tech_debt.md 中删除被偿还 task 覆盖的债项表格行。只删被覆盖的行，不删整节。该节下所有行都删完后，删该节标题。

偿还 task 本身已在 tasks_list.json 中，无需在 tech_debt.md 中重复记录。

### step 8：汇报

终端输出最终汇总：

```
=== 偿还 task 已创建 ===

T06 还债: auth 模块 token 刷新逻辑（依赖 T02）→ spec/plan 已生成
T07 还债: 统一错误处理（依赖 T03, T05）→ spec/plan 已生成
T08 还债: 环境-真实 DB 集成测试（blocked_by=key）→ spec/plan 已生成

共 3 个偿还 task 已追加到 tasks_list.json。
tech_debt.md 已清理。
```

## task 数量限制

- 合并后偿还 task 总数不超过 10 个。如超过，优先合并同模块项，必要时将低严重度项合并到主题 task。
- 每 task 覆盖债项不超过 5 个。超过则拆分为同主题的多个 task。

## 边界情况

- **tech_debt.md 为空或所有债项已转化为偿还 task**：输出 "无技术债，无需偿还"，不创建 task。
- **tech_debt.md 不存在**：报错 "tech_debt.md 不存在，请确认路径"。
- **功能 task 未全部完成**：警告 "尚有功能 task 未完成（列出未完成的 TID），按协议应等功能 task 全部收口后再偿还。是否继续？"

## 与其他 skill 的关系

- **intake**（需求→task 前置）：新功能 task 走 intake，偿还 task 走本 skill。二者输出格式一致（都追加到 tasks_list.json + 生成 spec/plan）。
- **opstart**（统一工作流入口）：偿还 task 创建完成后，走 /opstart 进入标准开发循环（选 task→派 op-coder→review→收口）。收口流程与功能 task 相同。
- 恢复后偿还 task 与功能 task 无区别，/opstart 统一按 tasks_list.json 的 status 和 depends_on 调度。

## 注意事项

- leader 是本 skill 的唯一调用者。op-coder/op-code-reviewer/test-reviewer 不调用本 skill。
- 偿还 task 走标准开发循环（spec/plan/op-coder/review/收口），与功能 task 流程完全一致。
- 不在功能 task 跑到一半插偿还 task——等当前 task 收口。
- 环境债的 blocked_by 在环境就位后由 leader 手动改为 null，然后走标准循环。
