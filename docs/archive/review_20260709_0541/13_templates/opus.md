## 当前模型判断依据
- 根据主会话环境提示，当前由 `default_opus[1m]` 驱动，符合 Opus 视角。

## 审阅范围
- docs_template/omni_powers/ 下全部 18 个模板文件（含 README.md, index.md, op_blueprint/*, op_execution/*, op_record/*），路径相对 `/home/karon/karson_ubuntu/omni_powers/`。

## 高优先级问题（CRITICAL / HIGH）
1. **`op_execution/issues/{TID}_quality.md` 模板与标准 issue 模式存在字段冲突**
   - **位置**: `docs_template/omni_powers/op_execution/issues/{TID}_quality.md`
   - **现象**: 该模板在 Frontmatter 中使用了 `issue_id` 而不是 `id`，缺失了 `title`, `blocks_merge`, `converted_to` 等字段，并且包含了非标准的 `task` 字段。
   - **影响**: 导致统一解析、分诊或汇总 issue 的脚本工具（如 optriage 或 opstatus）在读取此文件时，因字段缺失或格式不匹配而报错崩溃，无法实现结构化统一处理。
   - **建议**: 将质量阻塞 issue 的 Frontmatter 结构调整为与标准 issue `I-{YYYYMMDD}-{NN}.md` 相同的 Schema：
     ```markdown
     id: {TID}_quality
     title: {TID} 质量阻塞
     source: reviewer FAIL（{TID}）
     spec: {TID}
     severity: P0
     tags: [quality, blocker]
     status: open
     converted_to:
     blocks_merge: true
     created_at: {YYYY-MM-DD HH:mm UTC+8}
     ```
   - **置信度**: 95%
   - **优先级**: HIGH

## 中低优先级问题（MEDIUM / LOW）
1. **多个蓝图模板文件中的设计文档章节引用错误**
   - **位置**:
     - `docs_template/omni_powers/op_blueprint/prd.md`（第3行）
     - `docs_template/omni_powers/op_blueprint/architecture.md`（第3行）
     - `docs_template/omni_powers/op_blueprint/domain.md`（第3行）
     - `docs_template/omni_powers/op_blueprint/conventions.md`（第3行）
     - `docs_template/omni_powers/op_blueprint/test.md`（第3行）
     - `docs_template/omni_powers/op_blueprint/spec_index.md`（第3行）
   - **现象**: 这6个模板文件顶部声明其职责时，均引用了 `design §3.3`。
   - **影响**: 在 `omni_powers_design.md` 中，§3.3 实际上是“机械护栏”，而定义这些文档职责的“文档职责矩阵（去重边界）”在 §1.3。这会导致阅读模板的开发者或 Agent 被错误的章节引用误导。
   - **建议**: 将这 6 个文件中的 `design §3.3` 统一修正为 `design §1.3`。
   - **置信度**: 100%
   - **优先级**: MEDIUM

2. **`op_execution/tasks/{TID}/review.md` 中的设计文档引用错误**
   - **位置**: `docs_template/omni_powers/op_execution/tasks/{TID}/review.md`（第31行）
   - **现象**: 引用了 `design §7.2`。
   - **影响**: 设计文档 `omni_powers_design.md` 总共只有 5 个大章，根本没有 `§7.2`。双裁决的轮数上限和阻塞处理在 §2.4 中定义。
   - **建议**: 将 `design §7.2` 修正为 `design §2.4`。
   - **置信度**: 100%
   - **优先级**: MEDIUM

3. **`op_blueprint/test.md` 中 CUA 运行策略与设计文档冲突**
   - **位置**: `docs_template/omni_powers/op_blueprint/test.md`（第18行）
   - **现象**: CUA lane 的夜跑失败列写着 “不阻断，开 issue”。
   - **影响**: 设计文档 §2.7 明确指出 CUA 无法在无头环境的 CI 夜跑中自动运行（“cua 通道验收的 AC 无法固化为 CI 可重放测试，这类验收标准不在夜跑覆盖内”），而是留 `*.cua-manual` 标记进行人工回归。模板描述的“夜跑失败开 issue”存在事实矛盾，会给编写测试策略的开发者带来困惑。
   - **建议**: 将 CUA 栏的夜跑失败说明改为 “不适用（不参与 CI，人工回归）”。
   - **置信度**: 95%
   - **优先级**: MEDIUM

4. **`README.md` 描述与 `TID_quality.md` 实际标签不一致**
   - **位置**: `docs_template/omni_powers/README.md`
   - **现象**: 声明质量阻塞记录模板 `op_execution/issues/{TID}_quality.md` 的“技术债加 `tech-debt` 标签”。但 `{TID}_quality.md` 里的 tags 实际为 `[quality, blocker]`，没有 `tech-debt`。
   - **影响**: 导致分类标签丢失或 README 描述失准。
   - **建议**: 在 `{TID}_quality.md` 的 tags 中补上 `tech-debt`，或修正 README 的描述。
   - **置信度**: 95%
   - **优先级**: MEDIUM

5. **`op_execution/tasks_list.json` 中 `depends_on` 默认值为 null 存在 JQ 运行隐患**
   - **位置**: `docs_template/omni_powers/op_execution/tasks_list.json`（T0001, 第8行）
   - **现象**: T0001 的 `"depends_on": null`。
   - **影响**: 系统高度依赖 `jq` 脚本做确定性依赖计算。在 `jq` 中，如果对 `null` 值使用类似 `.depends_on[]` 或 `contains` 的操作，会引发运行时报错（例如 `cannot iterate over null`）。
   - **建议**: 将默认无依赖的 task 的 `"depends_on": null` 修改为 `"depends_on": []`。
   - **置信度**: 95%
   - **优先级**: MEDIUM

6. **`index.md` 出现错别字**
   - **位置**: `docs_template/omni_powers/index.md`（第32行）
   - **现象**: 将“真相源”错写为“真信源”（“唯一 task 真信源”）。
   - **影响**: 文字不够严谨。
   - **建议**: 改为“唯一 task 真相源”。
   - **置信度**: 100%
   - **优先级**: LOW

7. **`op_execution/leader_checkpoint.md` 中的命令路径未考虑 Lite 模式 fallback**
   - **位置**: `docs_template/omni_powers/op_execution/leader_checkpoint.md`（第4行）
   - **现象**: 提示命令写着 `bash "$OP_HOME/skills/oprun/scripts/close_check.sh" {TID}`。
   - **影响**: 在 Lite 模式下，没有 `$OP_HOME` 环境变量（仅依赖 `OP_SCRIPT_ROOT` 或直接用 oplrun 调度）。对于 Lite 项目的 leader 手动排障运行，会直接报错。
   - **建议**: 将提示修正为更通用的 fallback 变量形式，如 `bash "${OP_SCRIPT_ROOT:-$OP_HOME}/scripts/close_check.sh"`。
   - **置信度**: 90%
   - **优先级**: LOW

8. **`op_record/progress.md` 设计章节引用不准**
   - **位置**: `docs_template/omni_powers/op_record/progress.md`（第4行）
   - **现象**: 引用了 `design §3`。
   - **影响**: 在 `design.md` 中，§3 是“横切机制”，而 progress 的格式和生成规则实际上主要在 §1.3 (矩阵) 和 §2.6 (closer 流程) 提及。
   - **建议**: 将 `design §3` 改为 `design §1.3 / §2.6`。
   - **置信度**: 95%
   - **优先级**: LOW

9. **`op_execution/tasks_list.json` 中 T0003 缺少 `blocked_by` 字段的规范性**
   - **位置**: `docs_template/omni_powers/op_execution/tasks_list.json`
   - **现象**: 只有 T0003 包含 `"blocked_by": "resource"`，而 T0001/T0002 均没有这个字段。
   - **影响**: 导致 Schema 的不一致。
   - **建议**: 可以在所有 Task 模板里都保留该字段（默认为 `null`），或者在设计文档中明确说明其可选性。
   - **置信度**: 90%
   - **优先级**: LOW

## 改进建议
1. **Schema 校验器联动**：由于 `tasks_list.json` 和 `issues` 会被各种自动化 Agent（implementer, reviewer, evaluator, closer）读写，建议在工具集中引入轻量级校验（或在 conventions 中定死 Schema 约定），以规避因手动修改模板导致字段不一致引起的下游脚本崩溃。
2. **测试命令的 Needs Clarification 原则强调**：`op_blueprint/test.md` 模板中的“运行”和“分层”部分，必须严格遵循“勿臆造命令”的原则。目前模板中有多处占位符形如 `{项目实际命令/工具}`，需确保在 intake 或 init 生成时引导用户填入真实值，避免 agent 擅自脑补。

## 不确定项 / 可能误报
1. **`op_record/decisions.md` 的 `**被否方案**` 字段**
   - **讨论**: 铁律 3 提到“只留'现在是什么'：事实结论。不留被否方案”。但在 `decisions.md`（历史归档）的模板里，依然包含了 `**被否方案**：...` 这一项。
   - **理由**: 稳定规格 specs/ 和 blueprint_update.md 中不应包含过程性、被否决的方案，这是为了让生效真相源干净纯粹；但 decisions.md 属于“冻结历史 (append-only)”，记录架构探索的权衡过程，因此包含“被否方案”是符合其定位的，不属于冲突，但极易在执行时与铁律 3 产生字面上的混淆。建议在 `decisions.md` 说明中额外强调“此历史区允许保留决策过程中的被否方案，以作归档，区别于生效规格 specs/”。
