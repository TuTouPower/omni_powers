---
name: intake
description: >
  需求→task 统一入口。默认深度模式（一问一答协作讨论 + 可选 visual companion），
  用户说"快速模式/快速决定/直接生成"才走快速。内部调 spec-generator 和 plan-generator。
  触发：/intake、新需求、拆 task、需求入轨。
---

# Intake：需求→task 统一入口

## 触发

- `/intake "做用户登录功能"`
- `/intake docs/harness_blueprint/prd.md`（已有文档）
- `/intake`（然后粘贴需求描述）
- 用户说"新需求"、"拆 task"、"需求入轨"

## 模式选择

**默认：深度模式**——一问一答协作讨论，逐项确认目标/范围/方案，可选 visual companion。

**快速模式**：仅当用户**明确说**以下关键词时才走快速：
- "快速模式"、"快速决定"、"直接生成"、"快速生成"、"不用讨论了"

进入 skill 后先确认模式：

```
/intake "{需求}"

默认走深度讨论，逐项确认目标/范围/方案。说"快速"则直接生成。
开始？
```

## 深度模式

1. **读上下文**：tasks_list.json（⚠️ 严禁 Read 整文件，必须用 `jq` 查询） + ref 文档（prd/spec/architecture/domain）
2. **讨论需求（第一轮 spec-generator）**：一问一答逐项确认目标/范围/方案，可选 visual companion。产出需求共识（不写文件，仅讨论）
3. **从结论拆 task**：提取需求范围 → 拆 task → 确认 → 更新 tasks_list.json → 建目录
4. **生成正式 spec/plan（第二轮）**：对每个 task 调 spec-generator（快速模式，因方案已在讨论中确认）+ plan-generator（快速模式），输出到各 task 目录
5. **汇报**：task 已就位，下一步 /harness-start

## 快速模式

用户明确说"快速"时才走此模式。

1. **读上下文**：tasks_list.json（⚠️ 严禁 Read 整文件，必须用 `jq` 查询）+ ref 文档
2. **确认需求范围**：从输入提取，输出确认
3. **更新 ref**（按需）：prd/spec/architecture/domain/test
4. **拆 task**：确认 → 更新 tasks_list.json → 建目录
5. **调 spec-generator + plan-generator（快速模式）**：为每个 task 用 `Agent({ subagent_type: "general-purpose", model: "sonnet", prompt: "..." })` 启动一个子代理，子代理内依次调用 spec-generator skill 和 plan-generator skill，完成后回报。

> 深度模式直接在主会话调 Skill（需要用户交互），快速模式用子代理（无需交互可并发）。两种方式不同是因为深度模式需要一问一答，子代理无法与用户交互。

6. **汇报**：task 已就位，下一步 /harness-start

## 拆 task 规则

每个 task 满足：独立可交付、可独立回滚、依赖明确。

| 字段 | 规则 |
|---|---|
| `id` | 从当前最大 ID +1 递增，格式 `T{NN}` |
| `title` | 简短描述 |
| `dependencies` | 只填已完成 task 或本批次前面的 task |
| `status` | 统一填 `待开始` |
| `verification` | 验收标准，一句话 |
| `blocked_by` | 有环境依赖才填，否则 `null` |

拆完输出确认：

```
=== 待追加 task ===

T{n}   "{title}"  依赖: [{deps}]  验收: {verification}
共 {m} 个 task。追加？
```

## 建目录拷模板

```bash
mkdir -p docs/harness_execution/tasks/{TID}
cp docs/harness/template/harness_execution/tasks/{TID}/spec.md docs/harness_execution/tasks/{TID}/spec.md
cp docs/harness/template/harness_execution/tasks/{TID}/plan.md docs/harness_execution/tasks/{TID}/plan.md
cp docs/harness/template/harness_execution/tasks/{TID}/context.md docs/harness_execution/tasks/{TID}/context.md
cp docs/harness/template/harness_execution/tasks/{TID}/steps.md docs/harness_execution/tasks/{TID}/steps.md
```

context.md 和 steps.md 暂不填（空模板，coder 和 leader 后续维护）。

## 与其他 skill 的关系

```
/intake（默认深度模式）
    │
    ├── 深度：spec-generator（深度讨论）→ 拆 task → spec/plan-generator（快速）
    │
    └── 快速：确认范围 → 拆 task → spec/plan-generator（快速）
                │
                ▼
         /harness-start
```

- **spec-generator**：intake 内部调用，可独立调用 `/spec-gen`
- **plan-generator**：intake 内部调用，可独立调用 `/plan-gen`
- **debt-to-tasks**：技术债偿还走 debt-to-tasks，新功能走 intake
- **harness-start**：完成后调 /harness-start 进入开发循环

## 注意事项

- 先改 ref 再拆 task，不反过来
- 每个 task 独立可交付——拆不出来说明需求还不够清晰
- spec.md 的过程性内容留在 task spec，不进 harness_blueprint/specs/
- context.md 和 steps.md 不要预填
