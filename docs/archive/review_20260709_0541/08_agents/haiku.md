## 当前模型判断依据

可观测来源：`/home/karon/.claude/settings.json` 顶层 `model=haiku`；`env.ANTHROPIC_MODEL=default_model`；`ANTHROPIC_DEFAULT_HAIKU_MODEL=default_haiku[1m]`；`ANTHROPIC_DEFAULT_SONNET_MODEL=default_sonnet[1m]`；`ANTHROPIC_DEFAULT_OPUS_MODEL=default_opus[1m]`。当前主会话由 `default_model` 驱动，本审阅路在 `default_haiku[1m]` 继承路径。不能读取运行时内部状态，current 路继承主会话。

## 审阅范围

- `/home/karon/karson_ubuntu/omni_powers/agents/op-closer.md`
- `/home/karon/karson_ubuntu/omni_powers/agents/op-evaluator.md`
- `/home/karon/karson_ubuntu/omni_powers/agents/op-implementer.md`
- `/home/karon/karson_ubuntu/omni_powers/agents/op-reviewer.md`

排除 `vendors/` 与 `docs/archive/`，全量逐段审阅。以 `docs/omni_powers_design.md` 为对照契约（只读上下文，不重复审阅）。

---

## 高优先级问题（CRITICAL / HIGH）

### H-1 [HIGH] op-reviewer description 与落盘协议矛盾——description 称「lite 自己写」，但 design §2.4/§3.4 明确 review.md 单写者恒为 leader

**位置**：`agents/op-reviewer.md:3`（frontmatter description）+ `:21`（omni_powers 协议适配段）

**现象**：
- description 写「heavy 下 leader 落盘 review.md；lite 自己写」
- 正文 §21 写「**heavy 下**你无 checkout……**由 leader 落盘 review.md**（你一般不直接 Write）。**lite 下**……自己写 review.md」
- 但 design.md:122/332/623 明确：review.md **单写者 = leader**，「task 分支不许碰，merge gate 白名单 REJECT」；§5.1 lite 差异表只列出 lite「主分支直改」，未声明 review.md 写权归 reviewer
- design.md:626 进一步说「流程文件（tasks_list.json / checkpoint / issues / decisions.md / review.md）**只在主 worktree 一份物理副本**」——单写者化是两版共用的隔离根基

**影响**：若 reviewer 在 lite 下当真直接 Write review.md，破坏单写者原则；若不写，则 description 与正文误导 leader。两版核心契约 review.md 落盘协议出现一处模糊点，实际执行时可能产生 leader/reviewer 双写或无人写。

**建议**：统一表述为「两版 review.md 末行 verdict 均由 reviewer 返回，leader 落盘；lite 下 reviewer 仍只返回末行 verdict，不直接 Write」。或在 design §5.6 lite 流程明确 lite 下也由 leader 落盘（若 design 为权威），反之同步改 agent。

**置信度**：85%（design 多处强调单写者，agent description/正文未对齐）

**优先级**：HIGH

---

### H-2 [HIGH] op-closer 硬校验「pwd == leader 指定目录」与 design §3.4 角色视图不一致——closer 在主 worktree 内工作，不是独立 worktree

**位置**：`agents/op-closer.md:11`

**现象**：
- agent 写「收到任务第一件事：`cd <work_dir> && pwd`。硬校验：pwd 输出必须等于 leader 指定的工作目录」
- design.md:624 角色视图明确：op-closer「**主 worktree 内工作（heavy）** | 完整 checkout | 主分支」
- design.md:492 closer gate 描述「主 worktree 完整 checkout，物理能写 src/spec/e2e/op_blueprint 的一切」

closer 并非独立 worktree，`work_dir` 就是主 worktree 路径。硬校验 pwd 在此场景下意图模糊：closer 是 subagent，dispatch 时 cwd 已被 leader 注入主 worktree；「硬校验」在此角色上与 implementer（独立 worktree）的语义不同。

**影响**：closer 实际在主 worktree 工作，pwd 校验语义重复且易与 closer gate（§2.6）职责混淆——closer gate 才是真正的越界校验（`op_closer_gate.sh`），prompt 级 pwd 校验在 closer 场景下无增量保护，却可能让 closer 在路径不匹配时直接 die，绕过 gate 机制。

**建议**：澄清 closer pwd 校验意图（仅防 dispatch 传错路径），或删除该硬校验（closer gate 已机械覆盖写权限）；若保留，明确「主 worktree 路径」而非泛化的「工作目录」。

**置信度**：70%

**优先级**：HIGH

---

### H-3 [HIGH] op-implementer 与 op-closer 对 decisions.md 写权的描述不对称——design §3.4 说 implementer 无写权，agent 文件未显式重申写权边界

**位置**：`agents/op-implementer.md`（全文，无 decisions.md 写权声明）

**现象**：
- design.md:380 明确「implementer 对 decisions.md 无写权（§3.4 流程文件单副本在主 worktree）——归因写进 report.md 的归因段」
- design.md:626「流程文件……只在主 worktree 一份物理副本」
- implementer agent 文件全文未显式声明「不写 decisions.md」；只在 §6 契约边界提到「需进 spec 的决策→回报 leader 走 spec 变更子流程」，但未点明 decisions.md 由 leader 写而非自己写
- 对照 closer agent（:41/49）明确「decisions.md 你直接追加」「implementer 对 decisions.md 无写权——归因写进 report.md」

**影响**：implementer 可能在执行期误判「需要记 spec-delta」时直接写 decisions.md（尤其 lite 下无 worktree 隔离、主分支直改），破坏单副本单写者原则。design §2.4 规定 spec-delta 由 leader 写，implementer 只回报。

**建议**：implementer agent 的「禁止」段补一条：「不写 `op_record/decisions.md`（leader 单写者；design §3.4）——spec 变更类决策回报 leader，红灯归因写 report.md 归因段」。当前禁止段（:158-167）漏了这条。

**置信度**：80%

**优先级**：HIGH

---

## 中低优先级问题（MEDIUM / LOW）

### M-1 [MEDIUM] op-evaluator 输出路径前缀不一致——正文用 `docs/omni_powers/op_execution/`，其他段落用 `op_execution/` 相对路径

**位置**：`agents/op-evaluator.md:149`（输出段）vs `:117/127/189`（步骤 1/2、报告回流层）

**现象**：
- `:149`「写入 `docs/omni_powers/op_execution/acceptance/{TID}/acceptance_report.md`」——带 `docs/omni_powers/` 前缀
- `:117`「写入 `acceptance/{TID}/eval.md`」、`:127`「`op_execution/acceptance/{TID}/baselines/`」、`:189`「`op_assemble_eval_brief.sh {TID}`」——相对路径
- design.md:102 目录树根是 `docs/omni_powers/`，agent 内路径混用相对与绝对

**影响**：evaluator 作为 subagent，worktree 内路径解析取决于 dispatch 注入的 cwd；路径前缀不一致可能在 sparse-checkout 下导致写文件定位偏差（写错位置会越过 gate 或丢失）。

**建议**：全文统一为相对 `op_execution/` 的路径（与 design §1 目录树一致），或在开头声明「所有路径相对 leader 指定的工作目录根」。

**置信度**：75%

**优先级**：MEDIUM

---

### M-2 [MEDIUM] op-reviewer 「暂存判断标准」与 design 范围外发现 P 级赋值链路不完全对齐

**位置**：`agents/op-reviewer.md:26`

**现象**：
- agent 写「暂存判断标准（满足任一才可暂存）：跨 scope / 需环境变更 / 架构决策 / 依赖未来 task」
- design.md:572「P 级（P0-P3）是 issue 排期语义……**落盘者赋 P（统一协议）**：reviewer 范围外发现写进返回文本暂存段（reviewer 无 checkout，不直写 `issues/`）→ leader 收口时落盘 `issues/` 并赋 P」
- reviewer agent 未在暂存段格式里给出 P 级建议字段，只有【暂存:原因】标签

**影响**：reviewer 作为最了解范围外发现影响面的角色（design §3.2 赋 P 由落盘者做），暂存段缺 P 建议字段会让 leader 落盘时缺少初判依据；design §2.6 closer 分支提到 closer 赋 P（reviewer 范围外发现最了解影响面），链路上 reviewer→leader/closer 的 P 初判信息缺失。

**建议**：reviewer 暂存段格式补 `P建议: P0|P1|P2|P3` 字段（参考 design §3.2 issue 字段），并注明「P0 不由你最终赋，leader/optriage 复核确认」。

**置信度**：65%

**优先级**：MEDIUM

---

### M-3 [MEDIUM] op-closer blueprint_update.md 模板未含 spec 变更决策表与验收标准追溯矩阵

**位置**：`agents/op-closer.md:52-89`（提案模板）

**现象**：
- closer 提案模板覆盖 specs/architecture/domain/conventions/prd/test/baselines/task 归档
- design.md:518 事后报告内容含「验收标准追溯矩阵（closer 提案含）+ spec 变更决策表（decisions.md spec-delta）」——明确「验收标准追溯矩阵」由 closer 提案含
- closer 模板里没有 AC 追溯矩阵段

**影响**：事后报告关键素材（AC→实现→验收证据映射）在 closer 提案阶段缺失，leader 生成事后报告时要补，违反 design「closer 提案含」的声明。

**建议**：提案模板补「## 验收标准追溯矩阵」段（| AC-N | spec 条目 | 实现文件:行 | 验收证据 |）。

**置信度**：70%

**优先级**：MEDIUM

---

### M-4 [MEDIUM] op-evaluator 步骤 0 重验基准读取路径与 design §2.5 描述错位

**位置**：`agents/op-evaluator.md:72-79`（步骤 0）

**现象**：
- agent「重验（对照评）：有 baseline，读基准位置按时序分……跨 task / 后续迭代重验：读 `op_blueprint/baselines/baselines_index.md` + `op_blueprint/baselines/{功能名}/`」
- design.md:450「跨 task / 后续迭代重验（前 task 已收尾合入）：读 `op_blueprint/baselines/baselines_index.md` 找已有基准快照」
- 两者基本一致，但 agent 用 `{功能名}`，design 用功能名分目录（§1 目录树 `session-management/`）；design §2.5 :526 强调「feature_key 闸门 A 阶段确定，入 task spec frontmatter / tasks_list，closer 只能引用不能重新判断」——evaluator 读基准也需按 feature_key，agent 未显式声明 feature_key 来源

**影响**：evaluator 重验时若不知 feature_key（来自 spec frontmatter / tasks_list），可能按 TID 或 slug 找错基准目录。

**建议**：步骤 0 补一句「feature_key 从 task spec frontmatter 读（闸门 A 定，D10），非自行判断」。

**置信度**：60%

**优先级**：MEDIUM

---

### M-5 [MEDIUM] op-implementer 工作流未提「dispatch 锚点 sha」相关协作，lite 下与 design §5.9 补强链路脱节

**位置**：`agents/op-implementer.md:28-55`（工作流）

**现象**：
- design.md:908「**dispatch 锚点 sha**：dispatch implementer 时记 HEAD sha，reviewer `git diff` 锚定该 sha 而非 HEAD——防 implementer 自行 commit 致 diff 空」
- design.md:630「记录 dispatch 锚点 sha（= 主分支头；lite 下作 reviewer diff 锚点）」
- implementer agent 工作流完全未提 dispatch 锚点；lite 下 implementer 自行 commit 会让 reviewer diff 空（review-package 失明）
- implementer agent 只在「正向开发」说「不 jq 读 tasks_list.json」，对 lite 下是否可自行 commit 无指引

**影响**：lite 下 implementer 若自行 `git commit`（无分支拓扑，主分支直改），会抹平 reviewer diff 锚点，破坏 design §5.9 补强机制。agent 层缺「不要自行 commit」或「commit 规则」的指引。

**建议**：implementer 工作流补 lite 分支说明——lite 下不自行 commit（commit 归 leader 收口），或明确 commit 时机；heavy 下分支内自由 commit 已由 design §3.4 覆盖。

**置信度**：60%

**优先级**：MEDIUM

---

### L-1 [LOW] op-closer frontmatter description 冗长，单段 4 行无换行，可读性差

**位置**：`agents/op-closer.md:3`

**现象**：description 字段塞进「per-task 一段式……（per-task 验收 PASS 后）：append decisions.md + 把暂存项转 issue + 产 blueprint_update.md 提案（含 baselines 合入 + task 归档）。对 op_blueprint/ 无写权限，提案由 leader 自审后执行写入（A18，不经用户事中审批）」——单段长句。

**影响**：dispatch 时 subagent_type 选择与角色识别靠 description，过长降低匹配清晰度。

**建议**：拆短句或用分号分隔核心职责。

**置信度**：90%

**优先级**：LOW

---

### L-2 [LOW] op-evaluator 「cua 域证据规则」段提到 `cua do shell`，未给降级时的 shell 证据替代

**位置**：`agents/op-evaluator.md:57`

**现象**：「能抓的结构化信号照抓（`cua do shell` 查进程/文件/注册表副作用……）」——但降级规则（:61）只覆盖 cua 不可用时 AC 判 INSUFFICIENT_EVIDENCE，未说 cua 可用但 `cua do shell` 不可用时怎么办。

**影响**：边界场景证据收集策略模糊，实际 cua 版本差异可能让 `shell` 子命令缺失。

**建议**：降级规则补「`cua do shell` 不可用 → 改用 CDP 直驱的 Bash/HTTP/SQL 抓结构化信号，仍不可达判 INSUFFICIENT_EVIDENCE」。

**置信度**：55%

**优先级**：LOW

---

### L-3 [LOW] op-implementer TDD 流程示例命令偏前端（`npm test`）

**位置**：`agents/op-implementer.md:79`

**现象**：「`npm test -- path/to/test.test.ts`」——示例固定为 npm/ts 栈，但 omni_powers 本身是 bash + 通用框架，被派发的项目可能是 Python/Go/Rust。

**影响**：implementer 若机械照搬命令格式，非前端项目跑错命令。

**建议**：改为「`<项目测试命令> -- <测试路径>`」并注明「测试命令见 spec 可测性契约 / CLAUDE.md」。

**置信度**：85%

**优先级**：LOW

---

### L-4 [LOW] op-reviewer 「问题不分严重度等级」与 design §3.2 P 级语义表述易混淆

**位置**：`agents/op-reviewer.md:23`

**现象**：agent「问题不分严重度等级：范围内问题写进返回文本的问题清单；范围外问题标【暂存】」——表述正确，但与 design §3.2「P 级（P0-P3）是 issue 排期语义」并列时，读者易误以为 reviewer 完全不碰 P。

**影响**：认知歧义，实际 reviewer 暂存项后续要赋 P（M-2 已提）。

**建议**：补一句「范围内/外是分流维度，P 级是排期维度，两者正交；暂存项可附 P 建议」。

**置信度**：70%

**优先级**：LOW

---

### L-5 [LOW] op-closer 步骤 3 标题「追加 decisions.md（直接写，非提案）」与铁律 1「可写 decisions.md（append-only，直接追加）」重复但措辞略冲突

**位置**：`agents/op-closer.md:39` vs `:16`

**现象**：铁律 1 说 closer 可写 decisions.md；步骤 3 标题强调「直接写，非提案」；两处都正确，但「非提案」措辞易让人误以为其他步骤都是提案。

**影响**：轻微认知负担。

**建议**：统一表述，铁律 1 已足够，步骤 3 标题可简化。

**置信度**：80%

**优先级**：LOW

---

### L-6 [LOW] 四份 agent 均用「收到任务第一件事 cd + pwd 硬校验」，但 heavy 下 reviewer/closer 无独立 worktree，语义重复

**位置**：`op-closer.md:11`、`op-reviewer.md:29`（lite 分支才有 cd）、`op-implementer.md:25`、`op-evaluator.md`（无显式 cd 段，但 worktree 隐含）

**现象**：
- implementer/evaluator 在独立 worktree，cd 校验有意义
- closer 在主 worktree（design §3.4），reviewer heavy 无 checkout（design §3.4:623）——两者 cd 校验语义弱化
- reviewer 已正确区分「lite 下 cd，heavy 下无此步」（:29）；closer 未区分

**影响**：closer pwd 校验与 closer gate（机械）职责重叠（H-2 已提）。

**建议**：closer 参考 reviewer 写法，区分 heavy/lite；或删除（gate 覆盖）。

**置信度**：65%（与 H-2 部分重叠）

**优先级**：LOW

---

## 改进建议

1. **统一 review.md 落盘协议表述**（H-1）：四份 agent + design 对齐「review.md 单写者 = leader，两版共用」，消除 lite 下「reviewer 自己写」的歧义。

2. **补 implementer decisions.md 写权禁止项**（H-3）：与 closer 的「implementer 无写权」声明对称。

3. **澄清 closer pwd 校验意图**（H-2）：区分「防 dispatch 传错路径」与「closer gate 机械校验」职责。

4. **统一路径前缀风格**（M-1）：evaluator 全文用相对 `op_execution/` 路径，与 design §1 目录树一致。

5. **closer 提案模板补 AC 追溯矩阵段**（M-3）：design §2.6 事后报告素材由 closer 产。

6. **reviewer 暂存段补 P 建议字段**（M-2）：赋 P 协议链路完整性。

7. **implementer 补 lite 下 commit 规则**（M-5）：防抹平 reviewer diff 锚点。

8. **TDD 命令示例去前端化**（L-3）：通用化或引用 spec 可测性契约。

9. **closer description 拆句**（L-1）：提升 subagent_type 匹配清晰度。

10. **evaluator feature_key 来源显式化**（M-4）：重验基准读取防错目录。

---

## 不确定项 / 可能误报

1. **H-1（review.md lite 落盘）**：design §5.6 lite 流程图（:863）写「派 op-reviewer → 双裁决 → tasks/{TID}/review.md（末行 verdict）」，字面可解读为 reviewer 写；但 design §2.4/§3.4 单写者原则又强调 leader 写。若 design §5.6 为 lite 专门豁免，则 agent description 正确，H-1 误报；需 design 侧澄清 lite 下 review.md 是否真豁免单写者。置信度下调空间存在。

2. **M-4（feature_key 来源）**：若 evaluator dispatch prompt 已由 leader 注入 feature_key（未在 agent 文件体现），则 agent 不写也无碍；需查 oplrun/oprun dispatch 模板确认。

3. **M-5（implementer lite commit）**：若 lite dispatch prompt 已含「不自行 commit」约束（agent 文件不重复），则误报；需查 oplrun SKILL dispatch 段。

4. **L-2（cua do shell 降级）**：cua 版本若已稳定提供 shell 子命令，边界场景概率低，可能过度设计。

5. **H-2（closer pwd 校验）**：若 closer dispatch prompt 明确传 `work_dir=主worktree路径`，pwd 校验仍有防传错价值，则保留合理；仅与 gate 职责表述重叠，非真正冲突，严重度可能降为 LOW。

---

result: 已写入 docs/review_20260709_0541/08_agents/haiku.md
