## 当前模型判断依据

- 基于可观测来源：环境提示显示当前会话由 `default_model` 驱动，`/home/karon/.claude/settings.json` 中配置顶层为 `default_model`，env 环境变量配置了三档默认模型，其中 `env.ANTHROPIC_DEFAULT_OPUS_MODEL` = `default_opus[1m]`。
- 主会话未设置 model 覆盖时直接继承，可观测上表现为 `default_model`。本报告在用户授权后以 opus 视角产出。
- settings 文件中的 secret 已在审阅时自动省略，不得包含在报告中。

## 审阅范围

以 `docs/omni_powers_design.md`（v6 合并版，包含 D24-D27 修正）为核心契约，审阅以下只读源文件（均成功读取）：
- `.gitattributes`
- `.gitignore`
- `CLAUDE.md`
- `RULES.md`
- `docs/op_decisions.md`
- `docs/op_first_run.md`
- `docs/op_install.md`
- `docs_template/omni_powers/README.md`
- `docs_template/omni_powers/index.md`
- `docs_template/omni_powers/op_blueprint/architecture.md`
- `docs_template/omni_powers/op_blueprint/baselines/baselines_index.md`
- `docs_template/omni_powers/op_blueprint/conventions.md`
- `docs_template/omni_powers/op_blueprint/domain.md`
- `docs_template/omni_powers/op_blueprint/prd.md`
- `docs_template/omni_powers/op_blueprint/spec_index.md`
- `docs_template/omni_powers/op_blueprint/specs/{feature}.md`
- `docs_template/omni_powers/op_blueprint/test.md`
- `docs_template/omni_powers/op_execution/issues/I-{YYYYMMDD}-{NN}.md`
- `docs_template/omni_powers/op_execution/issues/{TID}_quality.md`
- `docs_template/omni_powers/op_execution/leader_checkpoint.md`
- `docs_template/omni_powers/op_execution/tasks/{TID}/report.md`
- `docs_template/omni_powers/op_execution/tasks/{TID}/review.md`
- `docs_template/omni_powers/op_execution/tasks_list.json`
- `docs_template/omni_powers/op_record/decisions.md`
- `docs_template/omni_powers/op_record/progress.md`

## 高优先级问题（CRITICAL / HIGH）

### 1. RULES.md 状态机仍采用中文机读状态，且保留已被 D27 废弃的“跳过”态
- **位置**：`RULES.md:18-39`、`RULES.md:49-54`、`RULES.md:90-99`、`RULES.md:133-134`、`docs_template/omni_powers/op_execution/issues/{TID}_quality.md:20-22`
- **现象**：运行时手册使用中文 `待规划/待开始/进行中/审阅中/收口中/完成/阻塞/跳过/挂起` 作为机读 status；下游阻塞传播写成改 `跳过`；质量阻塞模板亦同步包含了下游 `跳过` 状态。
- **影响**：design §1.1 / D27 D-6 明确 `tasks_list.json.status` 机读值必须是纯 ASCII：`pending/ready/in_progress/reviewing/closing/done/suspended/blocked/obsolete`，中文仅在 opstatus 渲染层做人类友好映射。下游阻塞“不另设态（无跳过态），调度器依 depends_on 不选中（design §2.4）”。当前 RULES 依然宣称机读为中文且使用跳过态，作为运行时恢复唯一入口会直接导致脚本 jq/grep、opstatus、checkpoint 解析混乱，属于流程核心数据分裂。
- **建议**：RULES.md 中的状态机表格、查询语句示例、阻塞/下游传播规则全部改为 ASCII 机读状态字。删除“跳过”状态描述及改写规则，改为“下游保持 ready，调度器依 depends_on 未满足而不选中”。同步清理 `{TID}_quality.md` 模板中的“下游跳过”。
- **置信度**：高
- **优先级**：HIGH

### 2. CLAUDE.md 与 RULES.md 中 lite 执行时序写成“先收口/commit，再 evaluator 验收”
- **位置**：`CLAUDE.md:31-36`、`RULES.md:133-135`
- **现象**：`CLAUDE.md` 把 `/oplrun` 流程描述为“implementer → leader 自验 → reviewer → 收口 → per-task 裸评 → P0 检查 → 归档”；RULES.md 的 lite 分叉表述为“review PASS → git add workset + commit → per-task 裸评 → P0 检查 → 归档”。
- **影响**：在 v6 合并版 design §5.6 中，明确 D-1 决策为“验收前置，先验 PASS 才 commit”；即在 review PASS 后，必须先派 evaluator 裸评，FAIL 则回流修复，验收 PASS 后 leader 才能在收口时执行 `git add` 实际 diff 并 commit。入口文档 CLAUDE.md 和 RULES.md 当前的描述会导致未经验收的实现代码被提前 commit 进主分支，破坏了设计契约的核心安全时序。
- **建议**：将 CLAUDE.md 与 RULES.md 的 lite 流程重写为：“review PASS → evaluator per-task 裸评（≤3 轮，PASS 才 commit）→ leader 收口（git add 实际 diff + commit + 归档）”，P0 检查放入结束报告。
- **置信度**：高
- **优先级**：HIGH

### 3. RULES.md 的 compact 恢复步骤未按 design 先读 profile，且 lite 脚本路径仍指向旧 per-skill 副本
- **位置**：`RULES.md:8`、`RULES.md:84-103`、`RULES.md:120-140`
- **现象**：文件开头和 compact 恢复段写“读本文件 + jq 查 tasks_list.json + 读 leader_checkpoint.md”；在 lite 恢复段写 `$SCRIPTS = ~/.claude/skills/oplrun/scripts`。
- **影响**：design §5.2 明确“compact 恢复第一步先读 docs/omni_powers/profile”，以 profile 决定后面的编排和脚本寻址；且 design §5.5/D27 D-7 明确 lite 淘汰 per-skill 副本，scripts 寻址统一指向全局共享目录 `~/.claude/scripts/omni_powers/`（通过 `${OP_SCRIPT_ROOT:-$OP_HOME}` 寻址）。RULES 作为恢复入口，顺序错误或继续引导使用旧 skill scripts 目录会直接导致状态与脚本版本不一致。
- **建议**：RULES.md 开头强调第一步读 profile；compact 恢复步骤分 heavy/lite 阐述，lite 寻址指向全局共享目录（`${OP_SCRIPT_ROOT:-$OP_HOME}` / `~/.claude/scripts/omni_powers/`），淘汰 skills/oplrun/scripts 引用。
- **置信度**：高
- **优先级**：HIGH

### 4. RULES.md 环境检查与脚本调用硬编码 `$OP_HOME`
- **位置**：`RULES.md:39`、`RULES.md:64-67`、`RULES.md:88-98`、`RULES.md:110`
- **现象**：RULES 中各处状态修改、回滚、查询的脚本调用示例均硬编码为 `bash $OP_HOME/scripts/...`；跨 agent 铁律中写“入口先跑 `bash "$OP_HOME/scripts/op_check_env.sh"`”。
- **影响**：对于 lite 模式，design §5.3-§5.5 明确“零侵入”——不设置 `$OP_HOME` 环境变量（未配置 settings.json env），脚本定位完全依赖 `${OP_SCRIPT_ROOT:-$OP_HOME}` 的 fallback 注入。硬编码 `$OP_HOME` 会把 lite 项目误导向未装或配置错误的 heavy 全局路径，破坏 lite 的可用性。
- **建议**：在 RULES.md 中说明，重置/查询等脚本路径应根据 profile 进行寻址，或命令示例统一采用 fallback Resolver 的逻辑（如 heavy 用 `$OP_HOME/scripts`，lite 用 `$OP_SCRIPT_ROOT`），且在 lite 分叉明确只检查 jq/git，跳过 OP_HOME 校验。
- **置信度**：高
- **优先级**：HIGH

### 5. `tasks_list.json` 模板与 design 契约不一致
- **位置**：`docs_template/omni_powers/op_execution/tasks_list.json:4-31`
- **现象**：
  - `spec` 字段填充的是 `{TID}` 而非真正的相对路径 `specs/{TID}_{slug}.md`。
  - 含有 `type: "实现"` 字段，而 design 元数据 schema 中未设计此字段（change type 来自工作 spec 头部 YAML）。
  - `depends_on` 存在 `null` 与 `["T0001"]` 混用，且 status 中包含 blocked 未定义完整的元数据属性。
  - 缺少 `eval` 和 `eval_reason` 的完整占位，仅 T0001 包含了 `eval: "required"`。
- **影响**：此模板是 `/opintake` 拆 task 生成 tasks_list.json 的直接参照，spec 路径错误会导致 dispatch 找不到工作 spec，字段缺失/混用会导致 jq 脚本（如 op_jq.sh）在做拓扑解析和 workset 校验时崩溃或误判。
- **建议**：规范 tasks_list.json 模板，将 `spec` 改为 `"specs/T0001_xxx.md"` 格式；统一无依赖时使用空数组 `[]`（或根据脚本统一为 null，但不混用）；为所有 task 统一补齐 `eval` (可选 required/skip) 与 `eval_reason` 默认占位字段，删除不属于 schema 的中文 `type`。
- **置信度**：高
- **优先级**：HIGH

### 6. `baselines_index.md` 模板与 `test.md` 将 DOM/a11y 列为结构化硬门
- **位置**：`docs_template/omni_powers/op_blueprint/baselines/baselines_index.md:13-21`、`docs_template/omni_powers/op_blueprint/test.md:14-20`
- **现象**：baselines_index 注释写“结构化信号（DOM/a11y/stdout/API 响应体/DB 查询/进程日志）→ 进机械硬门”；test.md lane 将 CDP 结构化信号全部列入机械硬门。
- **影响**：design §2.2、§2.5 及 D7 决策已明确“DOM/a11y tree 降级为 advisory 锚点，不进机械硬门”。DOM 极易因框架升级、CSS 样式重组产生 flaky 差异，误入硬门会导致夜跑 CI 频繁假红。
- **建议**：修改模板注释与 test.md 的 lane 规定，明确“stdout/API/DB/进程/消息等结构化语义信号进硬门；DOM/a11y/视觉截图作为 advisory 锚点，不阻断夜跑与 CI”。
- **置信度**：高
- **优先级**：HIGH

### 7. `op_first_run.md` 的时序、术语与 v6 design 严重脱节
- **位置**：`docs/op_first_run.md` 全文
- **现象**：首跑计划仍写“oprun → 闸门 C → 归档”（旧 per-task 闸门 C 阻断），流程表描述为“reviewer → closer → commit → per-task 验收”；且末尾提到了已在 D25 中被完全删除的“钓鱼审计/刻薄化调教循环”。
- **影响**：虽然是非运行时文档，但作为引导开发团队跑通首例 task 的实操手册，严重的流程反序（验收本应前置到 merge 前）和过时机制会误导人工 leader 陷入错误的执行路径，制造冲突。
- **建议**：在 `docs/op_first_run.md` 头部追加醒目的“已废弃/仅归档”横幅，并指引首跑实践参考最新 `docs/omni_powers_design.md` 和 RULES.md；或者直接将文件移动到 `docs/archive/`。
- **置信度**：高
- **优先级**：HIGH

## 中低优先级问题（MEDIUM / LOW）

### 8. `CLAUDE.md` 对 lite 描述仍称“脚本自包含”
- **位置**：`CLAUDE.md:36`、`CLAUDE.md:67`
- **现象**：CLAUDE.md 写 lite 为“脚本自包含”、oplrun 为“外部，脚本自包含”。
- **影响**：与 design §5.5/D27 D-7 的“共享 scripts 目录”演进方向不一致，易误导开发人员继续往 oplrun 专属目录下塞独立脚本副本，破坏 scripts/ 全局收敛方案。
- **建议**：改为“lite 模式共享 scripts 目录，当前保留部分副本过渡”。
- **置信度**：中
- **优先级**：MEDIUM

### 9. `README.md` 模板中的 TID 命名示例过时
- **位置**：`docs_template/omni_powers/README.md:38`
- **现象**：命名约定章节写“task 目录：`{TID}` 如 `T05`”。
- **影响**：与 D27 A5 强制规定的四位宽 TID `T0001/T0002` 不一致，不统一的宽度会导致单调递增性校验在 T9 跨 T10、T99 跨 T100 时因字典序逻辑错乱。
- **建议**：改为 `{TID}` 如 `T0001`。
- **置信度**：高
- **优先级**：MEDIUM

### 10. `index.md` 导航模板未说明 lite 不支持 SessionStart 自动发现
- **位置**：`docs_template/omni_powers/index.md:3`
- **现象**：模板引言称“给 agent 看的目录页（SessionStart hook 注入其摘要）”。
- **影响**：在 lite 模式下，由于零侵入原则不改写 CLAUDE.md 与 settings.json，根本没有 SessionStart 自动注入，状态恢复靠 oplrun 启动读 profile。此表述容易使在 lite 项目下阅读的 agent 产生疑惑。
- **建议**：补全说明：“heavy 可由 SessionStart 注入摘要；lite 模式通过 oplrun 启动后读取 profile 并识别本文件”。
- **置信度**：中
- **优先级**：MEDIUM

### 11. `review.md` 模板保留 `verdict: UNKNOWN` 作为末行
- **位置**：`docs_template/omni_powers/op_execution/tasks/{TID}/review.md:34`
- **现象**：模板末行为 `verdict: UNKNOWN`，注释说 UNKNOWN 不算裁决。
- **影响**：根据 design §2.4 A1，verdict 末行是 merge gate 和运行脚本判断 PASS/FAIL 的依据。初始化为 UNKNOWN 时，如果读取脚本没有做严苛的值范围断言，一旦解析器直接读取最后一行，容易产生误判或需要额外写容错。
- **建议**：脚本应当只认 PASS/FAIL，其他值直接按未通过处理；模板中的 UNKNOWN 也可以移除，或者不以 `verdict:` 前缀写在末尾，仅当 reviewer 产出 verdict 时才由 leader 追加写入。
- **置信度**：中
- **优先级**：MEDIUM

### 12. `review.md` 模板注释中的设计文档锚点过时
- **位置**：`docs_template/omni_powers/op_execution/tasks/{TID}/review.md:31`
- **现象**：注释写“review ≤ 2 轮（design §7.2 / RULES.md）”。
- **影响**：D20 之后，设计文档全文合并重写，原有章节号已变动，review 上限移到了 design §2.4。此锚点失效会增加查证成本。
- **建议**：改为 `design §2.4 / RULES.md`。
- **置信度**：高
- **优先级**：LOW

### 13. `report.md` 模板中的测试输出提示过时
- **位置**：`docs_template/omni_powers/op_execution/tasks/{TID}/report.md:18`
- **现象**：写着“贴测试运行原始输出关键段（hook 自动跑的受影响测试结果）”。
- **影响**：在 D18 之后，subagent 无法触发 hook，自动测试结果并不存在，证据属于 implementer 自跑记录。这会误导 implementer 去寻找并不存在的 hook 运行输出。
- **建议**：改为“贴测试运行原始输出关键段（由实现者运行并收集）”。
- **置信度**：高
- **优先级**：LOW

### 14. `decisions.md` 模板缺少 design 要求的幂等来源标识与具体段落示例
- **位置**：`docs_template/omni_powers/op_record/decisions.md` 全文
- **现象**：模板只有简单的 YYYY-MM-DD - {TID}: {决策标题}，未给出幂等标识和类型示例。
- **影响**：design §2.6 明确 decisions.md 在追加时需要带 `[来源标记 | TID | Round-N | 日期]` 用作中断判重。没有占位模板，agent 生成 decisions 追加块时格式极易失控。
- **建议**：补全格式模板：`[spec-delta / red-attribution / blocked-attribution / leader-close | TID | Round-N | YYYY-MM-DD]` 占位，并给出变更段落和受影响清单模板。
- **置信度**：高
- **优先级**：MEDIUM

### 15. `progress.md` 模板信息较薄，未对齐 design 要求
- **位置**：`docs_template/omni_powers/op_record/progress.md:3-6`
- **现象**：模板格式为 `- {TID} | {feature} | {date} | 完成`。
- **影响**：design §1 目录职责写 progress.md 记录“commit 区间 + review 结论 + 验收标准覆盖”。如果模板不包含这些字段，容易被 closer 或归档脚本忽略。
- **建议**：将示例扩展为 `- {TID} | {feature} | {commit_range} | review {verdict} | eval {result} | YYYY-MM-DD` 结构。
- **置信度**：中
- **优先级**：MEDIUM

### 16. `baselines_index.md` 模板中的验收标准文本归属说明与 design D23 冲突
- **位置**：`docs_template/omni_powers/op_blueprint/baselines/baselines_index.md:3-5`
- **现象**：写着“验收标准的文字定义在 spec（`op_execution/specs/{TID}_{slug}.md`）”。
- **影响**：与 D23 “生效规格不是单一工作 spec 映射，合入后以生效规格 op_blueprint/specs/{feature}.md 为准”不符。若只引导去追已归档的工作 spec，会破坏生效规格 specs/ 作为系统长期真相源的定位。
- **建议**：改为“验收标准当前定义以 `op_blueprint/specs/{feature}.md` 为准，历史工作 spec 作为合入来源归档于 `op_record/specs/`”。
- **置信度**：中
- **优先级**：MEDIUM

### 17. `{TID}_quality.md` 模板 severity 只提供 `P0 | P1` 选择
- **位置**：`docs_template/omni_powers/op_execution/issues/{TID}_quality.md:9`
- **现象**：限制级别为 `P0 | P1`。
- **影响**：与 design §3.2 “P0 只能人或 optriage 复核确认，agent 只能先赋 P1-P3 建议以防静默阻断”存在冲突。如果模板直接引导 agent 自主定 P0，容易被误用。
- **建议**：改为 `P1 | P2`（默认 P1，P0 需人工或分诊确认）。
- **置信度**：高
- **优先级**：LOW

### 18. `op_install.md` 归档说明中的章节引用过期
- **位置**：`docs/op_install.md:4`
- **现象**：说明指引“详见 docs/omni_powers_design.md §11”。
- **影响**：v6 合并后安装章节已移动至 §4.1，无效引用。
- **建议**：改为 “docs/omni_powers_design.md §4.1”。
- **置信度**：高
- **优先级**：LOW

### 19. `op_decisions.md` 历史记录存在可能引起歧义的过时机制描述
- **位置**：`docs/op_decisions.md` 全文
- **现象**：虽然是 append-only 历史，但 D1-D17 中大量 Workflow、tmux 等已被新决策废弃的架构细节没有醒目提示，初学者容易被误导。
- **影响**：阅读历史决策可能误以为某些已废弃设计仍属有效现状。
- **建议**：在文件头加粗强调：“本文件是 append-only 历史归档，部分旧决策已被后续决策推翻，一切设计真相和交付状态以最新的 docs/omni_powers_design.md 能力矩阵和最新章节为准”。
- **置信度**：中
- **优先级**：LOW

### 20. `issues/I-{YYYYMMDD}-{NN}.md` 模板 source 枚举不全
- **位置**：`docs_template/omni_powers/op_execution/issues/I-{YYYYMMDD}-{NN}.md:6`
- **现象**：source 仅包含 `reviewer 暂存 / reviewer 范围外 / evaluator 范围外 / 系统层夜跑 / 定期体检`。
- **影响**：缺少了 design §3.2 中“review 两轮到顶残留”这一关键入口。
- **建议**：将 `reviewer 暂存` 修正为 `review 两轮到顶` 并写入模板。
- **置信度**：高
- **优先级**：LOW

### 21. 模板 README/index 未说明 lite op_blueprint 空壳规则
- **位置**：`docs_template/omni_powers/README.md`、`docs_template/omni_powers/index.md`
- **现象**：模板完整列出 `op_blueprint/` 的文档构成，但在说明里没有专门提及 lite 模式下该目录仅用作路径兼容，实际上全为空壳且 agent 绝对不应读取它。
- **影响**：可能导致 oplinit 部署后，agent 被残留的空 blueprint 目录或模板引导去读取 blueprint 契约，引发行为漂移。
- **建议**：在 README 与 index 模板的 `op_blueprint` 章节加粗标注：“在 lite 模式下，本目录为空壳，规格判定全部回退至 `op_execution/specs/`”。
- **置信度**：中
- **优先级**：MEDIUM

## 改进建议

1. **自动校验脚本**：编写一个简单的一致性检查工具，自动比对 design 中的 `tasks_list.json.status` ASCII 字符集、TID 四位正则（`T[0-9]{4}`）在整个模板和 RULES.md 中的体现，防范未来维护时再次漂移。
2. **规范模板的 profile 分支**：在 `docs_template/omni_powers` 根目录下区分 `heavy/` 和 `lite/` 专有模板描述，或在一份 README 中将 profile 差异明文列为一等公民。
3. **收拢 decisions 块幂等头格式**：在 decisions 模板中给出一个明确的空注释，指导 agent 按 `[类型 | TID | 轮次 | YYYY-MM-DD]` 格式进行物理行级别的追加，从而能被 shell 脚本以简单 grep 快速检查幂等。

## 不确定项 / 可能误报

- `tasks_list.json` 模板中的 `depends_on: null`，部分 JSON 解析脚本可能会将其当成非法拓扑值或与空数组 `[]` 作不同分支处理。若现有代码中的 jq 调用能保证对 null 的鲁棒性，则只属于文档一致性问题，反之则为 HIGH 风险。
- `review.md` 模板中的 `verdict: UNKNOWN`，若 `op_read_verdict.sh` 中有限定只读取 PASS/FAIL 的正则表达式且会将其他非匹配行作为错误拒绝，则此 UNKNOWN 不会误导状态机，仅属于可读性优化。
- `docs/op_decisions.md` 的废弃决策属历史痕迹，不强制要求在旧决策内文改写，仅在头部补充高亮提示即可。
