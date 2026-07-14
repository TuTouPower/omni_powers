## 当前模型判断依据

可观测来源：`/home/karon/.claude/settings.json` 顶层 `model` 为 `haiku`；同文件 `env.ANTHROPIC_MODEL` 为 `default_model`；`env.ANTHROPIC_DEFAULT_HAIKU_MODEL` 为 `default_haiku[1m]`；`env.ANTHROPIC_DEFAULT_SONNET_MODEL` 为 `default_sonnet[1m]`；`env.ANTHROPIC_DEFAULT_OPUS_MODEL` 为 `default_opus[1m]`；主会话环境提示显示当前由 `default_model` 驱动。无法读取运行时内部状态，只能判断 current 路继承主会话；主会话可见模型标识为 `default_model`，配置默认模型字段显示 `haiku`。

## 审阅范围

- `/home/karon/karson_ubuntu/omni_powers/docs/op_decisions.md`
- `/home/karon/karson_ubuntu/omni_powers/docs/op_first_run.md`
- `/home/karon/karson_ubuntu/omni_powers/docs/op_install.md`

排除 `vendors/` 与 `docs/archive/`。逐文件、逐段全量审阅，不抽样。

---

## 高优先级问题（CRITICAL / HIGH）

### CRITICAL-1：op_first_run.md 自述生命周期已过期但仍留在 docs/

- **位置**：`docs/op_first_run.md` 第 6-7 行
- **现象**：文件自身声明「完成后本文档移 docs/archive/，结论沉淀进 op_decisions.md」。文档描述的内容（首跑计划、前置检查、三阶段路线）是时间敏感的一次性计划，含具体项目名、具体模型配置值、需要人工逐条勾选的环境检查项。当前该文件仍在 `docs/` 目录而非 `docs/archive/`。
- **影响**：读者（agent 或新加入者）无法从文件本身判断首跑是否已完成、文档是"待执行计划"还是"已过期的历史记录"。文件中引用的模型配置（`OP_IMPLEMENTER_MODEL=sonnet` 等）与当前 settings.json 配置可能不一致，产生误导。文件引用的 `docs/op_manual_leader.md`（第 71 行、第 118 行）实际不存在（`ls` 确认 Exit 2），表明首跑产出未按计划生成。
- **建议**：若首跑已完成则移入 `docs/archive/` 并加注完成日期与结论概要；若尚未完成则在文件头部显式标注状态（如 `status: not_started` 或 `in_progress`），与 tasks_list 或 checkpoint 机制关联。
- **置信度**：高（文件自身有不移即食言的自指声明，引用产物不存在直接证实）
- **优先级**：CRITICAL

### CRITICAL-2：op_install.md 描述完全废弃的插件机制但篇幅长达 381 行

- **位置**：`docs/op_install.md` 全文
- **现象**：文件头部已标注「已废弃，留作参考」「插件模式已废弃」「仅作为历史归档保留」。但文件正文 381 行详细描述了整套已废弃体系：`$CLAUDE_PLUGIN_ROOT`、`plugin.json`、`hooks.json`、`claude plugins install`、`opstart`/`opplan`/`optask`/`opdebt`、`op-coder`/`op-code-reviewer`/`op-test-reviewer` 旧角色名、`OMNI_POWERS_MODEL_*` 环境变量、`~/.config/omni_powers/config.yaml` 配置。当前生效的安装方案（`install.sh` + `--set-ophome`，见 `CLAUDE.md`「安装」段和 `docs/omni_powers_design.md` §4.1）与此文描述完全不相干。
- **影响**：尽管有废弃标记，超长正文仍会造成严重混淆。agent 阅读时可能被旧路径/旧变量名/旧角色名污染上下文（LLM 对"已废弃"标记的权重远低于正文细节）。一个显著风险：有人跳过头部标记直接读内容后按 `claude plugins install .` 来安装，会失败且无法理解原因。物理位置在 `docs/` 而非 `docs/archive/` 与 `CLAUDE.md` 中所说的「历史安装方案（已废弃，留作档案）」定位矛盾——同类废弃文档 `omni_powers_lite_design.md`、`op_findings.md` 等均在 `docs/archive/` 下。
- **建议**：移入 `docs/archive/`，同时在 `docs/archive/README.md` 中加一条记载。或极度精简为 10 行摘要保留在 `docs/`——只说明"历史上曾走 plugin 模式，现改用 install.sh"，其余全部删除。
- **置信度**：高（废弃文档体量远超头部声明，实物与声明的"归档"定位不符）
- **优先级**：CRITICAL

### HIGH-1：op_decisions.md 存在多次反转的决策链，末尾状态不明确

- **位置**：`docs/op_decisions.md` D12 (第 138 行) → D16 (第 174 行)
- **现象**：D12 决定「代码平面 vs 控制平面分离，一个 task 两个 commit」→ D16（39 行之后）完全推翻 D12：「取消控制平面/代码平面分离」「一个 task 一个 commit」「所有 task 共用一个 worktree」。随后 D27 A1-A2（第 429-432 行）又改了 merge gate 和 review.md 机制，进一步修正了 D16 的简化为"单 worktree"的后果。D16 本身的"所有 task 共用一个 worktree"在现行 design §3.4 中也被推翻——当前为 per-task worktree（`op/task/{TID}` 分支 + 独立 worktree）。读者按时间线读 D12→D16→D27 能在脑中重构演进过程，但直接跳到 D16 的读者会误以为当前仍是"单 dev worktree"模式。
- **影响**：D16 的标题和正文没有"已被后续 Dxx 取代"的标记（不同于 D1/D4/D5/D10 都有显式 `⚠️ 已被 D15 取代`），读者无法快速判断此决策的现行状态。若 agent 截取 D16 正文作为"现行规则"执行，会导致完全错误的 worktree 操作（单 worktree 共享 vs per-task worktree 隔离）。
- **建议**：D16 标题加 `⚠️ worktree 策略已被后续设计演化取代，现行隔离方案见 design.md §3.4`。类似地，对所有被后续演化推翻的旧决策统一标注时效状态。
- **置信度**：高（现行 design §3.4 的 per-task worktree 拓扑与 D16 的"单 worktree"明确矛盾）
- **优先级**：HIGH

### HIGH-2：op_first_run.md 模型配置与环境变量声明可能已与实际不同步

- **位置**：`docs/op_first_run.md` 第 24-31 行
- **现象**：文件硬编码了具体模型指配：`OP_IMPLEMENTER_MODEL=sonnet`、`OP_REVIEWER_MODEL=sonnet`、`OP_EVALUATOR_MODEL=opus`、`OP_CLOSER_MODEL=haiku`。design.md §2「模型分配」表中推荐值与这里的值不完全一致（design 推荐 reviewer 用 Opus，此处用 Sonnet）。且文件未标注日期——读者无法判断这是一次性首跑的特殊配置还是长期推荐值。
- **影响**：如果首跑已结束，这些值纯属历史快照，但照抄者会被误导。design.md 的推荐值是系统设计参考，首跑的配置是执行时的临时选择，二者语义不同但未区分。
- **建议**：加注「以下为首跑时的临时选择，默认推荐值见 design.md §2」；若首跑已完成，移除本文档时此问题自然消失。
- **置信度**：中（取决于首跑是否完成）
- **优先级**：HIGH（因与 CRITICAL-1 连锁：文档状态不明确放大了此处风险）

### HIGH-3：op_decisions.md D22 末尾记录了与 design §2.1 的未决张力

- **位置**：`docs/op_decisions.md` 第 343-344 行
- **现象**：D22 末尾写道「与现状的关系（待澄清）」——spec 强制不进 omni_powers vs design §2.1 的轻量直做门禁之间有张力，「留待后续裁决」。这是一个在决策记录中明确标注为"未决"的设计冲突。
- **影响**：D22 已记录决策意图（spec 为硬性入场条件），但与 design §2.1 当前正文有矛盾。两个多月过去（7/8 记录），张力仍未裁决。implementer/reviewer 在"三行 fix 要不要进 omni_powers"这一边界场景下没有明确判决依据。
- **建议**：要么裁决后补 D28 记录，要么在 design §2.1 加注此张力状态。
- **置信度**：高（决策记录自述未决）
- **优先级**：HIGH

---

## 中低优先级问题（MEDIUM / LOW）

### MEDIUM-1：op_decisions.md 决策编号非时间序排列，增加阅读阻力

- **位置**：`docs/op_decisions.md` 第 102 行 D13、第 116 行 D14、第 138 行 D12
- **现象**：D12（代码平面分离）排在 D13（放弃 task 拆分）和 D14（放弃并发）之后。文档内未说明编号跳序原因。读者按标题序号顺序读会先看到"放弃 task 拆分"(D13)再看到 D12，心理上会以为 D12 是后续补充，实则 D12 是先于 D13/D14 做出的决策。
- **影响**：轻度混淆，不影响信息完整性，但依赖编号推断时间线会出错。
- **建议**：在文档头部加一句「编号非严格时间序，部分决策编号跳序」说明；或保留现状，此文件毕竟是 append-only 决策记录，顺序忠实于写出时间而非编号。
- **置信度**：中
- **优先级**：MEDIUM

### MEDIUM-2：op_first_run.md 引用的产出文件不存在

- **位置**：`docs/op_first_run.md` 第 71 行、第 118 行
- **现象**：文件两次引用 `docs/op_manual_leader.md`——作为阶段 1 产出（"攒成底稿"）和首跑后动作（"定稿"）。经 `ls` 确认该文件不存在于 `docs/` 下。
- **影响**：指示了不存在的目标，按此计划执行会找不到写入位置；独立来看说明首跑计划未完成或产出丢失，强化了 CRITICAL-1。
- **建议**：若首跑未完成则标注产出文件待生成；若已完成则补充该文件或删除引用。
- **置信度**：高（文件不存在已证实）
- **优先级**：MEDIUM

### MEDIUM-3：op_decisions.md 旧角色名到 v6 角色名的映射只在头部，后续决策大量使用旧名

- **位置**：`docs/op_decisions.md` 第 5 行（头部映射声明）；全文 D1-D17 多处
- **现象**：头部声明了 `op-coder → op-implementer`、`op-code-reviewer / op-test-reviewer → op-reviewer` 的术语映射。但 D1-D17 正文全用旧名，读者（特别是快速浏览的 agent）可能在读到映射声明之前就遇到了旧名而产生困惑。此外头部映射无法覆盖 D24 之后新增文件路径和 hook 名称（`session-start.sh`、`hooks.json` 等）的旧引用。
- **影响**：习惯当前术语的读者需要做心智映射，但头部已声明映射故影响可控。
- **建议**：可在旧名首次出现处加脚注式提示（如 `op-coder (→v6 op-implementer)`），而非只依赖头部一句话。
- **置信度**：中
- **优先级**：MEDIUM

### LOW-1：op_install.md 内部有多处格式/内容重复

- **位置**：`docs/op_install.md` 第 121-134 行与第 246-268 行
- **现象**：「Skill 脚本 vs 共用脚本」表格（第 121-134 行）和「Skill 内引用改写」中的共用脚本调用示例（第 246-268 行）重复出现了相同的脚本列表和路径。同为废弃文档，此重复无实际危害。
- **影响**：无功能影响，纯编辑问题。
- **建议**：废弃文档移入 archive/ 后不再修改；若精简保留则删除重复段。
- **置信度**：高（重复可客观验证）
- **优先级**：LOW

### LOW-2：op_first_run.md 环境检查使用了当前可能不存在的检查脚本路径

- **位置**：`docs/op_first_run.md` 第 15 行
- **现象**：`bash "$OP_HOME/scripts/op_check_env.sh"` 引用的路径依赖 `$OP_HOME` 环境变量与 `scripts/op_check_env.sh` 文件存在。design §5.5 表明 lite 共享脚本在 `~/.claude/scripts/omni_powers/`，`$OP_HOME` 是 heavy 专属；若首跑在 lite 环境下此命令将失败。
- **影响**：轻度，仅首跑执行者受影响。
- **建议**：加注「仅 heavy 模式下有效」或改用 fallback 变量写法 `${OP_SCRIPT_ROOT:-$OP_HOME}/scripts/op_check_env.sh`。
- **置信度**：中
- **优先级**：LOW

---

## 改进建议

1. **op_first_run.md 增加状态 frontmatter**：在文件头部加 YAML frontmatter（`status: completed | in_progress | not_started` + `last_run_date`），让读者不必通读全文就能判断时效性。与 tasks_list 的 task 状态机制对齐。

2. **op_install.md 移入 archive/ 或大幅精简**：当前 381 行废弃文档放在 `docs/` 根目录违反了项目自身的 `docs/archive/` 惯例。建议移入 `docs/archive/`，路径为 `docs/archive/op_install_plugin_deprecated.md`，并在 archive README 登记。或保留一个 10 行的精简版说明"历史上曾有 plugin 方案，当前方案见 CLAUDE.md 安装段"。

3. **op_decisions.md 增加决策状态标注**：对已被后续演化推翻的旧决策（D12, D16 等），在标题行加 `⏳ 已演化` 标记，类似 D1/D4/D5 的 `⚠️ 已被 D15 取代` 写法。这已是文档自身设定的惯例（D1/D4/D5/D10 都有），但 D12/D16 缺失此标记。

4. **op_decisions.md D22 的未决张力需限期裁决**：D22 与 design §2.1 的矛盾已悬挂超过两个月。建议设定一个裁决期限（如「下个主要设计审查时必决」），防止变成永久悬挂项。若裁决结果为"保留轻量直做门禁作为 heavy 内嵌路径"，则 D22 尾部措辞更新为已决。

5. **op_decisions.md 可考虑加快速导航表**：本文档长达 448 行，决策编号不按时间排序。在头部加一个"决策状态总览表"（编号/日期/标题/现行状态）可大幅降低读者定位成本。当前只有术语演变一句话说明，不够。

---

## 不确定项 / 可能误报

- **首跑完成状态**：我无法从文件内容或 git 历史确定 `op_first_run.md` 描述的首跑是否已完成。如果确认已完成，CRITICAL-1 的修复就是纯粹的移入 archive；如果仍在进行中，则修复方向是加状态标记而非移除。本审阅按"文档自述应已归档但未归档"判断为 CRITICAL，若事实是首跑仍在进行则优先级应降为 MEDIUM（加注即可）。

- **D22 的张力是否已隐性裁决**：design.md §2.1 当前写的是"不需要 spec 的简单任务不该调本 skill，直接做即可"——这实际上等同于 D22 的立场。如果 §2.1 的这句话就是 D22 裁决的结果，那么 D22 的"留待后续裁决"应改为"已裁决，见 design §2.1 更新"。我无法确认这是否为隐性裁决后的遗漏更新。

- **op_decisions.md 的旧角色名是否为故意保留**：文档自身声明了术语演变，D1-D17 的旧名使用可理解为"忠实于决策做出时的语境"。这可能是设计选择而非缺陷。本审阅记录为 MEDIUM-3 但可能被判定为 WONTFIX。
