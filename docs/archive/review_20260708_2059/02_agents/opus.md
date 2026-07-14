## 当前模型判断依据
- 可观测来源：主会话环境提示当前正由 `default_opus[1m]` 提供支持，且 `~/.claude/settings.json` 中配置继承该主会话档位。
- 结论：当前审阅基于 Opus 模型视角进行，报告中未写入任何敏感信息（Secret）。

## 审阅范围
本次审阅针对以下 omni_powers 角色定义文件，以 `docs/omni_powers_design.md` 为核心规格契约进行比对：
- `/home/karon/karson_ubuntu/omni_powers/agents/op-closer.md`
- `/home/karon/karson_ubuntu/omni_powers/agents/op-evaluator.md`
- `/home/karon/karson_ubuntu/omni_powers/agents/op-implementer.md`
- `/home/karon/karson_ubuntu/omni_powers/agents/op-reviewer.md`

---

## 高优先级问题（CRITICAL / HIGH）

### 1. implementer 修改 review.md 的写入越权冲突
- **位置**：`agents/op-implementer.md` 核心规则 4、FAIL 轮工作流步骤 5、文件约定表；以及 `agents/op-reviewer.md` 问题处理逻辑。
- **现象**：`op-implementer.md` 要求开发角色在 FAIL 轮修改 `review.md` 的 Fix-N 段以记录修复说明；然而 `omni_powers_design.md`（§2.4, §3.4）明确规定 `review.md` 为单写者（仅由 leader 在主分支落盘），task 分支对 review.md 的任何修改均被 merge gate 白名单拦截（REJECT）。同时，设计明确指出：**FAIL 轮的 Fix-N 修复说明也追加到 report.md，不进 review.md**。
- **影响**：在 heavy 模式下，implementer 会因为 worktree 排除流程目录而无法找到 `review.md`，或者即使强行修改，其 task 分支的 merge 请求也会被 merge gate 拒绝，导致流水线死锁。
- **建议**：
  1. 彻底移除 `op-implementer.md` 中修改 `review.md` 的指示，将其 FAIL 轮修复说明（Fix-N）统一规范为追加至 `report.md`。
  2. 在 `op-reviewer.md` 的 Process 部分补充说明，重审时应在 `report.md` 中阅读开发者的 Fix-N 修复说明。
- **置信度**：100%
- **优先级**：CRITICAL

### 2. evaluator 范围外发现转 issue 的职责链条断裂
- **位置**：`agents/op-closer.md` 步骤 1 和 2；`agents/op-evaluator.md` 步骤 1.6 与铁律 3。
- **现象**：`op-evaluator.md` 明确规定自己对 `issues/` 目录没有直写权，验收发现的范围外问题应写入验收报告 `acceptance_report.md` 的范围外发现段（作为草稿，由 leader/closer 在收口时落盘并赋 P 级）。然而，负责收口的 `op-closer.md` 仅规定了读取 `review.md` 暂存项并将其写入 `issues/`，对于 `acceptance_report.md` 里的范围外发现只字未提。
- **影响**：evaluator 在真机验收中发现的范围外 Bug 或可用性问题，在 closer 收尾归档时会被静默遗漏，无法成功登记为项目 issue 资产，破坏了 "一切现在不修的问题必须有档案"（design §3.2）的闭环。
- **建议**：
  1. 修改 `op-closer.md` 步骤 1，补充读取并解析 `op_execution/acceptance/{TID}/acceptance_report.md` 的范围外发现段。
  2. 修改 `op-closer.md` 步骤 2，明确将 reviewer 暂存项和 evaluator 范围外发现共同转化为 `op_execution/issues/` 下的 issue 文件。
  3. 修改 `op-evaluator.md` 步骤 1.6 的字面表述 "范围外发现 -> 落 issues/"，改为 "写入验收报告的范围外发现段（草稿）"。
- **置信度**：95%
- **优先级**：HIGH

---

## 中低优先级问题（MEDIUM / LOW）

### 1. decisions.md 追加块头部机械标识不一致
- **位置**：`agents/op-closer.md` 步骤 3 模板。
- **现象**：`op-closer.md` 给出的 decisions.md 追加模板头部为 `## {TID} {title}（{ISO 时间}）[red-attribution]`。而 `omni_powers_design.md` §2.6 规定，为支持中断、重试等恢复场景的去重判重，每个 decisions.md 追加块头部必须带高精度机械标识 `[来源标记 | TID | Round-N | 日期]`。
- **影响**：缺少 `Round-N` 及特定结构可能导致判重逻辑失效，在执行中断恢复时产生重复追加。
- **建议**：修改 `op-closer.md` 中的 decisions.md 追加格式模板，使其包含精确的 `[red-attribution | {TID} | Round-{N} | {ISO 时间}]` 机械标识。
- **置信度**：90%
- **优先级**：MEDIUM

### 2. closer 提案模板缺失 domain.md 和 conventions.md 结构
- **位置**：`agents/op-closer.md` 步骤 4 模板。
- **现象**：在产出「blueprint 更新提案」的模板中，仅显式列出了 `specs/{feature}.md`、`architecture.md` 以及 `baselines`，但忽略了 `domain.md` 和 `conventions.md`。
- **影响**：在实际工作中，agent 可能会遗漏这些同样属于 `op_blueprint/` 的文档修改建议。
- **建议**：在 `blueprint_update.md` 的模板中补充 `## domain.md` 和 `## conventions.md` 的占位结构，并指示 "无改动写'无更新'"。
- **置信度**：90%
- **优先级**：LOW

### 3. evaluator 启动命令对源码依赖的隐患
- **位置**：`agents/op-evaluator.md` 步骤 1.3。
- **现象**：要求 evaluator 按 spec 可测性契约中的 "启动方式" 启动应用。然而 spec 写入的命令（如 `npm start`）通常以开发模式运行在源码目录，而 heavy 模式下的 evaluator worktree 根本没有 `src/**` 源码，只有构建产物。
- **影响**：evaluator 直接运行面向源码的命令会失败，导致验收中断。
- **建议**：在 `op-evaluator.md` 中增加提示：在隔离环境下启动应用时，应优先采用 brief 中组装的、面向构建产物的启动命令（或直接运行构建好的二进制/服务包），而非开发时源码命令。
- **置信度**：85%
- **优先级**：LOW

---

## 改进建议

### 1. 规范 P 级与 tags 赋值指南
- 在 `op-closer.md` 的暂存项转 issue 部分，明确指出 `severity`（P 级）的赋级规范（P1-P3），并再次申明 `P0` 不得由 closer 单方面赋予，必须保留给人类或 optriage 复核确认（对齐 design §3.2）。

### 2. 统一前置探活的 FATAL 退出
- `op-implementer.md`、`op-reviewer.md`、`op-evaluator.md` 三者顶部都增加了基于 `OP_SCRIPT_ROOT` 或 `OP_HOME` 的探活脚本。建议规范在探活失败（如目录不存在、脚本解析空）时，统一显式输出带有 `FATAL:` 标记的错误文本并立即 `exit 1`，防止逻辑继续向下漂移产生次生异常。

---

## 不确定项 / 可能误报

### 1. Lite 模式下的 review.md 修改限制
- **分析**：虽然 Lite 模式下无 merge gate 且在主分支直改，物理上 implementer 能改写 `review.md`。但为了让 implementer 这一核心 agent 在 heavy 和 lite 下复用相同的执行内核与文件契约（即同一份 `op-implementer.md` 提示词），应当统一要求其将修复说明写在 `report.md` 中，所以判定其与 design 冲突并非误报。
