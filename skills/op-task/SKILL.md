---
name: op-task
description: >
  需求→task 统一入口。默认深度模式（一问一答协作讨论 + 可选 visual companion），
  用户说"快速模式/快速决定/直接生成"才走快速。内部调 op-generate-spec 和 op-generate-plan。
  触发：/intake、新需求、拆 task、需求入轨。
---

# Intake：需求→task 统一入口

## 触发

- `/intake "做用户登录功能"`
- `/intake docs/omni_powers/op_blueprint/prd.md`（已有文档）
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
2. **讨论需求（第一轮 op-generate-spec）**：一问一答逐项确认目标/范围/方案，可选 visual companion。产出需求共识（不写文件，仅讨论）
3. **从结论拆 task**：提取需求范围 → 拆 task → 确认 → 更新 tasks_list.json → 建目录
4. **生成 spec/plan**：主会话逐 task 调用 `Skill("op-generate-spec")`（深度模式）→ `Skill("op-generate-plan")`（深度模式）。深度模式需用户一问一答交互，必须在主会话完成，不用子代理。多个 task 时串行处理。

<HARD-GATE>
必须对每个 task 调用 `Skill("op-generate-spec")` 和 `Skill("op-generate-plan")`，禁止手写 spec/plan。不得跳过此步。
</HARD-GATE>

5. **汇报**：task 已就位，下一步 /op-start

## 快速模式

用户明确说"快速"时才走此模式。

1. **读上下文**：tasks_list.json（⚠️ 严禁 Read 整文件，必须用 `jq` 查询）+ ref 文档
2. **确认需求范围**：从输入提取，输出确认
3. **更新 ref**（按需）：prd/spec/architecture/domain/test
4. **拆 task**：确认 → 更新 tasks_list.json → 建目录
4. **生成 spec/plan**：为每个 task 用 `Agent({ subagent_type: "general-purpose", model: "sonnet", prompt: "..." })` 启动一个子代理，子代理内依次调用 op-generate-spec skill（快速模式）和 op-generate-plan skill（快速模式），输出到各 task 的指定目录。每个 task 的子代理独立运行，多个 task 的子代理可并发。

<HARD-GATE>
必须对每个 task 调用 op-generate-spec 和 op-generate-plan skill，禁止手写 spec/plan。不得跳过此步。
</HARD-GATE>

> 深度模式直接在主会话调 Skill（需要用户交互），快速模式用子代理（无需交互可并发）。两种方式不同是因为深度模式需要一问一答，子代理无法与用户交互。

6. **汇报**：task 已就位，下一步 /op-start

## 拆 task 规则

每个 task 满足：独立可交付、可独立回滚、依赖明确。

| 字段 | 规则 |
|---|---|
| `id` | 从当前最大 ID +1 递增，格式 `T{NN}` |
| `title` | 简短描述 |
| `depends_on` | 前置依赖 task ID 数组，无依赖填 `null`（**必填，不可省略**） |
| `status` | 统一填 `待开始` |
| `verification` | 验收标准，一句话 |
| `blocked_by` | 有环境依赖才填，否则 `null` |

拆完输出确认：

```
=== 待追加 task ===

{TID}   "{title}"  依赖: [{depends_on}]  验收: {verification}
共 {m} 个 task。追加？
```

## 建目录拷模板

```bash
bash scripts/op_new_task.sh {TID}
```

context.md 暂不填（空模板，op-coder 后续维护）。

## 与其他 skill 的关系

```
/intake（默认深度模式）
    │
    ├── 深度：op-generate-spec（深度讨论）→ 拆 task → op-generate-spec/op-generate-plan（深度）
    │
    └── 快速：确认范围 → 拆 task → op-generate-spec/op-generate-plan（快速）
                │
                ▼
         /op-start
```

- **op-generate-spec**：intake 内部调用，可独立调用 `/op-generate-spec`
- **op-generate-plan**：intake 内部调用，可独立调用 `/op-generate-plan`
- **op-debt2tasks**：技术债偿还走 op-debt2tasks，新功能走 intake
- **op-start**：完成后调 /op-start 进入开发循环

## 注意事项

- 先改 ref 再拆 task，不反过来
- 每个 task 独立可交付——拆不出来说明需求还不够清晰
- spec.md 的过程性内容留在 task spec，不进 op_blueprint/specs/
- context.md 不要预填
