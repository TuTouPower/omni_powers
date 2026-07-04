# omni_powers 决策记录

> 记录架构和设计决策及其依据。最终规则见 RULES.md。
>
> **术语演变**：早期决策用旧 agent 名 `op-coder`（→ v6 `op-implementer`）、`op-code-reviewer` / `op-test-reviewer`（→ v6 `op-reviewer`，双裁决合并）。读到这些旧名时按 v6 角色对应，不视为新角色。

## D1：Agent Team vs Workflow（2026-06-25）— ⚠️ 已被 D15 取代

| | Workflow（task_review.js） | Agent Team（teammate） |
|---|---|---|
| 强制 schema | ✅ 结构化返回 | ❌ 输出不可控 |
| 强制 verdict | ✅ PASS/FAIL | ❌ 需 leader 解析 |
| 上下文复用 | ❌ 每次重新填充 | ✅ 跨 task 保留 |
| FAIL 轮状态 | ❌ 无状态 | ✅ 跨轮保留 |
| token 成本 | 高 | 低 |

**初始决策**：review 用 Workflow（要 schema 强制），开发用 Agent Team（要上下文复用）。

**后续变更**：见 D4。

## D2：推荐 in-process 而非 tmux（2026-06-25）

**理由**：tmux 的上下文监控优势被 shutdown 残留问题抵消。shutdown 后 Claude Code 实例和 tmux 面板不关闭，残留为孤儿。

## D3：上下文窗口从系统提示解析（2026-06-25）

**理由**：agent 训练数据和实际部署配置不一致。agent 不知道自己跑的 variant 和窗口大小。leader 应解析 teammate 系统提示中的 `powered by the model` 字符串，结合 settings.json 推导。

## D4：放弃 Workflow，全面使用 Agent Team（2026-06-25）— ⚠️ 已被 D15 取代

**变更**：review 从 Workflow（task_review.js）迁移到 Agent Team（op-code-reviewer + op-test-reviewer）。

**理由**：
- Workflow 每次重新填充上下文，token 成本高
- Agent Team 跨 task 复用上下文，FAIL 轮保留状态
- Workflow 的 schema 强制优势可通过 teammate 输出 review_*.md 首行 verdict 实现
- teammate 输出 review_*.md，leader 读文件判 verdict，兼得复用和结构化

**影响**：
- `docs/omni_powers/workflows/` 已删除
- review 流程改为：leader SendMessage 派 review → op-code-reviewer/op-test-reviewer 写 review_*.md → leader 读首行 verdict

## D5：放弃上下文监控，全面复用（2026-06-25）— ⚠️ 已被 D15 取代

**变更**：不监控 teammate 上下文占用，不主动 shutdown 重建，所有 teammate 全程复用直到 session 结束。

**理由**：
- ctx_stats 只显示 context-mode 拦截量，不显示实际上下文占用率，无用
- tmux capture-pane 能读但 shutdown 后面板残留，不值得
- 按 task 数轮换太粗糙，task 大小不一
- Claude Code 自身有 compact 机制，上下文满了会自动截断，不需要手动干预

**规则**：
- 使用 in-process 模式，不用 tmux
- teammate 跨 task 常驻复用，不主动 shutdown
- 上下文满了由 Claude Code 自动 compact/截断
- 只在 teammate 完全无响应时才 shutdown 重建

## D6：一个 task 一次 commit，hash 回填延迟（2026-06-25）— ⚠️ 已被 D12 取代

**变更**：收口只有一次主 commit。progress.md 和 leader_checkpoint.md 中的 `<待回填>` hash 不单独 commit，延迟到下一个 task 收口时一并回填提交。

**理由**：收口主 commit + hash 回填单独 commit = 两次 commit，违反"一个 task 一次 commit"原则。合并到下一个 task 的 commit 中，保持一个 task 一次 commit 的简洁语义。

## D7：op-test-reviewer 使用 Round 格式（2026-06-25）

**变更**：op-test-reviewer 从 10 段通用测试审查报告改为 Round N-1/N-2 轮次结构，与 op-code-reviewer 格式一致。

**理由**：模板 `review_test.md` 定义了 Round N-1/N-2 结构，但 op-test-reviewer agent 输出 10 段通用报告，格式完全不匹配。统一格式后 leader 判定逻辑一致，op-coder FAIL 轮处理也一致。

## D8：删除 agent frontmatter model 字段（2026-06-25）

**变更**：三个 omni_powers agent 定义文件（op-coder、op-code-reviewer、op-test-reviewer）删除 frontmatter 中的 `model` 字段。

**理由**：spawn 时 Agent 工具不读 frontmatter 的 model，必须显式传 `model` 参数。保留 model 字段会误导读者以为它会生效。

## D9：保留 opdebt HARD-GATE（2026-06-25）

**决策**：不改 opdebt SKILL.md 中的 `<HARD-GATE>` 标签。

**理由**：opspec 和 opplan 已注册到本项目的 `.claude/` 目录，Skill 工具可以调用。手动写 spec/plan 容易格式不一致、跳过自审流程，HARD-GATE 强制走标准化流程。

## D10：标记文件为完成判定唯一真相源，去双通道（2026-06-26）— ⚠️ 已被 D15 取代

**变更**：取消"双通道确认"（SendMessage + 标记文件必须同时满足）。完成判定以标记文件为唯一依据，SendMessage 降级为加速信号。

**规则**：
- teammate **先 touch 标记文件、再 SendMessage**（文件先落盘，消息丢了也能恢复）
- 标记文件路径：`.worktrees/{TID}/.omni_powers/signals/` 下，不在 git 跟踪区
- leader 每次主循环迭代前扫标记文件。文件存在即完成，不依赖 SendMessage
- 扫到 `coder_done` → 删文件 → 派 review
- 扫到 `reviewer_code_done` + `reviewer_test_done` 同时存在 → 删两文件 → 读 verdict
- 全在等时 `ScheduleWakeup(180s)` 兜底轮询
- FAIL 轮重新派 op-coder 前标记文件已在上一轮处理时删空

**理由**：
- SendMessage 跨 agent 通信不是 100% 可靠——消息可能丢失
- 双路并行等待引入竞态（消息和文件哪个先到）和重复判定问题
- 标记文件在 worktree 磁盘上，compact/crash 后也不丢——天然覆盖恢复场景
- SendMessage 仍保留：到达时触发提前扫描，省去 3 分钟等待
- 删除标记文件确保下一轮不会误读上一轮的旧标记

## D13：放弃 task 拆分（2026-06-26）

**变更**：删除 task-splitter subagent，删除所有 task 拆分逻辑。

**理由**：
- task 拆分是运行时动态行为，无法在 /opstart 的循环中可靠执行——拆后 tasks_list.json 变化，循环已跑过半
- task-splitter 要读原 spec/plan 全文、切片、重写——中间内容大量挤占 leader 上下文
- 实际使用中需要拆分的场景极少。真需要拆时，用户直接 /optask 拆好了再 /opstart

**影响**：
- 删除 `agents/optask-splitter.md`
- RULES.md / SKILL.md / CLAUDE.md 中所有相关段落删除

## D14：放弃 op-coder 并发（2026-06-26）

**变更**：只保留 op-op-coder，删除 coder-2/3。所有 task 串行执行。

**理由**：
- worktree 并发收口时的合并冲突、控制平面竞争、FF 策略选择——复杂度远超收益
- omni_powers 自身是单项目开发，不存在 trivially parallelizable 的 task
- 串行简化整个系统：无同层波次、无下游顺延、无并发 merge 冲突

**影响**：
- 花名册 op-coder/2/3 → op-coder
- RULES.md / SKILL.md 中所有"并发"、"波次"、"同层"段落重写
- DAG 仍保留给串行 task 的拓扑顺序计算

**变更**：删除并发判定算法（从 plan.md 提取文件列表→算冲突图→定联通分量）。并发直接按 DAG 拓扑同层，上限 3，不做文件冲突预检。

**理由**：
- worktree 隔离已防止互相覆盖，不存在并发写同一个文件的问题
- 合并冲突在收口时由 leader 按依赖优先规则解决，不是灾难
- 文件冲突预检依赖 AI 读 plan.md"文件结构"段提取路径——格式不可靠，脆弱
- 同层直接并发的逻辑可全脚本化（dag_gen.sh 已算拓扑），无需 AI 推理

## D12：代码平面 vs 控制平面分离，一个 task 两个 commit（2026-06-26）

**变更**：工作区文件分为两层——代码平面（per-task，进 feat 分支）和控制平面（全局共享，仅 leader 在主 repo 串行写）。收口从"worktree 内一次 commit 包含所有文件"改为两阶段：A. op-closer 在 worktree 做 per-task 操作 → leader commit 代码提交 → merge 回主线；B. leader 在主 repo 串行更新控制平面文件 → control plane commit。

**规则**：
- 代码平面：`src/`、`tests/`、`docs/omni_powers/op_execution/tasks/{TID}/`、`docs/omni_powers/op_record/tasks/{TID}/`
- 控制平面：`tasks_list.json`、`specs/{feature}.md`、`progress.md`、`decisions.md`、`tech_debt.md`、`leader_checkpoint.md`
- closer 绝不碰控制平面文件，输出 `closer_output` 供 leader 使用
- leader 在主 repo 串行处理收口，A 阶段 merge 后，B 阶段改控制平面

**理由**：
- 并发波次两个 worktree 各自有基线的 tasks_list.json / specs 等共享文件，各自改→merge 必冲突
- 控制平面文件应当在唯一位置（主 repo）由唯一写入者（leader）串行操作
- 两个 commit 语义清晰：代码 commit 是 task 产出，控制平面 commit 是收口记录

## D15：全线改用 Sub Agent，放弃 Agent Team（2026-06-27）

**变更**：op-coder、op-code-reviewer、op-test-reviewer 从 Agent Team 迁移为 Sub Agent。删除标记文件机制、Team 生命周期管理、CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS 依赖。

**理由**：

1. **上下文加载几乎一样**——Sub Agent 也加载 CLAUDE.md 全层级、git status、skills、tools、MCP。和 Teammate 的启动上下文差异极小。Agent Team "跨 task 上下文复用"记住的是旧 worktree 细节，对新 task 是噪音不是帮助。
2. **更简单**——删除标记文件（touch/rm/扫描/轮询）、TeamCreate/TeamDelete/spawn/config/shutdown、SendMessage 通信、ScheduleWakeup 兜底。通信改为 dispatch→返回结果。
3. **更稳定**——Agent Team 是实验性功能，API 在变化（TeamCreate/TeamDelete 已废弃、team_name 参数被忽略）。Sub Agent 是成熟 API。
4. **更便宜**——harness 只有 2-4 个并发 Agent，属于小规模。Sub Agent 每次按需 spawn，无 Team 常驻 token 开销。
5. **Superpowers 已验证**——社区最大 Claude Code 插件全线使用 Sub Agent，证明了该模式在小规模多 Agent 协作中的可靠性。

**影响**：
- 删除 `skills/opstart/scripts/op-scan-signals.sh`
- agents/*.md 删 SendMessage 工具和标记文件相关指令
- RULES.md 删除 Agent Team 管理节、标记文件节、idle 兜底、compact teammate 恢复
- SKILL.md 删除环境变量校验、Team 创建、标记扫描、SendMessage 派活
- 不再需要 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`

**详见**：`docs/agent_team_vs_subagent.md` 第十二节

## D16：从 per-task worktree 改为单 dev worktree，取消控制平面/代码平面分离（2026-06-27）

**变更**：

1. 所有 task 共用一个 worktree（`git worktree add .worktrees/op-dev -b feat/op-dev`），全 session 共享，不再每 task 创建独立 worktree
2. 取消"控制平面 vs 代码平面"分离——串行无并发，不存在 merge 冲突
3. leader、coder、reviewer、closer 全在同一目录工作
4. 一个 task 一个 commit（不是两个）
5. 收口在 session 结束时统一：merge + 删 worktree
6. `/opstart` 启动时问用户选 worktree 模式还是 master 模式

**理由**：
- 串行执行下 per-task worktree 的隔离收益为零——没有并发竞争
- 控制平面和代码平面分离是并发时代的遗产，串行下所有文件在一个目录，谁都可以写
- 简化收口流程：不需要 per-task merge/删 worktree/主 repo 不干净检查

**影响**：
- RULES.md 删除 commit 时机节、控制平面节、工作区与 worktree 节
- SKILL.md 收口从 5 小步简化为：op-closer 一步（spec 盖戳 + git mv + 更新 tasks_list.json + specs + tech_debt + git add -A + commit）
- agent prompt 中的 `.worktrees/{TID}` 路径改为项目根目录
- `close_check.sh` 不再检查主 repo 不干净（无此概念）

## D17：v5 对齐——closer 提案制、删 dag/tech_debt/using-omni-powers、controller=leader（2026-07-02）

基于 `vendors/omni_powers_harness_v5.md` 重构。以下决策记录依据，正式规则见 RULES.md。

| 决策 | 依据 |
|---|---|
| closer 产 blueprint_update 提案，直接追加 decisions.md，对 op_blueprint/ 无写权 | 改最高契约（生效规格）需隔离执行方，防静默改写。decisions.md 是 append-only 历史 closer 直接写。blueprint 提案写 `op_record/tasks/{TID}/blueprint_update.md`（diff 形态，覆盖 op_blueprint 全部文档），leader 审批后写入 |
| controller = leader 主会话（被 oplead 驱动） | 单设 controller agent 与 leader 职责重叠，多一层间接。状态走 checkpoint |
| 删 using-omni-powers meta skill | SessionStart hook 已动态注入路由，opstatus 渲染状态，内部 skill 由编排者调用。规则摘要放 CLAUDE.md |
| 删 oparchive skill，归档由 closer 末 task 顺带 | 归档即"改生效规格"，已由 closer 提案制覆盖，无需独立 skill |
| 删 dag.md，依赖走 depends_on + jq | DAG 文件是 tasks_list.json 的过期复印件，jq 直接查拓扑即可 |
| 删 tech_debt.md，技术债归 issues 加 `tech-debt` 标签 | 单独文件易过期，与 issues 重复。标签与 P0-P3 严重度正交 |
| review 合并为 op-reviewer 双裁决，≤2 轮 | 三 reviewer 并行是同档盲区，单 agent 双裁决（规格合规+测试可信）更准。两轮修不平是结构问题，继续循环烧 token |
| optriage 留 oplead，不并入 closer | 分诊需全局视野，信息流与 closer（收口提案）相反 |
| agents 模型用环境变量（OP_*_MODEL） | 用户可自定义 haiku/sonnet/opus，未设回退默认档 |
| plan 无独立文档 | plan 信息四归宿：顺序依赖→tasks_list+spec 执行图；跨 task 决策→spec；接口契约→代码先行；工作集→任务卡 |

**影响**：
- agents: 5 → 4（删三 reviewer，加 op-reviewer/op-evaluator；op-coder→op-implementer）
- skills: 6 → 7（删 opstart/opplan/optask/opdebt，加 opintake/oprun/opstatus/opred/optriage）
- hooks: 新增 pre/post_tool_use、stop、session_start
- 详见 `docs/vendors/reconstruction-proposal.md`、`docs/vendors/v5-revision-notes.md`

---

## baseline 形态裁定（2026-07-03）

| 决策 | 理由 |
|---|---|
| baseline 按信号性质分三层：结构化/语义（硬门）、视觉（锚点）、操作（手段） | 不按应用类型枚举——任何有外部可观察产物的系统都覆盖（DB/API/进程/消息/定时任务），形态由应用暴露的可观察接口决定 |
| 结构化信号进硬门机械断言，视觉截图不进机械硬门（交 evaluator 多模态对照） | 像素 diff 高 flaky（字体渲染、合法 UI 演化）；结构化信号可复现零放水。多模态比像素 diff 强（看语义级差异），但继承 stock model 放水，靠 hard-pass gate+预期失败模式+钓鱼审计兜 |
| baseline 可信——重验时 evaluator 对照 baseline + spec 看新结果 | baseline 是首次评经 hard-pass gate+破坏检查验过能红的 PASS 证据，锚定安全；确认偏误由 §8.1 防放水机制兜 |
| evaluator 自己操作应用复现 AC（computer use/独立机器），截图是锚点非比对对象 | "亲自观察"=自己操作触发，非看别人截的图。重验 = 重新操作复现路径逐步对照 |
| 前期单机（非 UI 类完整、UI 受限）/ 后期独立验证环境 + 独立机器自由操作 UI | 非 UI 类不依赖操作能力前期就完整；UI 类随操作能力升级。与文件系统隔离同阶段线 |
| 夜跑判定以结构化硬门信号为准，视觉对照不阻断 | 视觉 flaky 不进硬门，避免误报风暴 |

**影响**：
- design.md §8 表格 spec 层、§8.1 文件系统层、§8.2 重写（信号三层表+时序+阶段差+自己操作）
- agents/op-evaluator.md：步骤 1 自己操作+截图锚点、步骤 2 基准信号两层、访问隔离阶段差
- skills/opspec/SKILL.md：可测性契约"测试方式"→"验收信号"，入口扩到 DB/进程/消息/定时任务
- skills/oprun/SKILL.md：补阶段差
- agents/op-closer.md：baselines 合入段标注信号类型

## D18：hook 对 subagent 失效——隔离改纯 worktree 结构、行为层 worktree 对称（2026-07-04）

**触发**：`docs/four_model_review_2026_07_04.md` 审阅 + 官方文档/issue 技术核查。

**核心事实（已核实）**：PreToolUse/PostToolUse hook 对 subagent（Agent 工具 dispatch 的 agent）的工具调用 deny 整体失效——常规运行下就不 work，与 `--dangerously-skip-permissions` 无关。implementer/reviewer/evaluator/closer 全是 subagent（D15 全线 Sub Agent），故 v6 设计里所有"按身份分级的 hook 拦截"在当前 Claude Code 实现下不成立。

| 依据 issue | 结论 |
|---|---|
| [#40580](https://github.com/anthropics/claude-code/issues/40580) | subagent 工具调用，PreToolUse exit 2 被忽略，工具照常执行 |
| [#34692](https://github.com/anthropics/claude-code/issues/34692) | subagent 内 Bash/Edit/Write/Read/Grep 不触发 PreToolUse/PostToolUse |
| [#26923](https://github.com/anthropics/claude-code/issues/26923) | Task matcher fire 正常但 exit 2 拦不住 dispatch，subagent 照常 launch |
| [#43772](https://github.com/anthropics/claude-code/issues/43772) | bypassPermissions subagent 完全绕过 hook |

**好消息**：`agent_type` 在 SubagentStop/SubagentStart 可读且 matcher 按 agent_type 过滤（[#30703](https://github.com/anthropics/claude-code/issues/30703)）——可做事后门禁/留痕，但工具执行已完成，只能阻断收口/返回，不能阻止读源码动作本身。

| 决策 | 理由 |
|---|---|
| 隔离架构：纯 worktree 结构隔离（唯一硬底线=evaluator worktree 无 src） | hook 对 subagent 失效使"hook 拦 evaluator Read src/"破产；源码物理不在文件系统是唯一不可绕手段。放弃 frontmatter `tools` 配置级限制路线（用户拍板：选最硬的路） |
| 行为层保护：worktree 对称隔离（implementer worktree 不挂 e2e/）+ git 层（branch protection + pre-commit/post-receive） | implementer 也是 subagent，hook 拦不住；既有 e2e/BUG-* 硬锁改 git 操作层。BUG-* 新增由 evaluator 写或 implementer 产 patch 由 leader 转交 |
| 威胁模型：bypass 纳入（实际常规场景就失效，bypass 与否结论一致） | 不依赖"agent 不开 bypass"假设 |
| spike 重定位：worktree 无 src 工程（挂载范围 + CI 构建产物链路） | 原 P0/P1 身份识别 spike 删除——字段在但 deny 对 subagent 无效，无需再验 |
| 验收轮次：Stage 4 ≤3 轮，到顶 Critical→升级人裁决/Important-Minor→落 issue | 原则10循环上限，原 design 全文无 Stage 4 上限 |
| prd.md：grill-me 标注由外部 repo 提供 | 清悬空引用，grill-me 不在本仓库 |

**审阅意见处理**（`docs/four_model_review_2026_07_04.md`）：
- #1（身份识别）：**反向推翻**——审阅称"原生解决→独立环境可收缩"，实际独立环境（worktree 无 src）是唯一出路，方向反了
- #2/#3/#5/#6/#9：文档矛盾已修
- 额外小问题：§7.5 模型表合四行；**baselines/specs 双键统一为功能名**（§3 目录树 / §5.1 frontmatter 加 `feature` 字段 / §8.2 baselines_index 格式 + 合入路径临时区按前缀→合入区按功能名 + "跨前缀更新"改"跨功能更新"）；**§10 加防线层↔实现手段映射表**（点破主防线 1/2 层非 Claude hook，配齐 hook ≠ 安全）。注：`e2e/` 按工作前缀分目录保留——e2e 是代码资产按工作单位组织，前缀永不复用，与 op_blueprint 稳定真相异质，非双键问题
- #8（Stop hook）：SubagentStop 落点 + stop_hook_active 防递归已补；但审阅称"PreToolUse deny 在 bypass 下可拦"——**错误**，bypass 下 deny 同样失效（[#43772](https://github.com/anthropics/claude-code/issues/43772)）

**影响（design.md）**：§0 原则6、§2（行为层锁定改 worktree 对称）、§3（baselines 按功能名统一）、§4（Stage 2 自检 + 验收 3 轮 + 自举例外）、§5.1（frontmatter 加 `feature` 字段）、§7.5（模型表合并）、§8.1（访问隔离单层化：worktree 无 src + 报告回流 + dispatch advisory）、§8.2（双键统一功能名 + 跨功能更新）、§10（结构+git 层、SubagentStop、防线↔实现映射表）、§11（hooks 清单净化、Task advisory、issue 依据指 D18）、§12（spike 换 worktree 无 src、P2 硬要求）
