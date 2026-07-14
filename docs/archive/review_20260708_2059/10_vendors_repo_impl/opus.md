## 当前模型判断依据

- 基于可观测来源：环境提示显示当前会话由 `default_opus[1m]` 驱动，`/home/karon/.claude/settings.json` 中配置顶层为 `default_model`，env 环境变量配置了三档默认模型，并且主会话明确指出由 `default_opus[1m]` 驱动。
- 本报告作为只读审阅报告，在用户授权后以 opus 视角产出。
- 审阅时自动省略任何敏感凭证或 secret，报告中不包含此类信息。

## 审阅范围

以 `docs/omni_powers_design.md` 为核心设计契约，对以下三份 vendors_repo 实现/工作流参考资料进行只读审阅，评估其与现行设计的一致性、对设计方案的支撑度以及参考边界：
- `docs/vendors_analyze/vendors_repo/bmad-method.md`
- `docs/vendors_analyze/vendors_repo/gstack.md`
- `docs/vendors_analyze/vendors_repo/trellis.md`

---

## 高优先级问题（CRITICAL / HIGH）

### 1. `bmad-method` 的 Persona 角色设定（命名人格化）与 omni_powers 的功能角色与自动化契约定位冲突
- **位置**：`docs/vendors_analyze/vendors_repo/bmad-method.md:12-13`、`docs/vendors_analyze/vendors_repo/bmad-method.md:130-144`
- **现象**：BMad Method 采用高度拟人化的命名角色 Persona（如分析师 Mary、架构师 Winston、开发者 Amelia 等），并为其定制特定的沟通风格、个性和会话级别的菜单问候项。
- **影响**：`omni_powers_design.md` §2 与 §0（设计原则 11）强调自动化角色编排与规格契约。BMad 这种面向人机交互的 Persona 设计在全自动 Subagent 协作中会引入大量冗余的性格提示词和非必要的会话机制，显著增加了 Token 损耗。在无人工干预的开发闭环中，拟人化的交互设计并不服务于“规格是唯一契约”的质量校验实质。
- **建议**：在 `bmad-method.md` 文件头部添加高亮警告，指明 omni_powers 使用确定性的功能职责代理（Subagent Gate），拒绝引入任何拟人化的 Persona 属性及非必要的会话菜单交互，以保持 Token 使用的高能效比和职责边界的严谨性。
- **置信度**：高
- **优先级**：HIGH

### 2. `gstack` 的 browser daemon 本地 Bun 编译与 Chromium 常驻服务设计与 omni_powers 的轻量无侵入原则存在张力
- **位置**：`docs/vendors_analyze/vendors_repo/gstack.md:27-30`、`docs/vendors_analyze/vendors_repo/gstack.md:320-337`
- **现象**：GStack 依赖一个高度定制的 `browse daemon`（通过 Bun 编译二进制并启动常驻的 Chromium 进程）来向 AI 提供次秒级的浏览器 CDP 控制命令。
- **影响**：omni_powers 设计了 heavy 和 lite 两种模式（design §5），其中 lite 模式强调“零侵入”（不加项目 hooks，不改项目配置，不增加外部服务）。GStack 这种重度依赖本地编译及 codesign 签名服务的守护进程方案，会彻底破坏 lite 模式的零侵入红线；即使在 heavy 模式下，多进程守护的生命周期管理和本地编译开销也增加了系统的部署与维护复杂度。
- **建议**：在 `gstack.md` 浏览器小节前添加架构提示，说明 omni_powers 对 UI 验收的硬指标（CDP/cua/直驱）以宿主直接驱动或一次性测试运行为首选，当前阶段不引入基于 Bun 开发的常驻守护进程。但可参考其将 ARIA 树简化为 `@e1` 引用以降低 Token 损耗的 Ref 树设计。
- **置信度**：高
- **优先级**：HIGH

### 3. `trellis` 通过 PreToolUse 钩子拦截并注入 subagent 上下文的机制在 subagent 执行中静默失效
- **位置**：`docs/vendors_analyze/vendors_repo/trellis.md:127-129`、`docs/vendors_analyze/vendors_repo/trellis.md:201-220`
- **现象**：Trellis 在 `PreToolUse` 钩子中拦截 `trellis-implement` 和 `trellis-check` 子代理的派发，修改 `tool_input.prompt` 注入所需的 `implement.jsonl`/`check.jsonl` 及 PRD/设计等上下文文件内容。
- **影响**：`omni_powers_design.md` §0（设计原则 7）指出：“hook 自动跑测试对 subagent 已失效——Claude Code 的 subagent 不触发 PreToolUse/PostToolUse”。这意味着当主会话 leader 派发子代理时，Trellis 依赖的 `PreToolUse` 自动注入机制在 subagent 内部将无法触发，导致子代理在缺失上下文的情况下执行，造成机制静默失效。
- **建议**：在 `trellis.md` 的钩子说明部分明确添加高亮警告，指出该注入逻辑对于 Claude Code 派发的 subagent 无效；omni_powers 的 subagent 上下文传递必须在 dispatch 阶段由主会话 leader 亲手读取并以参数/Prompt 载体显式写入 dispatch prompt 中，或者由子代理在启动时自行检测是否存在注入标记并读取文件（需保证被读路径已挂载）。
- **置信度**：高
- **优先级**：HIGH

### 4. `trellis` 的三阶段工作流与面包屑状态机高度依赖 settings.json 钩子注册与 CLAUDE.md 注入，与 lite 零侵入设计冲突
- **位置**：`docs/vendors_analyze/vendors_repo/trellis.md:47-50`、`docs/vendors_analyze/vendors_repo/trellis.md:227-240`
- **现象**：Trellis 依赖 `UserPromptSubmit` 和 `SessionStart` 钩子在每次会话启动和用户输入时，动态提取并向上下文注入当前的任务状态和 breadcrumb。同时在 `CLAUDE.md` 中强制注入特定的开始和结束注释块。
- **影响**：在 omni_powers 的 lite 模式（design §5.3）下，“不改项目 CLAUDE.md、不加项目 hooks、不改用户 settings.json”是绝对红线。Trellis 这种基于频繁钩子动态注入 breadcrumb 状态的机制会破坏这一零侵入边界。如果直接参考，会导致 lite 模式退化或产生严重的机制失效。
- **建议**：在 `trellis.md` 的状态管理与配置部分添加注解，区分 heavy 模式（可通过 hooks 做类似的状态提示）与 lite 模式（必须依赖 leader 读写 `profile` 与 `leader_checkpoint.md` 自行推演并手动控制，不依赖 any 自动注入）。
- **置信度**：高
- **优先级**：HIGH

### 5. `gstack` 的 `/freeze` 和 `/guard` 机制（基于 PreToolUse 钩子文件编辑路径拦截）的安全防线在 subagent 下会静默绕过
- **位置**：`docs/vendors_analyze/vendors_repo/gstack.md:167-173`、`docs/vendors_analyze/vendors_repo/gstack.md:193-200`
- **现象**：GStack 提供了 `/freeze`（限制编辑到单目录）和 `/guard` 机制，通过 `PreToolUse` 钩子在编辑工具（如 Write/Edit）执行前进行拦截以锁定目录。
- **影响**：由于 subagent 在 Claude Code 下不触发 `PreToolUse`/`PostToolUse` 钩子，这导致如果派发出去的 `op-implementer` 子代理受到外部恶意输入注入等攻击，意图修改未授权的目录，GStack 基于钩子的拦截将形同虚设，子代理可以随意越界编辑。这印证了 omni_powers 把安全边界设在 leader 合回主分支时（`merge gate`）及 closer 动作后（`closer gate`）的正确性。
- **建议**：在 `gstack.md` 的范围控制部分添加警告，指出 hooks 拦截无法防范 subagent 越界，重申必须使用 merge gate 进行物理分支级的 diff 校验。
- **置信度**：高
- **优先级**：HIGH

---

## 中低优先级问题（MEDIUM / LOW）

### 6. 调研文件中缺少分析日期等元数据，影响时效性评估
- **位置**：`docs/vendors_analyze/vendors_repo/bmad-method.md`、`docs/vendors_analyze/vendors_repo/gstack.md`、`docs/vendors_analyze/vendors_repo/trellis.md`
- **现象**：三份文件均在说明时效性时提及“2026年6月”或“2026年至今”，但没有统一高亮的分析日期（如 `> 分析日期：2026-07-08`）。
- **影响**：由于调研对象处于极高频的迭代中。没有统一的分析基线日期，未来开发人员难以确定这些分析对应其哪个版本分支，增加了维护时的对照成本。
- **建议**：在上述三份调研文件头部补齐分析日期标识（即 2026-07-08）。
- **置信度**：高
- **优先级**：MEDIUM

### 7. 调研文件中关于会话记忆机制的记录与 omni_powers 已有设计术语和设计实践重合，缺乏对照去重
- **位置**：`docs/vendors_analyze/vendors_repo/bmad-method.md`、`docs/vendors_analyze/vendors_repo/gstack.md`、`docs/vendors_analyze/vendors_repo/trellis.md` 关于记忆和状态管理的小节
- **现象**：各文件分别对 `memlog.py`、`learnings.jsonl`/`decisions.jsonl`、`journal-N.md` 进行了详细的记录，这些记录实际上是 omni_powers 目前 `progress.md` 与 `decisions.md` 设计的重要灵感来源。但文件本身没有将这些调研事实与 omni_powers 的具体设计项进行对比或关联。
- **影响**：仅保留原始调研细节，使得调研报告显得孤立，不利于开发团队直接理解“我们为什么采用了目前的 progress.md/decisions.md 设计”。
- **建议**：在 `docs/vendors_analyze/overview.md` 中进行统一索引与去重归口，将上述文件的核心发现分类梳理并对照 omni_powers 的具体实现（例如：Trellis 的 Journal 对应 omni_powers 的 `progress.md`，GStack 的 Decisions 对应 omni_powers 的 `decisions.md`），使调研真正服务于 design 的解释。
- **置信度**：中
- **优先级**：MEDIUM

---

## 改进建议

1. **统一的“厂商参考边界说明”**：建议在 `docs/vendors_analyze/overview.md` 中增加一节，总结 `bmad-method`、`gstack` 和 `trellis` 与 omni_powers 的异同，尤其是如何吸纳其“先规约后代码”的设计精髓，同时舍弃其“重度依赖客户端 hooks”和“文档冗余”的设计缺陷。
2. **规范化 UI 验收决策树**：GStack 使用常驻 $B 守护进程，Trellis 采用 pre-development checklist + inline/sub-agent 区分。建议 omni_powers 进一步在 `docs/omni_powers_design.md` 的可测性契约和 evaluator 部分明确 CDP 优先的调试规范，参考 GStack 的 ARIA 树映射，以防 evaluator 在 UI 交互测试时由于大量 HTML 的解析而导致上下文迅速爆炸。

---

## 不确定项 / 可能误报

- **关于 Claude Code 对 subagent 触发 hooks 限制的变更**：如果未来版本的 Claude Code 升级了其 subagent 执行机制，使得 `Agent tool` 派生的子会话能够继承并触发宿主系统的 `PreToolUse`/`PostToolUse` 钩子，则 Trellis 和 GStack 的钩子注入、路径拦截方案在安全和环境隔离上将重获可行性。目前将其判断为“静默失效”是基于当前 Claude Code 版本的安全保守策略。