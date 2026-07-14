# 10_vendors_repo_impl — sonnet 审阅报告

> 审阅对象：`docs/vendors_analyze/vendors_repo/bmad-method.md`、`gstack.md`、`trellis.md`
> 核心参考：`docs/omni_powers_design.md`
> 审阅时间：2026-07-08 20:59 UTC+8
> 审阅模型：sonnet

---

## 一、总体判断

三个文件均属 vendor 分析参考资料，记录了 bmad-method v6.9.0、gstack v1.58.5.0、trellis v0.6.5 的架构、安装机制、工具全景、编排模式。它们为 `docs/omni_powers_design.md` 的设计决策提供了背景信息，本身不是设计契约的一部分。三份文档技术准确性高，与 design 无结构性冲突，但存在以下问题：

1. bmad-method.md 的对比表（第 9 节）有几处描述与 design 当前状态不完全一致；
2. gstack.md 和 trellis.md 缺少与 omni_powers 的显式对比/启示段，追溯学习成果困难；
3. 三份文件之间无交叉引用，同属 vendors_repo/ 目录但各自独立；
4. 存在信息老化风险——design 持续演进但 vendor 分析文件无更新机制。

---

## 二、逐文件发现

### 2.1 bmad-method.md

**位置**：第 9 节对比表，"SessionStart 注入"行，"omni_powers"列
**现象**：描述为「无大段 SessionStart 注入；依赖 skill 按需读取 `$OP_HOME` 文档」。
**影响**：与 design §6.3 / §5.3 描述不一致。heavy 模式确实曾有大段 SessionStart 注入（后因 A17 移除），lite 模式则从未有。当前 design 明确 lite「无自动发现：新会话/compact 后无 SessionStart 注入（A17 已去）」，heavy 的 SessionStart 也只注入 index.md 摘要。该描述过于简化，且未反映 heavy/lite 两模式差异。
**建议**：更新为两模式描述——heavy: SessionStart 注入 `docs/omni_powers/index.md` 摘要（轻量）；lite: 无 SessionStart 注入，靠用户手动 `/oplrun`。
**置信度**：高
**优先级**：P2（信息性偏差，不影响设计正确性）

---

**位置**：第 9 节对比表，"配置注入"行，"omni_powers"列
**现象**：描述为「`/opinit` 写使用方 settings env，运行时按 `$OP_HOME` 定位」。
**影响**：仅描述 heavy 行为，未提及 lite 不修改 settings.json。design §5.3 明确 lite 禁止写入 `~/.claude/settings.json`。
**建议**：补充 heavy/lite 分述，或注明此行为为 heavy only。
**置信度**：高
**优先级**：P3（已有 overview.md 补充上下文，不紧急）

---

**位置**：第 9 节对比表，"IDE 适配"行
**现象**：omni_powers 列为「Claude Code only」。
**影响**：准确。与 design 一致。无需修改。
**置信度**：高
**优先级**：无

---

**位置**：全文
**现象**：bmad-method.md 技术分析详尽准确，step-file 架构、三层合并配置、Party Mode 的描述均与 bmad-method 仓库实际一致。作为 vendor 参考文档价值高。
**影响**：正面。为 design 中"task 严格串行"、"spec 即契约"等决策提供了对比参照。
**建议**：无修改需要。但建议在文件顶部加一行元数据注明"分析日期 2026-07-02，基于 bmad-method v6.9.0"以明确时效性（已有生成时间标注在 overview.md，各分文件未单独标注）。
**置信度**：高
**优先级**：P3

---

### 2.2 gstack.md

**位置**：全文
**现象**：缺少与 omni_powers 的显式对比段。bmad-method.md 有第 9 节对比表，gstack.md 无。
**影响**：读者需回到 `overview.md` 的第五、六节才能了解 gstack 对 omni_powers 的具体启示（浏览器验证、安全护栏等）。文件自足性不足。
**建议**：在 gstack.md 末尾追加「对 omni_powers 的关键启示」小节，从 overview.md 第六节提取相关行，或至少添加指向 overview.md 的交叉引用。
**置信度**：中（取决于是否认为 vendor 分析文件需要自足）
**优先级**：P3

---

**位置**：第 4.4 节 Security Stack
**现象**：对 gstack L1-L6 安全栈的分析准确，但未评估其与 omni_powers 安全模型的差距。
**影响**：omni_powers design §3.3 的机械护栏与 gstack 六层安全栈是完全不同的设计路线。gstack 走 ML 分类器 + canary token 的 prompt 注入防御路线，omni_powers 走 git 拓扑 + merge gate + 访问隔离的结构性路线。vendor 分析未点出这一根本分歧。
**建议**：追加一段路线分歧分析——gstack 假设威胁来自外部网页内容注入 LLM 上下文；omni_powers 假设威胁来自 subagent 产物可信度与同源污染。两条路线解决不同问题，不矛盾。
**置信度**：高
**优先级**：P3

---

**位置**：第 6 节 SessionStart 注入
**现象**：准确描述了 gstack 的 SessionStart 只做 auto-update、router/skill 按需加载的策略。与 design §5.3 lite 的零注入路线有可比性。
**影响**：正面参考。为 lite 的"无 SessionStart 注入"设计提供了同路线先例。
**建议**：在文件末尾启示段标注此可比性。
**置信度**：中
**优先级**：P3

---

**位置**：第 8 节编排模式
**现象**：gstack 的编排模式分析准确（Router + Pipeline + Leader-Worker + Outside Voice）。但未与 omni_powers 的"leader 编排 + spec 唯一契约 + task 严格串行"做对比。
**影响**：overview.md 第四节已做编排复杂度对比（gstack 为"多模式混合"），但 gstack.md 自身未提。
**建议**：同 "关键启示" 建议，统一在文件末尾追加。
**置信度**：中
**优先级**：P3

---

### 2.3 trellis.md

**位置**：全文
**现象**：与 gstack.md 同样缺少与 omni_powers 的显式对比/启示段。
**影响**：trellis 的 hook 驱动上下文注入是 design overview.md 第六节明确标注的"可借鉴动态摘要"对象，但 trellis.md 自身未展开此点。
**建议**：追加启示段，重点标注：
- trellis 的 PreToolUse 子 agent 上下文注入 → omni_powers 的 dispatch prompt 注入（异曲同工，但 omni_powers 走 dispatch 脚本机械组装而非 hook 拦截）
- trellis 的 breadcrumb 状态机 → omni_powers 的 checkpoint + tasks_list.json
- trellis 的 task.py 生命周期 → omni_powers 的 tasks_list.json 状态枚举
**置信度**：高
**优先级**：P3

---

**位置**：第 4.2 节 PreToolUse Sub-Agent Context Injection
**现象**：对 trellis 的 `inject-subagent-context.py` 分析准确详尽。但 overview.md 已有一条重要限定——「不可作为访问控制、写权限隔离或安全边界」——trellis.md 自身未重复这一限定。
**影响**：单独阅读 trellis.md 的读者可能误认为 omni_powers 可直接照搬此模式，忽略 design §0.1 的信任根声明和 §2.5 的访问隔离设计。
**建议**：在 trellis.md 该节末尾添加与 overview.md 一致的限定声明。
**置信度**：高
**优先级**：P2（安全相关限定，漏标可能误导）

---

**位置**：第 5.1 节目录结构 vs design §1
**现象**：trellis 的 `.trellis/spec/` + `.trellis/tasks/` + `.trellis/workspace/` 三区布局与 omni_powers 的 `op_blueprint/` + `op_execution/` + `op_record/` 三区制有结构相似性。但 vendor 分析未做对比。
**影响**：这是一个有价值的参考点——trellis 的目录设计验证了"按用途分三区"的合理性，可增强 design §1 的说服力。
**建议**：在启示段提及此结构相似性。
**置信度**：中
**优先级**：P3

---

**位置**：第 8 节编排模式
**现象**：trellis 的 Phase 1 (Plan) → Phase 2 (Execute) → Phase 3 (Finish) 与 omni_powers 的 Stage 1 (spec) → Stage 2 (task 拆分) → Stage 3 (执行循环) → Stage 4 (收尾) 有概念对应但实现差异大。trellis 允许 Phase 2 回退到 Phase 1（prd defect），omni_powers 走 spec 变更子流程。
**影响**：可作为"阶段回退策略"的设计参考。
**建议**：启示段标注。
**置信度**：中
**优先级**：P3

---

## 三、跨文件共性问题

### 3.1 缺少目录内索引

**位置**：`docs/vendors_analyze/vendors_repo/`
**现象**：目录下有 10 个独立 vendor 分析文件，无本级 README 或 index 文件做快速导航。读者需先读上级 `overview.md` 才知道每个文件是什么。
**影响**：轻度。overview.md 已提供总览和横向对比，导航功能不缺失。但 vendors_repo/ 作为 10 文件集合，缺少自描述。
**建议**：在 vendors_repo/ 下加一个 README.md，内容为一行说明 + 指向 overview.md 的链接 + 10 文件清单。
**置信度**：高
**优先级**：P3

---

### 3.2 文件时效性标注不统一

**位置**：三个文件均未在文件顶部标注分析日期和所基于的 vendor 版本
**现象**：bmad-method.md 正文首段提到 v6.9.0，gstack.md 第 13 行提到 v1.58.5.0，trellis.md 第 14 行提到 v0.6.5。但均无机器可解析的元数据块（如 YAML frontmatter）。
**影响**：6 个月后 vendor 大版本升级，这些分析文件可能过时但无标记可查。
**建议**：统一在文件顶部加 YAML frontmatter 或固定格式的元数据行：`分析日期: 2026-07-02 | 版本: vX.Y.Z | 分析员: <模型名>`
**置信度**：中
**优先级**：P3

---

### 3.3 与 design 演进不同步

**位置**：三个文件整体
**现象**：vendor 分析生成于 2026-07-02，design 此后经历多次提交（全流程更新、D6 验收前置、D3 closer_gate、D5/D9/D4-B/D12 收尾等）。vendor 文件中提及 omni_powers 的部分（主要是 bmad-method.md 第 9 节）未随 design 演进更新。
**影响**：信息性偏差，不影响设计正确性。但若未来有人基于这些对比表做决策，可能依据过时信息。
**建议**：
- 方案 A：在 bmad-method.md 第 9 节加注"此对比基于 design 2026-07-02 快照，可能已过期，以 `docs/omni_powers_design.md` 当前版本为准"。
- 方案 B：vendor 分析文件整体归档为历史参考，不再维护对比表，对比逻辑移回 design 自身。
- 推荐方案 A：成本最低，保留 vendor 分析独立价值。
**置信度**：高
**优先级**：P2

---

## 四、维护价值评估

### 4.1 当前价值

- **bmad-method.md**：**高**。对比表（第 9 节）和 step-file 架构分析对理解 omni_powers 与同类系统的差异有直接帮助。
- **gstack.md**：**高**。浏览器守护进程和安全栈分析是独特参考，overview.md 多处引用。gstack 是唯一带"真实浏览器眼睛"的 vendor。
- **trellis.md**：**中高**。hook 注入机制和 task 状态机分析有价值，但与 omni_powers 设计路线分歧较大（trellis 重 hook 注入，omni_powers 因 subagent hook 失效而重结构隔离）。

### 4.2 长期维护建议

- **不归档**：三个文件仍服务 design 参考目的。vendor 项目活跃，分析内容未过时。
- **轻维护**：按本报告 P2 项更新后，vendor 分析文件转为"冻结参考"——不随 design 演进同步更新对比表，但在文件顶部标注快照日期和"以 design 当前版本为准"的免责声明。
- **去重**：无需去重。三文件分别覆盖三个不同类型的 vendor（方法论框架 / 重量级 harness / hook 驱动工程框架），无内容重叠。

---

## 五、问题汇总

| 编号 | 文件 | 位置 | 问题 | 优先级 | 置信度 |
|------|------|------|------|--------|--------|
| S-01 | bmad-method.md | §9 "SessionStart 注入" | omni_powers 描述未反映 heavy/lite 两模式差异 | P2 | 高 |
| S-02 | bmad-method.md | §9 "配置注入" | 仅描述 heavy 行为，未提 lite 不改 settings.json | P3 | 高 |
| S-03 | gstack.md | 全文 | 缺少与 omni_powers 的显式对比/启示段 | P3 | 中 |
| S-04 | gstack.md | §4.4 | 安全栈路线分歧未分析 | P3 | 高 |
| S-05 | trellis.md | 全文 | 缺少与 omni_powers 的显式对比/启示段 | P3 | 高 |
| S-06 | trellis.md | §4.2 | 缺少 hook 注入"不可作为安全边界"的限定声明 | P2 | 高 |
| S-07 | 跨文件 | vendors_repo/ | 缺少目录级 README 导航 | P3 | 高 |
| S-08 | 跨文件 | 文件顶部 | 缺少统一的时效性元数据标注 | P3 | 中 |
| S-09 | 跨文件 | 对比表 | 与 design 演进不同步，存在信息老化风险 | P2 | 高 |

**优先级分布**：P2 × 3，P3 × 6，无 P0/P1。

---

## 六、总结

三份 vendor 分析文档技术质量高，覆盖全面，与 `docs/omni_powers_design.md` 无结构性冲突。主要问题是信息老化——design 已演进而 vendor 对比表未跟随更新。建议按 P2 项处理时效性标注和安全限定声明后，将 vendor 分析文件标记为"冻结参考"——保留独立价值但不承诺与 design 同步演进。三文件值得保留，不需归档或去重。
