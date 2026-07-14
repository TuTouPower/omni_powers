# haiku 审阅报告：02_project_docs

## 当前模型判断依据

- `/home/karon/.claude/settings.json` 顶层 `model` = `haiku`；`env.ANTHROPIC_MODEL` = `default_model`；`env.ANTHROPIC_DEFAULT_HAIKU_MODEL` = `default_haiku[1m]`。
- 主会话环境提示显示由 `default_model` 驱动，该字段对应配置默认 `haiku`。
- 不能读取运行时内部状态，current 路继承主会话判断。
- 用户显式授权调用 haiku 做 multi-model-review。

## 审阅范围

- `/home/karon/karson_ubuntu/omni_powers/docs/op_decisions.md`（决策记录，449 行）
- `/home/karon/karson_ubuntu/omni_powers/docs/op_first_run.md`（首跑计划，121 行）
- `/home/karon/karson_ubuntu/omni_powers/docs/op_install.md`（历史安装方案，已废弃，381 行）

已读必读上下文 `docs/omni_powers_design.md`（合并版设计档案，910 行）。

---

## 高优先级问题（CRITICAL / HIGH）

### H1 [HIGH] op_first_run.md 引用已删除的设计章节与旧编号体系

- **位置**：`op_first_run.md` 全文（第 6、66、118、119 行等）
- **现象**：
  - 第 6 行「结论沉淀进 op_decisions.md」、第 119 行「结论并入 op_decisions.md（D20）」——但 D20 在 `op_decisions.md` 第 285 行已标注为「合并 heavy/lite 两份设计文档」，与首跑结论无关；首跑结论无对应 D 编号落地位置。
  - 第 66 行「per-task 验收（Stage 3 循环内）」、第 67 行「闸门 C」——当前 design.md 已将验收改为 merge 前验（§2.4 步骤 4，D27 D-1=A），闸门 C 改为批量化事后报告（§2.6，D27 D-3=A），首跑文档仍用旧「Stage 3 循环内验收」「闸门 C 呈报四样」表述。
  - 第 118 行「design §8.1 调教循环启动」——D25 已删钓鱼审计/刻薄化调教循环，§8.1（现 §2.5 防放水机制）三层防放水不含调教循环。
- **影响**：首跑计划是「一次性执行计划」，若真按此跑会走旧流程（验收在 merge 后、闸门 C per-task 审批），与当前 design 矛盾，导致首跑验证的不是当前系统。
- **建议**：要么按当前 design 重写首跑流程（验收 merge 前、闸门 C 改结束报告、删调教循环引用），要么直接归档（文档定位第 6 行已说「完成后移 docs/archive/」）。
- **置信度**：高（design.md 明确）
- **优先级**：HIGH

### H2 [HIGH] op_first_run.md 模型档位与 design 推荐档位不一致

- **位置**：`op_first_run.md` 第 23-31 行
- **现象**：首跑文档设 `OP_REVIEWER_MODEL=sonnet`，但 design.md §2 模型分配表（第 210 行）推荐 reviewer 用 Opus（「读 spec+diff+report 做双裁决，只读不写……强审弱错开同档盲区」）。
- **影响**：首跑验证用 sonnet 跑 reviewer，若出现裁决质量问题，无法判断是系统设计问题还是模型档位不够——验证基准偏离设计推荐。
- **建议**：首跑至少 reviewer 用 design 推荐档位，或在文档注明「首跑为省成本降档，非推荐配置」。
- **置信度**：高
- **优先级**：HIGH

### H3 [HIGH] op_decisions.md D6 标题与正文严重矛盾

- **位置**：`op_decisions.md` 第 59 行（D6 标题）
- **现象**：标题写「一个 task 一次 commit，hash 回填延迟（2026-06-25）— ⚠️ 已被 D12 取代」，但正文第 61 行「收口只有一次主 commit……延迟到下一个 task 收口时一并回填提交」描述的是「一次主 commit + 延迟回填」。
- D12（第 138 行）标题是「一个 task **两个** commit」，正文明确「代码 commit + 控制平面 commit」。
- D16（第 174 行）又取消了两 commit 分离，「一个 task 一个 commit（不是两个）」。
- **影响**：D6 标题标注「已被 D12 取代」，但 D12 的「两 commit」又被 D16 取消回「一 commit」。取代链断裂：D6 → D12（两 commit）→ D16（一 commit）。读者沿取代链走会混乱：D6 的「一 commit」实际被 D16 恢复，而非被 D12 取代。
- **建议**：D6 标题改为「已被 D16 取代」（最终态是一 commit），或补注取代链完整路径 D6→D12→D16。
- **置信度**：高
- **优先级**：HIGH

---

## 中低优先级问题（MEDIUM / LOW）

### M1 [MEDIUM] op_decisions.md 编号跳号 D11 缺失

- **位置**：`op_decisions.md` 第 83 行（D10）→ 第 103 行（D13）
- **现象**：D10 之后直接到 D13，无 D11、D12 在 D13 之后才出现（第 138 行 D12）。时间序乱：D10(06-26) → D13(06-26) → D14(06-26) → D12(06-26) → D15(06-27)。
- **影响**：D11 完全缺失，读者会疑惑是否漏记决策。D12/D13/D14 时间相同但编号倒序，阅读困难。
- **建议**：确认 D11 是否真实存在但未记录（补「已撤销」占位），或注明编号跳号原因。
- **置信度**：高（客观事实）
- **优先级**：MEDIUM

### M2 [MEDIUM] op_decisions.md 早期决策全部标注「已被 D15 取代」但未归档

- **位置**：`op_decisions.md` D1/D4/D5/D10（第 7、29、44、84 行）
- **现象**：D1/D4/D5（Agent Team vs Workflow/Sub Agent 演进）均已标「⚠️ 已被 D15 取代」，但仍在正文占用篇幅。D10（标记文件机制）同样被 D15 取代。
- **影响**：决策记录本意是保留历史，但 4 条被取代决策占据前 100 行，读者要翻到 D15+ 才看到当前有效决策。历史价值与可读性失衡。
- **建议**：可考虑将被取代决策折叠或移至附录段，正文保留取代标记 + 一句话摘要 + 指向取代者。或至少在文档头部加「当前有效决策从 D17 起」导航。
- **置信度**：中（属于可读性优化，非错误）
- **优先级**：MEDIUM

### M3 [MEDIUM] op_install.md 废弃文档冗长保留，与新安装模型冲突点多

- **位置**：`op_install.md` 全文
- **现象**：文档头部已声明废弃（第 1-7 行），但正文 380 行仍完整描述 plugin 模式（`$CLAUDE_PLUGIN_ROOT`/`claude plugins install`/`opstart`/`op-coder` 等旧称旧机制）。
- 与当前安装模型（install.sh + `$OP_HOME` + skill/agent 装 `~/.claude/`）完全不同。
- CLAUDE.md「安装」段与 design §4.1 是当前真相源。
- **影响**：文档自身已声明「勿据此实施」，风险可控。但作为 docs/ 下的文件仍可被搜索/引用，废弃文档与新文档并存增加混淆面。
- **建议**：移至 `docs/archive/`（CLAUDE.md 目录结构未列此文件在 archive，但第 5 行已自称「历史归档保留」），与声明一致。
- **置信度**：高
- **优先级**：MEDIUM

### M4 [MEDIUM] op_first_run.md 第 66 行验收位置与 design 当前态不符

- **位置**：`op_first_run.md` 第 66 行
- **现象**：表格「per-task 验收（Stage 3 循环内）」——当前 design 验收在 merge 前（§2.4 步骤 4，D27 D-1=A）。属 H1 的子项，单独列出因验收时序是首跑核心验证点。
- **影响**：首跑若按「Stage 3 循环内验收」跑，验证的是旧时序。
- **建议**：见 H1。
- **置信度**：高
- **优先级**：MEDIUM（因属 H1 子项，降一级）

### L1 [LOW] op_decisions.md D17 引用 vendors 路径未确认是否存在

- **位置**：`op_decisions.md` 第 198、217 行
- **现象**：D17 依据 `vendors/omni_powers_harness_design/omni_powers_harness_v5.md`，第 217 行「详见」同路径。审阅范围排除 vendors/，无法确认该文件是否存在或内容是否对齐。
- **影响**：若 vendors 文件已变动，D17 依据追溯链可能断裂。
- **建议**：审阅范围外，标记为不确定项（见「不确定项」段）。
- **置信度**：低（未核实）
- **优先级**：LOW

### L2 [LOW] op_first_run.md 第 18-21 行 CUA 安装措辞与全局约定可能冲突

- **位置**：`op_first_run.md` 第 18 行
- **现象**：「无则按 CUA 官方文档安装；PowerShell 管道脚本需先审阅 URL 内容，确认来源可信后再执行」——措辞谨慎，但 CLAUDE.md 全局约定要求「所有对公网开放的密钥/token 等必须由用户提供」，CUA 安装涉及的外部脚本属安全敏感操作。
- **影响**：低，文档已提示审阅 URL，属 advisory。
- **建议**：无需改，记录已注意到安全考量。
- **置信度**：高
- **优先级**：LOW

### L3 [LOW] op_decisions.md 第 264-267 行引用「四模型审阅记录」未纳入仓库

- **位置**：`op_decisions.md` 第 241、263 行（D18）
- **现象**：D18 触发与审阅意见处理均引用「四模型审阅记录（临时审阅材料，未纳入仓库）」。
- **影响**：决策依据无法追溯，但 D18 核心依据是 GitHub issue（已附链接），可独立核实。临时材料不入库是合理选择。
- **建议**：无需改，属文档策略选择。
- **置信度**：高
- **优先级**：LOW

### L4 [LOW] op_install.md 第 37 行 RULES.md 行数描述过时

- **位置**：`op_install.md` 第 37、39 行
- **现象**：「RULES.md 约 200 行……多一次 Bash 调用换每会话省 200 行」。当前 RULES.md 实际行数未知（审阅范围外），但设计演进后 RULES.md 内容大幅扩展，200 行估计大概率过时。
- **影响**：低，废弃文档内部数字不准。
- **建议**：无需改（废弃文档）。
- **置信度**：中
- **优先级**：LOW

---

## 改进建议

1. **op_first_run.md 决策**（H1/M4）：首跑文档与当前 design 差距大（验收时序、闸门 C、调教循环、D 编号），建议二选一——要么按当前 design 全面重写后跑，要么直接归档（若首跑已完成或计划变更）。

2. **op_decisions.md 取代链清理**（H3/M1/M2）：
   - D6 取代标注修正（D6→D12→D16，最终一 commit）。
   - 补 D11 占位或注明跳号。
   - 考虑早期被取代决策（D1/D4/D5/D10）折叠或移附录，正文头部加「当前有效决策从 D17 起」。

3. **op_install.md 归档**（M3）：移 `docs/archive/` 与文档自身声明（第 5 行「历史归档保留」）一致，减少 docs/ 下新旧并存混淆面。

4. **版本一致性机制**：三个文件均不同程度滞后于 design.md 当前态。建议建立机制——design 重大修订（如 D20/D24/D25/D26/D27）同步检查 docs/ 下非 archive 文档是否受影响，或定期做一次 docs↔design 一致性扫描。

---

## 不确定项 / 可能误报

1. **D17 vendors 路径**（L1）：审阅范围排除 vendors/，未核实 `vendors/omni_powers_harness_design/omni_powers_harness_v5.md` 是否存在及内容。若文件已删除，D17 追溯链断裂；若存在，无问题。

2. **op_first_run.md 是否已执行**：文档定位「一次性执行计划」，若首跑已完成，文档本应已移 archive（第 6 行）。留在 docs/ 可能意味着（a）未执行、（b）执行了未归档、（c）计划废弃未清理。三种情况对应不同的 H1 严重度——若（b/c）则 H1 影响降低。未与用户确认，按最坏情况（a）评级。

3. **D11 真实性**（M1）：D11 可能是真实存在但未记录的决策（用户口头裁定未落盘），也可能是纯编号跳号。未与用户确认，按「缺失」处理。

4. **RULES.md 行数**（L4）：未读 RULES.md，200 行估计是否过时未核实。
