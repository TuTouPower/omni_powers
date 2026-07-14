# Omni Powers 历史归档文档只读审阅报告 (Opus 视角)

## 1. 当前模型判断依据
- 默认档位配置：haiku=default_haiku / sonnet=default_sonnet / opus=default_opus。
- 环境变量：env.ANTHROPIC_MODEL 设为 default_model。
- 主会话运行状态：当前会话由 default_opus 模型驱动，本审阅完全基于 Opus 视角的深度分析得出。

## 2. 审阅范围
审阅对象为项目 docs/archive/ 目录下的全部历史归档文件：
- docs/archive/README.md
- docs/archive/agent_protocol_old.md
- docs/archive/agent_team_vs_subagent.md
- docs/archive/omni_powers_lite_design.md
- docs/archive/op_findings.md

以 docs/omni_powers_design.md 和 RULES.md 为现行设计基准，审查归档文件是否正确标注、是否被当前入口引用，以及是否具有误导性冲突。

## 3. 高优先级问题 (CRITICAL/HIGH)

### 问题 1: docs/archive/agent_team_vs_subagent.md 缺少历史废弃标注且结论与现行架构冲突
- **位置**：docs/archive/agent_team_vs_subagent.md 文件头部及第九节。
- **现象**：
  1. 文件头部未加注置顶的废弃或历史快照警告横幅，格式与 README.md 中其他已归档文件的描述不一致。
  2. 第九节（“结论”）中明确写有“建议：当前保持 Agent Team 方案不变”的结论。
- **影响**：
  现行系统在 D15、D20 决策后已全面采用 Sub Agent 编排。该文件由于缺少历史标识，其“保持 Agent Team 不变”的废弃结论将对人工阅读者或执行全局检索的 Agent 产生严重误导，破坏对当前全线 Sub Agent 架构的理解。
- **建议**：
  在文件头部追加置顶的历史废弃警告横幅，明确说明：“本分析完成于 2026-06-27，当时倾向于保留 Agent Team。系统后续已在 D15/D20 决策中全线迁移至 Sub Agent 编排，当前结论已废弃，最新架构设计以 docs/omni_powers_design.md 为准。”
- **置信度**：100%
- **优先级**：HIGH

## 4. 中低优先级问题 (MEDIUM/LOW)

### 问题 2: docs/archive/op_findings.md 头部历史警告强度不足
- **位置**：docs/archive/op_findings.md 文件头部。
- **现象**：
  文件头部仅标注了“2026-06-25 实验验证。记录实验结论和决策依据，最终规则见 RULES.md”，未采用统一的“⚠️ 已废弃/仅供历史参考”等强警告视觉格式。
- **影响**：
  该文件记录了大量关于 Agent Team、tmux 面板清理、config 残留等实验（实验 2 至 6）。随着系统整体淘汰 Agent Team，这些实验结论均已失去现实指导意义。警告不醒目可能导致后继开发者在维护时误用这些失效的实验结论。
- **建议**：
  将头部横幅改写为统一的强警告格式，指明其中涉及 Agent Team 及 tmux 的实验结论已随全线 Sub Agent 落地而废弃。
- **置信度**：95%
- **优先级**：MEDIUM

### 问题 3: docs/archive/agent_protocol_old.md 历史路径与状态机术语容易引发误匹配
- **位置**：docs/archive/agent_protocol_old.md 全文。
- **现象**：
  文件中频繁出现旧版术语，如 `harness_execution`、`harness_blueprint` 路径，以及中文状态机术语（“待开始”、“进行中”）。
- **影响**：
  虽然该文件头部已有清晰的废弃横幅，但由于包含与现行系统（如 `op_execution`、`op_blueprint` 及 ASCII 状态机）高度相似的概念，Agent 在使用模糊搜索或全局 `grep` 时，极易将此文件中的旧规则误认作现行规范。
- **建议**：
  在系统各 Agent（如 op-implementer, op-reviewer 等）的系统提示词中，增加硬性过滤规则，显式禁止读取或匹配 docs/archive/ 目录下的任何内容；或在归档文件内部的关键术语上添加明显的“废弃”前缀以物理阻断检索匹配。
- **置信度**：90%
- **优先级**：LOW

## 5. 改进建议
1. **统一归档横幅标准**：在 docs/archive/README.md 中明确建立一套归档文件置顶横幅的标准模板。任何移入 docs/archive/ 的文档，必须在头部包含该模板，以规范化视觉呈现。
2. **审查老旧引用链**：确认 docs/op_decisions.md 中第 172 行对 `docs/archive/agent_team_vs_subagent.md` 第十二节的引用仅作“历史溯源”，并在 op_decisions.md 引用处旁边备注“该文件已废弃”以防读者误入。

## 6. 不确定项
- 实验 7（model 参数显式传递）得出的“spawn 时必须显式传 model 参数，定义文件中的 model 字段不被 spawn 读取”的结论。在当前 Sub Agent 派发机制下，是否仍存在该限制，因缺少现行 Sub Agent 派发器的底层测试，无法单从文档判定。需在后续 P1/P2 的环境中核实。
