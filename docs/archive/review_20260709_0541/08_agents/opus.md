## 当前模型判断依据
根据主会话环境提示，当前运行模型由 `default_opus[1m]` (Claude 3 Opus) 驱动。在 `/home/karon/.claude/settings.json` 中配置的顶层 `model=haiku` 已通过用户多模型审阅授权重写，指定使用 Opus 模型进行只读审阅。

## 审阅范围
本次审阅针对以下 4 个 Agent 提示词文件：
- `/home/karon/karson_ubuntu/omni_powers/agents/op-closer.md`
- `/home/karon/karson_ubuntu/omni_powers/agents/op-evaluator.md`
- `/home/karon/karson_ubuntu/omni_powers/agents/op-implementer.md`
- `/home/karon/karson_ubuntu/omni_powers/agents/op-reviewer.md`

## 高优先级问题（CRITICAL / HIGH）

### 问题 1：`op-implementer.md` 存在严重指令冲突，诱导修改只读/保护文件 `review.md`
- **位置**：`op-implementer.md` 第 113 行（收到 review 反馈处理步骤 3）。
- **现象**：提示词指出 `不合理 → 在 review.md 追加"此项不改因为 Y"，附技术理由`。
- **影响**：这与该文件自身第 22/54/64 行以及设计文档（§1.1/§2.4/§3.4）中“review.md 单写者为 leader，implementer 绝不能写 review.md”的硬性规定直接冲突。若 implementer 尝试修改 `review.md`，将会因越权修改被 `merge gate` 机械拦截，导致流程彻底阻塞。
- **建议**：修改为 `不合理 → 在 tasks/{TID}/report.md 的 Round N 追加"此项不改因为 Y"，附技术理由`。
- **置信度**：100%
- **优先级**：CRITICAL

### 问题 2：`op-implementer.md` 缺少对 `type: fix` 任务在 `normal` 模式下的回归测试/Patch 编写指引
- **位置**：`op-implementer.md` 的 `normal` 模式流程（第 37-45 行）。
- **现象**：流程中只指导了“写映射验收标准的结构层单测”，未提及当 spec 类型为 `fix` 时，implementer 需编写行为层回归测试并生成 patch 附在 report 中的规则。
- **影响**：Implementer 会漏掉 fix 任务的关键交付物（`BUG-*` 回归测试 patch），仅编写结构层单测，导致 leader 无法在主分支验证“先红后绿”，破坏了整个修复流程的可信度。
- **建议**：在 `normal` 模式中，增加根据 `type` 分支的指引：如果任务类型为 `fix`，指导 implementer 编写必然失败的行为层回归测试（符合 `BUG-{id}_*.spec` 格式），并将该测试的 patch 附在 `report.md` 中。
- **置信度**：100%
- **优先级**：HIGH

### 问题 3：`op-closer.md` 的工作目录硬校验缺乏 `<work_dir>` 参数来源
- **位置**：`op-closer.md` 第 11 行及输入格式（第 117-123 行）。
- **现象**：收到任务第一件事是“硬校验：pwd 输出必须等于 leader 指定的工作目录”。但下文的 dispatch prompt 输入格式中，并未包含工作目录（`<work_dir>`）参数。
- **影响**：Agent 无法得知“leader 指定的工作目录”具体是什么，硬校验将无法执行或引发误判，导致 closer 直接中断并回报“路径错误”。
- **建议**：在 `op-closer.md` 的输入格式中增加 `work_dir` 字段（例如 `工作目录：{work_dir}`），或者在硬校验提示中明确说明如何获取该路径。
- **置信度**：100%
- **优先级**：HIGH

### 问题 4：三执行 Agent 未实现设计文档要求的“前置探活”根目录校验，脚本 resolver 健壮性不足
- **位置**：`op-implementer.md`、`op-evaluator.md`、`op-reviewer.md` 的文件顶部环境检查。
- **现象**：当前实现为：
  ```bash
  OP_ROOT="${OP_SCRIPT_ROOT:-$OP_HOME}"
  op_script() { ls "$OP_ROOT/scripts/$1" "$OP_ROOT/skills/oprun/scripts/$1" 2>/dev/null | head -1; }
  bash "$(op_script op_check_env.sh)"
  ```
  未校验 `$OP_ROOT` 目录是否存在，也未校验 `op_script` 是否定位到脚本，就直接跑 `bash`。
- **影响**：违反设计文档 §5.4 要求的“前置探活：三执行 agent 在 resolver 后立即校验根目录存在”。若环境未配置好，会导致 `bash ""` 执行报错或 `ls` 报错，且错误定位极其困难。
- **建议**：按照设计文档 §5.4 提供的 shell 函数重构 Agent 的 `op_script` 定位逻辑，并在调用前加入 `[ -d "$OP_ROOT" ]` 校验，若不存在或找不到脚本则输出明确 FATAL 并退出。
- **置信度**：100%
- **优先级**：HIGH

## 中低优先级问题（MEDIUM / LOW）

### 问题 5：`op-evaluator.md` 存在报告文件名冲突，混淆 `acceptance_report.md` 和 `eval.md`
- **位置**：`op-evaluator.md` 第 117 行与输出格式（第 149 行）。
- **现象**：第 117 行指出“范围外发现 → 写入 `acceptance/{TID}/eval.md` 范围外发现段（草稿）”，但输出格式段（第 149 行）明确要求输出文件是 `acceptance_report.md`，且内含 `## 范围外发现` 章节。
- **影响**：会导致 Evaluator 把范围外发现单独写到 `eval.md`，与主报告 `acceptance_report.md` 分离，使得 Closer 在收口时可能遗漏或读取失败。
- **建议**：统一为 `acceptance_report.md`，将第 117 行修改为：“范围外发现 → 写入 `acceptance/{TID}/acceptance_report.md` 的范围外发现段（草稿）”。
- **置信度**：100%
- **优先级**：MEDIUM

### 问题 6：`op-evaluator.md` 缺少工作目录的“收到任务第一件事”硬校验
- **位置**：`op-evaluator.md`。
- **现象**：与其他三个角色不同，`op-evaluator.md` 缺失了“收到任务第一件事：`cd <work_dir> && pwd` 并做硬校验”的步骤。
- **影响**：虽然 evaluator 在独立 worktree 中运行，但如果工作目录切换失败或路径错误，仍会产生污染。缺少此校验降低了整体一致性和鲁棒性。
- **建议**：补齐工作目录硬校验步骤，与 `op-implementer` 保持一致。
- **置信度**：95%
- **优先级**：MEDIUM

### 问题 7：`op-closer.md` 追加 decisions.md 的头部格式与设计文档微小不一致
- **位置**：`op-closer.md` 第 44 行。
- **现象**：Closer 中定义追加头部为 `## [red-attribution | {TID} | Round-{N} | {ISO 时间}] {title}`。而设计文档 §2.6 要求为 `[来源标记 | TID | Round-N | 日期]`。
- **影响**：细微格式不一致，由于 decisions.md 是幂等去重的，格式微调可能导致脚本分析去重时出现偏差。
- **建议**：建议统一为设计文档要求的格式。
- **置信度**：90%
- **优先级**：LOW

### 问题 8：`op-reviewer.md` 对输出文件的说明可能诱导 Heavy 模式下的 write 行为
- **位置**：`op-reviewer.md` 第 19 行。
- **现象**：明确指出“输出文件：`docs/omni_powers/op_execution/tasks/{TID}/review.md`”，这与 Heavy 模式下 Reviewer 没有 checkout、只输出 text 供 leader 落盘的机制冲突。
- **影响**：可能使 Agent 困惑，在 Heavy 模式下尝试使用 Write 工具写入该路径而报错。
- **建议**：在该条说明后补充：“（注：Heavy 模式下你只需在最终回复中输出此 Markdown 文本，由 leader 负责写入；Lite 模式下你才亲自写入此文件）”。
- **置信度**：95%
- **优先级**：LOW

## 改进建议
1. **统一 `op_script()` Resolver 的实现**：
   在 `op-implementer.md`、`op-evaluator.md` 和 `op-reviewer.md` 中，引入设计文档中给出的 `op_script()` 实现，该实现具备完整的路径循环检索和未找到时的 FATAL 退出机制，避免 `ls | head -1` 的简单实现带来的潜在 Flaky 表现。
2. **在 `op-reviewer.md` 的输入格式中增加 `work_dir` 指引**：
   对于 Lite 模式，Reviewer 需要 cd 项目根目录。输入格式中未明确体现项目根路径，应在 `op-reviewer.md` 尾部的输入格式中加入 `项目根目录：{work_dir}` 标识。
3. **补充 `BUG-*` patch 的具体格式范例**：
   在 `op-implementer.md` 中，可以简短给出一个 regression test patch 的写法样例，确保 implementer 能够生成标准的、可供 leader 直接应用的 patch 文本。

## 不确定项 / 可能误报
- **关于 `op-closer.md` 运行前检查环境**：
  `op-closer.md` 直接使用了 `bash "$OP_HOME/scripts/op_check_env.sh"`。虽然 closer 是 heavy 独有角色，理论上 `$OP_HOME` 一定存在，但是如果在某些特殊宿主环境下，`$OP_HOME` 环境变量未被正确继承，此命令可能直接失败。建议在 closer 中也加入对 `$OP_HOME` 变量是否存在且为目录的简单前置校验，或同样采用 Resolver 结构。
