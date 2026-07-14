# 审阅报告：vendors_analyze 主文档

> 审阅分块：08_vendors_main
> 审阅模型：haiku（model_override_authorized）
> 审阅对象：
> - docs/vendors_analyze/overview.md
> - docs/vendors_analyze/deep-discussion-notes.md
> - docs/vendors_analyze/spec_and_plan_comparison.md
> 核心参考：docs/omni_powers_design.md
> 审阅时间：2026-07-08
> 源文件只读；独立判断；中文。

---

## 一、总体定位判断

三份文档作为"厂商参考资料"的定位基本成立：design.md 正文零处提及任何具体 vendor，CLAUDE.md 第 106 行单条索引 `docs/vendors_analyze/overview.md` 作为"厂商分析"入口，RULES.md / agents/ / skills/ 同样零语义依赖。这意味着 vendors_analyze 是纯背景调研档案，不进运行时上下文，不构成契约源——这与 design.md §0 的"规格是唯一契约"原则一致。

但存在三处定位瑕疵：(1) overview.md 引用了不存在的 `vendors_repo/{repo_name}.md`；(2) overview.md 与 deep-discussion-notes.md 存在大面积内容重复；(3) 三份文档内嵌的"对 omni_powers 的建议"存在与现行 design 漂移或过时表述。逐项见下。

---

## 二、问题清单

### P1-01 vendors_repo 引用悬空，overview.md 自承诺无法兑现

- **位置**：overview.md 第 3-5 行
- **现象**：
  - 第 3 行："分析对象：`vendors/` 下 10 个 Claude Code harness 相关插件/工具集"
  - 第 5 行："每个 repo 的详细分析见 `vendors_repo/{repo_name}.md`"
- **影响**：仓库中 `docs/vendors_repo/` 目录物理不存在（已核实：`ls docs/vendors_repo/` 返回 NOT FOUND；`docs/` 下只有 archive/vendors_analyze 等）。overview.md 向读者承诺了 10 份详细单 repo 分析，读者按指引走会落空。同时第 3 行用 `vendors/`、第 5 行用 `vendors_repo/`，路径前缀不一致，加剧困惑。本轮审阅分块规划（09/10/11 vendors_repo_core/impl/other）同样预期该目录存在——悬空范围扩大到审阅流程自身。
- **建议**：二选一。
  - (A) 若 vendors_repo 分析从未产出，删除第 5 行该指引，并在第 3 行统一为 `docs/vendors_analyze/` 下 10 个 repo；同时同步调整本轮审阅分块 09/10/11 的规划。
  - (B) 若 vendors_repo 曾存在后被移除，从 `docs/archive/` 找回或从 git 历史恢复，overview.md 保持原样。
  - 路径前缀统一为 `vendors_repo/` 或 `docs/vendors_repo/`，消除 `vendors/` 歧义。
- **置信度**：高（物理验证）
- **优先级**：P1（读者按索引落空，且本轮审阅分块依赖此目录）

### P2-01 overview.md 与 deep-discussion-notes.md 内容大面积重叠

- **位置**：
  - overview.md §五 深度讨论结论（第 89-173 行）：spec-kit vs OpenSpec、gstack vs ECC、agent-skills vs superpowers/mattpocock、bmad-method、trellis、planning-with-files 六节
  - deep-discussion-notes.md §二-四（spec-kit/gstack/agent-skills 详解）+ §七-九（bmad/trellis/planning-with-files 详解）
  - overview.md §八 补充整理映射（第 203-228 行）"三个共同点"等
  - deep-discussion-notes.md §十 三个共同点（第 366-373 行）
- **现象**：overview.md §五几乎每一节都是 deep-discussion-notes.md 对应章节的压缩复述；§八"三个共同点"与 deep-discussion-notes §十"三个共同点"文字近乎逐字重复。overview.md 自身在 §八注释中写"原讨论中的'七个 repo 类型总览'已合并进本文二、类型总览"——说明作者已知有重复合并发生，但合并不彻底。
- **影响**：同一事实在三处维护（overview 表格 + overview §五 + deep-discussion 详解），任一处更新需同步多处，漂移风险高。作为参考资料，信息冗余增加读者扫读成本，违背 design §1.3"重复内容只留一份（独占者）"的文档职责原则——虽然该原则明示针对 op_blueprint，但作为项目文档规范有参考价值。
- **建议**：
  - overview.md 定位为"索引 + 横向对比表 + 关键启示"——保留 §一横向对比表、§二类型总览、§三按维度归类、§四核心差异化技术、§六对 omni_powers 启示、§九总判断。
  - §五深度讨论结论压缩为一行指引："详见 deep-discussion-notes.md"，不再在 overview 复述各 repo 详解。
  - §八"三个共同点"删除或改为一行链接指向 deep-discussion-notes.md §十。
  - deep-discussion-notes.md 作为唯一详解独占者。
- **置信度**：高
- **优先级**：P2（不影响正确性，但维护成本与扫读成本显著）

### P2-02 overview.md §六"对 omni_powers 的建议"部分过时

- **位置**：overview.md 第 175-188 行（§六对 omni_powers 的关键启示表）
- **现象**：表中 9 行"建议"，其中至少 3 行与现行 design 已落地状态不符或表述模糊：
  - 第 182 行"task 生命周期"建议"`tasks_list.json` 应继续作为执行唯一真相，并配 checkpoint 恢复"——现行 design §1.1/§2.4 已实现 tasks_list.json 为 task 元数据唯一源 + leader_checkpoint.md，且 §0.2 能力矩阵标注 /oprun 启动注入为 P1。建议表述停留在"应"，读起来像未做。
  - 第 184 行"配置可定制"建议"后续可引入默认/项目/用户三层模型配置"——现行 design 用 `OP_IMPLEMENTER_MODEL`/`OP_REVIEWER_MODEL`/`OP_EVALUATOR_MODEL`/`OP_CLOSER_MODEL` 环境变量参数化（§2 模型分配表后），非"三层可合并配置"。建议方向与现行实现路径不一致，易误导。
  - 第 187 行"子 agent ctx 注入"建议"可借鉴动态摘要，减少 leader 派发 prompt 冗余；不可作为访问控制、写权限隔离或安全边界"——现行 design §2.4 dispatch 采用"指针注入"（TID+spec 路径+workset/depends_on 由脚本从 tasks_list.json 提取注入），并未走 trellis 式 hook 自动注入；且 design §5.3 lite 明确零侵入不加 hook。建议未标注"已采用指针注入方案"这一现状。
- **影响**：作为参考资料，建议栏与现行实现状态脱节，读者（尤其新 contributor）可能误以为这些是待办项而开 PR 做重复工作或走偏方向。
- **建议**：§六表加一列"当前状态"（已采纳/部分采纳/未采纳/不建议），逐行标注。或整节降格为"历史启示记录"，顶部加注"本表为 2026-07-02 调研时建议，现行实现见 design.md"。spec_and_plan_comparison.md 第 464 行已有类似处理（"以下是 mattpocock_skills 的 vendor 术语，不是 omni_powers 当前入口"），可作范式。
- **置信度**：中高（design 对照）
- **优先级**：P2

### P2-03 spec_and_plan_comparison.md 与 overview.md 对 OpenSpec 的"plan 阶段"表述需统一

- **位置**：
  - spec_and_plan_comparison.md 第 13 行表格：OpenSpec "Plan 强制程度 = 无独立 plan 阶段"；§2.2 标题"OpenSpec — Delta SPEC，无 Plan"；第 161-163 行"为什么没有 Plan"
  - overview.md 第 18 行表格：OpenSpec"核心能力 = Delta spec 差异管理"，未单独点出"无 plan"
  - overview.md §五 第 92-100 行 spec-kit vs OpenSpec 对比表：未列 plan 维度
- **现象**：spec_and_plan_comparison 已明确指出 OpenSpec"无独立 plan 阶段"，这是 OpenSpec 的关键差异化特征。overview.md §一表格"核心能力"列未提，§五 spec-kit vs OpenSpec 对比表未将 plan 作为对比维度，导致只读 overview 的读者可能误判 OpenSpec 也有 plan。
- **影响**：低。overview 是入口，读者大概率会顺链读 spec_and_plan_comparison。但作为"横向对比总览"，关键差异不应藏在二级文档。
- **建议**：overview.md §五 spec-kit vs OpenSpec 对比表加一行"Plan 阶段"（OpenSpec 无 / spec-kit 强制 4 步）。
- **置信度**：高
- **优先级**：P2（轻微，一致性补强）

### P3-01 三份文档均无"时效声明 / 数据采集时点"统一标注

- **位置**：
  - overview.md 第 12-21 行表格：Star 数标注"采集时量级"仅在 ECC（224.6K）与 gstack（118.7K）两行；其余 8 行 Star 数（243.4K/152.9K/117.0K/68.4K/58.2K/49.9K/24.3K/11.5K）未标注是否采集时值
  - overview.md 顶部"生成时间：2026-07-02"
  - deep-discussion-notes.md / spec_and_plan_comparison.md 顶部"日期：2026-07-02"
- **现象**：Star 数、版本号（如 gstack v1.58、trellis v0.6.5、planning-with-files v3.1.3）、commit 数、贡献者数均为时点数据，三份文档统一生成于 2026-07-02，距今约 6 天。表格内部分数值标注"采集时量级"、部分未标，标注不一致。
- **影响**：作为参考资料，时点数据不标注会让未来读者误判为当前值。Star/版本/commit 数 6 个月后大概率漂移。
- **建议**：overview.md §一表格表头或表格上方加统一声明"表中 Star/版本/commit/贡献者数均为 2026-07-02 采集时值，仅供量级参考"，删除单行的"采集时量级"零散标注。三份文档顶部时间戳保持。
- **置信度**：高
- **优先级**：P3（非阻塞，参考资料常规处理）

### P3-02 deep-discussion-notes.md §一 与 overview.md §八"已用 repo"表重复

- **位置**：
  - deep-discussion-notes.md §一（第 8-18 行）：ECC/superpowers/OpenSpec/mattpocock_skills 四个已用 repo 特征表
  - overview.md §八（第 205-213 行）：同样的四个已用 repo 特征表
- **现象**：两表内容等价，仅排版略异。
- **影响**：与 P2-01 同类，但范围更小（仅四行表）。属同一重复问题的子集。
- **建议**：随 P2-01 一并处理——overview.md §八整体精简或指向 deep-discussion-notes.md。
- **置信度**：高
- **优先级**：P3（随 P2-01 处理）

### P3-03 spec_and_plan_comparison.md §2.7 trellis "Plan 生成"小节措辞与 design §0.7 原则 7 概念重叠但未互引

- **位置**：spec_and_plan_comparison.md 第 364-370 行（trellis Plan 生成："Plan 不是文档，是运行时注入 + hook 驱动的状态机"）
- **现象**：trellis 的"bash 先算状态，LLM 再决策"（overview.md 第 109 行、deep-discussion-notes.md 第 109 行均提及）恰是 design §0 原则 7"不变核心：bash 先算状态，LLM 再决策"的直接同源。三份 vendor 文档提到此模式时未点明 omni_powers 已采纳同款思路。
- **影响**：低。作为参考资料，读者无法从 vendor 文档反向建立"omni_powers 哪些设计受谁启发"的映射。属可读性优化。
- **建议**：overview.md §六"对 omni_powers 的关键启示"表新增一行"bash 先算状态"（参考 gstack/trellis），标注"已采纳——design §0 原则 7"。或不动（vendor 文档不必承担 design 溯源）。
- **置信度**：中
- **优先级**：P3（可选增强）

---

## 三、不应改动的部分（审阅确认）

- **overview.md §一横向对比表 / §二类型总览 / §三按维度归类 / §四核心差异化技术**：分类清晰、维度自洽，作为参考资料质量高，不动。
- **deep-discussion-notes.md §二-四、§七-九 各 repo 详解**：作为唯一详解独占者，内容详实，不动。
- **spec_and_plan_comparison.md §二各 repo 详解 / §三 SPEC 格式对比 / §四 Plan 格式对比 / §五关键差异总结**：对比维度清晰、模板引用准确，不动。
- **spec_and_plan_comparison.md 第 464 行注释**（"以下是 mattpocock_skills 的 vendor 术语，不是 omni_powers 当前入口；omni_powers 当前需求入口为 /opintake"）：这是文档自身已识别漂移并主动校准的良好范式，建议作为 P2-02 修复时的参考样板，本身不动。

---

## 四、与 design.md 冲突检查

逐项核对，**未发现硬冲突**。三份 vendor 文档均为背景调研，不定义 omni_powers 的任何契约/流程/角色，design.md 正文也零引用 vendor 具体内容。需要关注的只有 P2-02 列出的"建议栏表述与现行 design 已落地状态漂移"——属表述层过时，非契约冲突。

特别确认：
- design §0.7"hook 对 subagent 失效"的诚实声明，与 deep-discussion-notes.md 第 308-311 行"trellis PreToolUse 注入不可借鉴为硬边界"结论一致，无矛盾。
- design §5 lite"零侵入"定位，与 overview.md §六"对 omni_powers 的建议"未提"应加 hook 注入"一致，无诱导偏离。

---

## 五、归档 / 去重 / 索引建议汇总

| 建议 | 目标 | 优先级 |
|---|---|---|
| 删除 overview.md 第 5 行悬空指引，或恢复 vendors_repo/ 目录 | P1-01 | P1 |
| overview.md §五压缩为指向 deep-discussion-notes.md 的链接，§八三个共同点同步处理 | P2-01 | P2 |
| overview.md §六"建议"表加"当前状态"列，或整节加"2026-07-02 调研时建议"声明 | P2-02 | P2 |
| overview.md §五 spec-kit vs OpenSpec 对比表补 plan 维度 | P2-03 | P2 |
| overview.md §一表格统一时效声明 | P3-01 | P3 |
| overview.md §八四个已用 repo 表随 P2-01 处理 | P3-02 | P3 |
| overview.md §六补"bash 先算状态"行（可选） | P3-03 | P3 |

---

## 六、审阅方法说明

- 全量阅读三份目标文档 + design.md 全文。
- 物理验证：`ls docs/vendors_repo/`、`ls docs/`、grep 核对 design/CLAUDE.md/RULES.md 对 vendor 的引用。
- 内部一致性：cross-doc 表格数据对照（overview §五 vs deep-discussion §二-四；overview §八 vs deep-discussion §十；spec_and_plan §2.2 vs overview §一/§五）。
- 未调用其他 Agent。
- 源文件只读，仅写本报告。
