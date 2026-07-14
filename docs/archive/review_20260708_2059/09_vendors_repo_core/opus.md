## 当前模型判断依据

- 基于可观测来源：环境提示显示当前会话由 `default_opus[1m]` 驱动，`/home/karon/.claude/settings.json` 中配置顶层为 `default_model`，env 环境变量配置了三档默认模型，并且主会话明确指出由 `default_opus[1m]` 驱动。
- 本报告作为只读审阅报告，在用户授权后以 opus 视角产出。
- 审阅时自动省略任何敏感凭证或 secret，报告中不包含此类信息。

## 审阅范围

以 `docs/omni_powers_design.md` 为核心设计契约，对以下四份 vendors_repo 调研文件进行只读审阅，评估其与现行设计的一致性、对设计方案的支撑度以及参考边界：
- `docs/vendors_analyze/vendors_repo/agent-skills.md`
- `docs/vendors_analyze/vendors_repo/openspec.md`
- `docs/vendors_analyze/vendors_repo/planning-with-files.md`
- `docs/vendors_analyze/vendors_repo/spec-kit.md`

---

## 高优先级问题（CRITICAL / HIGH）

### 1. `planning-with-files` 与 `spec-kit` 引入独立 `plan.md`/`tasks.md` 文档的做法与 omni_powers 的分布式 plan 原则冲突
- **位置**：`docs/vendors_analyze/vendors_repo/planning-with-files.md:5-7`、`docs/vendors_analyze/vendors_repo/spec-kit.md:68-80`
- **现象**：
  - `planning-with-files` 将 agent 的工作记忆外化到磁盘上的独立文件 `task_plan.md` 中。
  - `spec-kit` 同样生成独立的 `plan.md` 和 `tasks.md` 文件。
- **影响**：`omni_powers_design.md` §0（设计原则 8）明确规定：“plan 是分布式信息，不是文档。顺序依赖住 tasks_list.json（机读）+ leader_checkpoint（人扫）；跨 task 技术决策复制进每个相关 spec（自足）；接口契约以代码形式先提交。独立 plan 文档只会是这四处的过期复印件”。若在参考上述厂商设计时混淆这一差异，极易导致 agent 重复生成、维护独立的计划和任务文档，引入不一致的状态副本，增加 token 损耗。
- **建议**：在两份调研文件头部添加高亮警告，明确指出 omni_powers 拒绝使用任何形式的独立 `plan.md` 文档，设计探索与技术决策应内联于 `specs/{TID}_{slug}.md` 之中，任务依赖与状态则完全收拢于 `tasks_list.json`。
- **置信度**：高
- **优先级**：HIGH

### 2. 厂商方案中依赖 PreToolUse/PostToolUse 钩子作安全/状态防线的假设在 subagent 下失效
- **位置**：`docs/vendors_analyze/vendors_repo/planning-with-files.md:57-70`、`docs/vendors_analyze/vendors_repo/agent-skills.md:45-48`
- **现象**：
  - `planning-with-files` 的 attestation 哈希锁校验以及状态推进高度依赖 `UserPromptSubmit`、`PreToolUse`、`PostToolUse` 和 `Stop` 等钩子。
  - `agent-skills` 使用 `PreToolUse`/`PostToolUse` 钩子提供缓存和代码块保护。
- **影响**：`omni_powers_design.md` §0（设计原则 7）指出：“hook 自动跑测试对 subagent 已失效——Claude Code 的 subagent 不触发 PreToolUse/PostToolUse，deny 整体失效”。如果 omni_powers 在设计 subagent 护栏时参考这些厂商的钩子控制流，将导致安全与防篡改逻辑静默失效（由于 subagent 根本不触发这些钩子）。
- **建议**：在 `planning-with-files.md` 和 `agent-skills.md` 涉及钩子的章节前补充边界标注，说明此处的钩子机制仅适用于人类主会话（advisory）；omni_powers 的 subagent 硬防线（如 `merge gate` 和 `closer gate`）一律在子代理返回主会话后由 leader 逻辑执行。
- **置信度**：高
- **优先级**：HIGH

---

## 中低优先级问题（MEDIUM / LOW）

### 3. `agent-skills.md` 与 `spec-kit.md` 缺少分析日期，无法评估其时效性与版本边界
- **位置**：`docs/vendors_analyze/vendors_repo/agent-skills.md`、`docs/vendors_analyze/vendors_repo/spec-kit.md`
- **现象**：`openspec.md` 在头部注明了分析日期（2026-07-02），但 `agent-skills.md` 与 `spec-kit.md` 均未包含此信息。
- **影响**：由于 `agent-skills`（2026-06 首次提交）和 `spec-kit` 处于极高频的迭代演进中，没有明确的分析截止日期，后续维护人员将无法知晓这些文件所记录的工具功能与配置结构对应哪个历史版本，增加了对比成本。
- **建议**：仿照 `openspec.md` 的格式，在 `agent-skills.md` 和 `spec-kit.md` 的文件顶部补齐类似 `> 分析日期：2026-07-08` 的高亮标识。
- **置信度**：高
- **优先级**：MEDIUM

### 4. 编排概念术语重叠可能造成误导（Agent 编排 vs 工具集成/指令集）
- **位置**：`docs/vendors_analyze/vendors_repo/openspec.md:109-110`、`docs/vendors_analyze/vendors_repo/spec-kit.md:498-501`
- **现象**：
  - `openspec` 声称“不定义 Agent 角色，无多 Agent 协调”。
  - `spec-kit` 声称支持 “35+ Agent 集成”，但其实质是支持 35+ 种 IDE 辅助工具的 skills 渲染，并非指内置了 35+ 个独立协作的 agent。
- **影响**：omni_powers 拥有由 leader 主动 dispatch 派发给 `op-implementer`、`op-reviewer`、`op-evaluator` 和 `op-closer` 的多角色编排架构（design §2）。厂商调研中关于“无多 Agent”的陈述如果缺乏背景限制，可能会让阅读者误以为 SDD 流程不需要多角色协作。
- **建议**：在 `openspec.md` 和 `spec-kit.md` 涉及“无 Agent/Agent 集成”的总结段中增加批注，明确区分“厂商的 Agent 集成（指适配不同的 LLM CLI 工具客户端）”与“omni_powers 的 Subagent 协作流（指系统内部职责分工的多角色）”。
- **置信度**：中
- **优先级**：LOW

---

## 改进建议

1. **建立统一的“厂商参考边界说明”**：建议在 `docs/vendors_analyze/overview.md` 中增加一节，总结 `openspec`、`spec-kit` 和 `planning-with-files` 与 omni_powers 的异同，尤其是如何吸纳其“先规约后代码”的设计精髓，同时舍弃其“重度依赖客户端 hooks”和“文档冗余”的设计缺陷。
2. **细化 `openspec` delta 变更的映射**：`openspec` 通过 ADDED/MODIFIED/REMOVED 的 delta specs 形式同步源真。omni_powers 在 design §2.4 的 spec 变更子流程中同样需要写 delta。建议明确指出 omni_powers 的 `decisions.md` spec-delta 记录格式规范正是从 `openspec` 的 delta spect 理念蒸馏演进而来。

---

## 不确定项 / 可能误报

- **关于 Claude Code 对 plugin hooks 的底层升级**：如果在后续的版本中，Claude Code 允许 subagent 在执行 `Agent tool` 时向下传递或触发 `PreToolUse`/`PostToolUse` 钩子，那么 `planning-with-files` 的 hook 保护机制和 attestation 哈希校验在 subagent 内部将重新具有可行性。但当前阶段，将其定性为“subagent 下钩子失效”是符合实际的安全保守策略。