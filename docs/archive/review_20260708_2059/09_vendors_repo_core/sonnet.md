# sonnet 视角审阅报告：vendors_repo 参考资料

## 当前模型判断依据

- 主会话 powered by `default_model`（默认档位继承）
- 本审阅以 sonnet 视角独立判断
- 审阅核心参考：`docs/omni_powers_design.md`

## 审阅范围

| 文件 | 路径 |
|------|------|
| agent-skills 分析 | `docs/vendors_analyze/vendors_repo/agent-skills.md` |
| OpenSpec 分析 | `docs/vendors_analyze/vendors_repo/openspec.md` |
| planning-with-files 分析 | `docs/vendors_analyze/vendors_repo/planning-with-files.md` |
| spec-kit 分析 | `docs/vendors_analyze/vendors_repo/spec-kit.md` |

审阅目标：判断这四份 vendor 参考资料是否仍服务 design、是否存在与现行设计冲突的未归档结论、是否需要索引/去重/标注参考边界。

---

## 高优先级问题

### 1. agent-skills.md 含跨文档设计约束（第 558 行）

- **位置**：`agent-skills.md` 第 558 行
- **现象**：原文「agent-skills 明确把 persona 互调列为反模式；不要把这一点泛化为 omni_powers 的永久平台契约」
- **影响**：这是一条从 vendor 分析中提取的**设计约束**，直接作用于 omni_powers 的架构决策。但 design 中并无对此约束的明确记录——design 虽有"task 严格串行"（原则 9）和 reviewer 双裁决独立运行，但未禁止未来放开 agent 间互调。此条旁注作为 vendor 分析的副作用产出了设计约束，存在两个风险：
  1. 约束的出处是 vendor 分析文档而非 design 本体——后续设计迭代时可能遗漏此约束
  2. 约束的适用范围和条件边界未定义——"永久平台契约"的措辞过强，与原则 12"模型升级后重新审视护栏"形成张力
- **建议**：将此约束的**实质内容**（「subagent 间不应互相调用——编排归 leader」）写入 design 原则或 op_decisions.md，并注明来源为 agent-skills 反模式分析的参考结论、非纯 vendor 事实记录。vendor 文档中保留引用指针指向 design/decisions 中的正式记录位置。
- **置信度**：高（0.85）
- **优先级**：高

### 2. OpenSpec 对比表直接对比 omni_powers，无版本锚定

- **位置**：`openspec.md` 第 413-421 行（表格）
- **现象**：表格逐维度对比 OpenSpec 与 omni_powers（Agent 角色、编排方式、工作流定义、状态追踪、代码审查、TDD），但未标注 omni_powers 的对比版本或快照时间点。
- **影响**：omni_powers design 持续演进（例如 evaluator 验收前置 D6、P0 事后报告 A18、lite closer gate 等），表格中的对比结论可能随 omni_powers 版本更新而过时。OpenSpec 侧有明确版本号（v1.5.0），omni_powers 侧缺失对应锚点。
- **建议**：在对比表上方加一行标注「omni_powers 对比版本：基于 design 文档 2026-07 快照」，并在 vendors_repo 目录的索引中标注此对比表需随 design 重大变更同步复核。
- **置信度**：高（0.90）
- **优先级**：高

### 3. planning-with-files 的 hook 重度注入策略与 design §0.1 存在未标注架构矛盾

- **位置**：`planning-with-files.md` 第 61-69 行（hook 事件表），对比 design §0.1 第 38 行
- **现象**：planning-with-files 的核心机制是**每次 turn / 每次 tool call 前通过 hook 注入 plan head**（UserPromptSubmit + PreToolUse + PostToolUse + Stop 全覆盖），这是其「文件即共享内存」策略的基石。但 omni_powers design §0.1 明确指出「hook 对 subagent 整体失效——Claude Code 的 subagent 不触发 PreToolUse/PostToolUse」。两条路径的架构假设直接矛盾：
  - planning-with-files 信赖 hook 在**主会话**每个生命周期点注入上下文（它不依赖 subagent 内 hook，因为它本来就是主会话单 agent 模式）
  - omni_powers 的主会话 hook 同样有效，但全系统核心工作流在 subagent 中执行——planning-with-files 的 hook 策略在 omni_powers 的 subagent 场景下全部失效
- **影响**：vendor 文档未标注此差异，可能导致后续读者误以为 planning-with-files 的 hook 模式可直接移植到 omni_powers。实际可参考的是其 **"文件即外部记忆"的理念**（与 omni_powers 的 leader_checkpoint + compact 恢复对齐），而非 hook 注入的实现手段。
- **建议**：在 vendor 文档末尾增加「与 omni_powers 兼容性说明」段，标注 hook 注入在 subagent 场景下失效，澄清可参考部分（文件持久化理念、phase 状态格式、attestation 思路）与不可直接移植部分（per-turn hook 注入策略）。
- **置信度**：高（0.88）
- **优先级**：高

### 4. 四份 vendor 文档均缺少与 design 的参考边界标注

- **位置**：全四个文件
- **现象**：四份文档各自独立分析 vendor，但均无以下标注：
  - 该 vendor 的哪些设计决策**已被 omni_powers 采纳或参考**（含出处指向 design/decisions 的具体位置）
  - 哪些是**明确不同的路径**（含原因）
  - 哪些是**待定/待深入研究**的
- **影响**：vendor_repo 目录目前是「信息堆」而非「决策参考库」。后续 design 演进时，无法快速判断某条 vendor 经验是否已被消化、是否仍需关注、是否已有结论。存在重复评估同一 vendor 特征的风险。
- **建议**：为 vendors_repo 目录增加 `README.md` 索引，对每个 vendor 文档标注三列：「已采纳（→design 位置）」「已排除（原因）」「待定」。各 vendor 文档头部增加与 design 的关联段（不超过 10 行），标注本分析对应的 design 版本快照。
- **置信度**：高（0.92）
- **优先级**：高

---

## 中低优先级问题

### 5. agent-skills 反模式目录与 omni_powers 编排模式的关系未梳理

- **位置**：`agent-skills.md` 第 544-550 行（4 种反模式）
- **现象**：agent-skills 定义了 A. 路由 Persona / B. Persona 调用 Persona / C. 串行编排器转述 / D. 深层 Persona 树 四种反模式。omni_powers 的 leader→implementer→reviewer→evaluator→closer 链是否命中这些反模式、命中后如何处理，未在任何文档中系统分析。
- **影响**：中等。不影响当前执行，但在未来考虑放开并行 task 或多 agent 协作时，缺乏对已知反模式的对照检查会增加设计风险。
- **建议**：在 op_decisions.md 中增加一条记录，逐条对照 4 种反模式分析 omni_powers 现行架构的免疫/风险/缓解措施。不应放入 vendor 文档（那是分析原料），应放入 decisions（那是设计结论）。
- **置信度**：中（0.70）
- **优先级**：中

### 6. OpenSpec 的 delta spec 模型与 omni_powers 两层 spec 的对比未归档

- **位置**：`openspec.md` 整体，对比 design §1.2
- **现象**：OpenSpec 用 delta spec（ADDED/MODIFIED/REMOVED）描述变更，归档时 merge 进主 spec。omni_powers 用两层 spec（op_execution 工作 spec → closer 提炼 → op_blueprint 生效规格）。两种模型有显著结构差异但 vendor 文档只做了维度对比表，未分析两种模型各自的适用场景和取舍。
- **影响**：低。omni_powers 已选型两层模型，短期内不会切换。但 delta spec 的「显式表达变更」思路可能对 spec 变更子流程（design §2.4）有参考价值。
- **建议**：在 vendor 文档末尾增加一行备注：「OpenSpec delta spec 模型对 omni_powers spec 变更子流程的潜在参考点——变更的显式表达（ADDED/MODIFIED/REMOVED）可降低 decisions.md 中 spec-delta 的歧义」。
- **置信度**：中（0.65）
- **优先级**：低

### 7. planning-with-files v3 phase coordination 字段与 tasks_list.json 的对照未做

- **位置**：`planning-with-files.md` 第 363-377 行，对比 design §2.3
- **现象**：planning-with-files v3 引入了 `parallel_workers`、`can_start`、`can_parallelize`、`assigned_to` 等多 agent 协调字段。omni_powers 的 `tasks_list.json` 目前只有 `depends_on`，且原则 9 明确「task 严格串行」。v3 的这些字段对 omni_powers 未来放开并行有参考价值，但文档未对照分析。
- **影响**：低。当前串行执行不需要这些字段，仅作远期参考。
- **建议**：在 vendor 文档中标注「远期参考：此段对 omni_powers 放开并行 task 执行时有参考价值（原则 9 已预留放开条件：先解决共享文件写入协议）」，不必展开。
- **置信度**：中（0.60）
- **优先级**：低

### 8. spec-kit constitution.md 与 omni_powers domain.md 的职责重叠未澄清

- **位置**：`spec-kit.md` 第 447 行（constitution.md 作为「不可变原则」），对比 design §1.3
- **现象**：spec-kit 的 constitution.md 定位为「所有 spec/plan/tasks 阶段都会读取的不可变原则」，与 omni_powers 的 domain.md（跨功能全局不变量）和 conventions.md（编码约定）存在职责重叠。vendor 文档未澄清两者的边界差异。
- **影响**：低。omni_powers 已将原则拆分到 domain（业务不变量）和 conventions（编码约定），比 constitution 单文件更精细。
- **建议**：在 vendor 文档中加一行备注：「spec-kit constitution.md = omni_powers domain.md（业务不变量）+ conventions.md（编码约定）的合并形态。omni_powers 拆分为两个文件以获得更清晰的职责边界（design §1.3）」。
- **置信度**：中（0.70）
- **优先级**：低

---

## 改进建议

### 建议 1：建立 vendors_repo 索引文件

在 `docs/vendors_analyze/vendors_repo/` 下新增 `README.md`，内容：

- 四个 vendor 的一句话说清定位
- 每个 vendor 的「已采纳 / 已排除 / 待定」三列状态表
- 与 design 的交叉引用指针
- 维护约定：design 重大变更后需复核的条目清单

### 建议 2：各 vendor 文档头部增加与 design 的关联段

每个 vendor 文档在现有内容之前增加不超过 10 行的关联段：

```markdown
## 与 omni_powers 的参考关系

- 分析版本：基于 omni_powers design 2026-07 快照
- 已采纳：[具体条目 → design/decisions 位置]
- 已排除：[条目 + 排除原因]
- 待定：[条目 + 待决断点]
```

此段由 leader 在消化 vendor 经验后填写并维护，不要求四份都一次性补齐。

### 建议 3：将跨文档设计约束提升到 decisions

上述高优先级问题 1（agent-skills 反模式约束）的核心内容是设计决策而非 vendor 事实，应从 vendor 文档中提取并写入 `op_decisions.md`，vendor 文档保留引用指针。

---

## 不确定项

### U1：planning-with-files 的 hash attestation 机制是否值得参考

planning-with-files 的 SHA-256 哈希锁定 + 每次注入前校验机制（第 139-142 行），与 omni_powers 的 trailer 自锁（design §2.5）有相似的「防篡改证据」意图。不确定 omni_powers 的 trailer 机制是否需要借鉴 attestation 的「缓存 + gated 模式强制 rehash」设计。留待 leader 判断。

### U2：spec-kit 的 workflow YAML 引擎是否可作为 oprun 未来 Pipeline 化的参考

spec-kit 的 workflow.yml（第 367-387 行）支持 gate 步骤、条件分支、循环、多集成。omni_powers 目前没有 workflow 引擎（task 循环逻辑在 skill SKILL.md 中硬编码）。不确定未来是否需要提取为声明式配置。留待设计演进时参考。

---

## 总结

四份 vendor 文档整体质量高，分析深入，覆盖了当前主流 AI 编程工作流工具的核心特征。主要问题集中在**参考边界标注缺失**和**跨文档设计约束未归档**两个方向。建议优先落地「改进建议 1（索引文件）」和「高优先级问题 1（将 agent-skills 反模式约束写入 decisions）」，其余可随 design 演进逐步消化。
