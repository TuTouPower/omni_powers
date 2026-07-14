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

## D6：一个 task 一次 commit，hash 回填延迟（2026-06-25）— ⚠️ 已被 D16 取代（经 D12 两 commit→D16 恢复一 commit）

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

**变更**：只保留 op-coder，删除 coder-2/3。所有 task 串行执行。

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

**详见**：`docs/archive/agent_team_vs_subagent.md` 第十二节

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

基于 `vendors/omni_powers_harness_design/omni_powers_harness_v5.md` 重构。以下决策记录依据，正式规则见 RULES.md。

| 决策 | 依据 |
|---|---|
| closer 产 blueprint_update 提案，直接追加 decisions.md，对 op_blueprint/ 无写权 | 改最高契约（生效规格）需隔离执行方，防静默改写。decisions.md 是 append-only 历史 closer 直接写。blueprint 提案写 `op_record/tasks/{TID}/blueprint_update.md`（diff 形态，覆盖 op_blueprint 全部文档），leader 审批后写入 |
| controller = leader 主会话（被 `/oprun` 驱动） | 单设 controller agent 与 leader 职责重叠，多一层间接。状态走 checkpoint |
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
- 详见 `vendors/omni_powers_harness_design/omni_powers_harness_v5.md`

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

**触发**：四模型审阅记录（临时审阅材料，未纳入仓库）+ 官方文档/issue 技术核查。

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
| prd.md：早期曾引用外部 grill-me，当前统一改为 opinit blueprint-generator 初始化 + 需求澄清流程维护 | 清悬空引用，避免读者误以为本仓库提供 grill-me |

**审阅意见处理**（四模型审阅记录，临时审阅材料，未纳入仓库）：
- #1（身份识别）：**反向推翻**——审阅称"原生解决→独立环境可收缩"，实际独立环境（worktree 无 src）是唯一出路，方向反了
- #2/#3/#5/#6/#9：文档矛盾已修
- 额外小问题：§7.5 模型表合四行；**baselines/specs 双键统一为功能名**（§3 目录树 / §5.1 frontmatter 加 `feature` 字段 / §8.2 baselines_index 格式 + 合入路径临时区按前缀→合入区按功能名 + "跨前缀更新"改"跨功能更新"）；**§10 加防线层↔实现手段映射表**（点破主防线 1/2 层非 Claude hook，配齐 hook ≠ 安全）。注：`e2e/` 按工作前缀分目录保留——e2e 是代码资产按工作单位组织，前缀永不复用，与 op_blueprint 稳定真相异质，非双键问题
- #8（Stop hook）：SubagentStop 落点 + stop_hook_active 防递归已补；但审阅称"PreToolUse deny 在 bypass 下可拦"——**错误**，bypass 下 deny 同样失效（[#43772](https://github.com/anthropics/claude-code/issues/43772)）

**影响（design.md）**：§0 原则6、§2（行为层锁定改 worktree 对称）、§3（baselines 按功能名统一）、§4（Stage 2 自检 + 验收 3 轮 + 自举例外）、§5.1（frontmatter 加 `feature` 字段）、§7.5（模型表合并）、§8.1（访问隔离单层化：worktree 无 src + 报告回流 + dispatch advisory）、§8.2（双键统一功能名 + 跨功能更新）、§10（结构+git 层、SubagentStop、防线↔实现映射表）、§11（hooks 清单净化、Task advisory、issue 依据指 D18）、§12（spike 换 worktree 无 src、P2 硬要求）

## D19：evaluator 执行后端接线 CUA（CDP 优先铁律 + cua 独立 lane）（2026-07-05）

**触发**：用户要求 evaluator 参考个人测试总方案（`~/karson_ubuntu/my_file/TESTING_PLAN.md`）使用 [CUA](https://github.com/trycua/cua) 作 UI/桌面自动化执行后端。插件在 Win 宿主 Claude Code 内调用，evaluator 与 cua-driver 同机，无跨环境桥接。

| 决策 | 理由 |
|---|---|
| 通道判定进 spec 可测性契约：每条 AC 加 `通道: CDP \| cua \| 直驱` 字段，判定决策树进 opspec | **CDP 能力边界优先**（TESTING_PLAN §0 核心原则）：能用 CDP 一律 CDP（快/稳/可断言 DOM），CDP 做不到的（Electron 原生壳层、浏览器 chrome、OS 对话框）才 cua，无 UI 直驱。写 spec 时判定，evaluator 照单执行——判定是 spec 期决策不是执行期决策 |
| evaluator 加「执行后端」节：cua CLI 用法（Look→Act→Verify）+ 降级规则 | cua 不可用 → 该 AC 判 INSUFFICIENT_EVIDENCE 并写明缺失，禁止跳过/降级推断/用 CDP 假装模拟 OS 行为——堵住"环境缺失变相放水"通道 |
| cua 域固化物独立 lane（`// channel: cua`）：夜跑失败开 issue 不阻断；破坏检查一次性验证不进回归硬门 | cua 域测试天然 flaky（焦点漂移/DPI/时序），进 CDP 硬门会产假红腐蚀夜跑信号。对应 TESTING_PLAN §9 CI 分组（cua 域 nightly） |
| eval brief 组装脚本探测 cua 可用性写进 brief | 机械组装原则不变：可用性是环境事实，脚本 `command -v cua` 探测比 evaluator 现场试错省一轮 |
| TESTING_PLAN 作上游宪章引用，不复写进插件 | 用例矩阵（TP-*）/边界表/CI 矩阵属个人测试资产，插件模板 test.md 留引用位；避免两处维护漂移 |

**影响**：`skills/opspec/SKILL.md`（模板加通道字段 + 通道判定节）、`agents/op-evaluator.md`（执行后端节 + 步骤 1/2 接通道）、`skills/oprun/scripts/op_assemble_eval_brief.sh`（brief 加执行后端段 + cua 探测）、`docs_template/omni_powers/op_blueprint/test.md`（lane 表）。design.md §8 未动——通道选择是 §8.2「操作层」的实现细节，design 不下沉到工具名。

## D20：设计文档合并 + 六项裁决（证据 CI 化/e2e 只读信号/严格串行/闸门 A 扩容/lite P0 检查）（2026-07-07）

**触发**：用户要求整体设计审查，识别出 5 个结构性问题 + 5 个次级问题，逐项裁决后合并 heavy/lite 两份设计文档。

| 决策 | 理由 |
|---|---|
| `omni_powers_lite_design.md` 并入 `omni_powers_design.md`（§13-§15），原文移 `docs/archive/` | 两模式一份设计，差异收敛在环境集成层；统一 install.sh + 按项目 init 分轻重的架构定型后，分文档只剩同步成本 |
| per-task 证据 CI 化（P2）：implementer 分支 push 触发 CI 跑测试，结果为准 | D18 后 PostToolUse 对 subagent 不触发，implementer 自跑自贴的证据可伪造，SubagentStop 只验存在不验真伪——"机器证据"必须在被监督者控制之外。与 evaluator 构建产物链路共用同一套 CI（原则 7 改写） |
| implementer 分支 CI 只读跑 e2e 全集回传结果（P2） | worktree 对称隔离使 implementer 盲跑集成，断裂积累到 Stage 4 才暴露是最贵反馈环；只读信号不给写权，不破坏隔离（§2） |
| task 严格串行，任务卡去「可并行」字段 | 多 implementer 并行 = 多 worktree 同时 append decisions.md 等共享文件，append-only 多写者是 git 合并最差场景；当前无真实并行需求，不为不存在的场景设计合并协议（原则 9） |
| 闸门 A 预算 5-10 分钟 → 15-30 分钟/叶子（用户选 A，不做审查减法） | spec 是全系统唯一质量单点（三方对着它干活），含可测性契约后 5-10 分钟只会橡皮图章；这半小时是全流程杠杆最高的人工投入（原则 11） |
| lite 补 P0 阻断检查（oplrun 叶子归档前扫 open P0，停下问用户） | lite 无闸门 C，P0 会随自动归档静默放行——heavy 的 blocks_merge 安全语义丢失；补一行检查恢复同语义（§14.2） |
| 纯文档修正一批 | §0.1 安全增量诚实声明（P2 前 heavy≈lite，买的是流程资产非安全）；原则 11 措辞改「正常路径」（消解与异常人裁的矛盾）；lite op_blueprint 占位加单行 README（防"目录空=无约定"误推断）；spec 前缀 26 后转双字母字典序；§8.3 登记 e2e 合法写入与 git 硬锁交互为 P2 开放问题；§8.1 钓鱼审计标注基建依赖 P3 |

**接受现状不改**：heavy leader 无上下文水位机制（靠 checkpoint+compact 容错，lite 因亲验证据才需硬约束）；钓鱼审计基建 P3 前收敛判据暂缓。

**影响**：`docs/omni_powers_design.md`（全文重写为合并版）、`docs/archive/omni_powers_lite_design.md`（归档+冻结标注）、`CLAUDE.md`/`RULES.md`/`docs/archive/README.md`（引用更新）。待实现项随 §12 P2/P3 排期，见合并版 §15。

## D21：四模型审阅处置（合并版 design.md 审阅轮）（2026-07-07）

**触发**：合并版 `docs/omni_powers_design.md`（D20 产物）经 self / opus / sonnet / haiku 四模型只读审阅，报告存 `docs/review/`。

**采纳（多家一致或明显正确）**：

| 处置 | 来源 | 落点 |
|---|---|---|
| §0.2 当前能力快照表（单一状态真相源），正文各节状态声明收进表 | self H1 / haiku H1 / sonnet 暗含 | §0.2 新增；§8.1/§10 状态声明改引用 |
| lite 水位检查升级为流程门（连续 2 次超阈值暂停） | self M3 / opus M1 / sonnet H2 | §14.1 改写 |
| decisions.md append 幂等标识 + op_close_post 前置检查 | self M4 / opus M2 / sonnet H5 | §7.4 加协议段 |
| spec 变更子流程补定义（delta 路径/发起者/审批归属/task 处置） | self M1 / sonnet M2 | §5.2 新增四步 |
| lite→heavy 迁移显式声明（非切 profile） | self M2 / sonnet M4 | §13 末段新增 |
| §10 正文/映射表去重、§15 决策史回链 op_decisions.md | 四家全提 | §10 重写 / §15 精简 |
| §10.1 CI 最小接口三接口节 | sonnet 建议 1 | §10.1 新增 |
| worktree spike 补备选方案（独立浅 clone）+ 平台验证 | sonnet H4 | §12 P0 改写 |
| 小修集：BUG-* 目录位置（§3）、§7.2 明确「呈报用户四选一」、钓鱼审计开头标 P3、token 排序标待实测、AC=验收场景注释（§5.1）、closer 铁律合并单条（§7.4）、原则 7 拆 3 小点、快速导航表、OP_SCRIPT_ROOT 前置探活（opus M3）、§13.4 砍 op_close_pre 因果链一句话（haiku M5）、§1.2 style 测试规则见 §2 交叉锚（haiku L4） | 各家 LOW/MEDIUM | 逐处 |

**用户裁决三项**：
- 决定 1（§8.3 方向）：**A 敲定 leader 唯一入口**（commit trailer + 解锁脚本配对；入口先于硬锁上线）。三家审阅收敛到同一方案，再拖无信息增量。
- 决定 2（P2 CI 三合一是否拆里程碑）：**B 保持三合一整体交付**。sonnet H3 主张拆独立灰度，用户裁定不拆——共用 CI 配置框架、P2 内顺序交付。
- 决定 3（过渡期 evaluator 审计脚本加不加）：**B 不加**。opus 建议 2 主张加扫 src/tasks 引用痕迹脚本，用户裁定不加——一次性护栏（P2 落地后即废），过渡期风险已由 §0.1/§0.2 诚实声明覆盖，不为短命护栏付实现 + 维护成本（原则 12 护栏按需付费）。

**驳回**：
- sonnet M6（无差异脚本加同步注释）：`build_lite.sh` 漂移校验 + `--sync` 修复机制已存在，注释是冗余层。
- haiku M2（lite 状态机图缺阻塞分支）：图内已有「2轮FAIL → 阻塞（下游跳过）」行，与 heavy 同构，事实不准。
- sonnet M5（定期体检补实现概要）：P3 项，提前设计调度/工具选择是过度；CI 最小接口节（§10.1）已覆盖其依赖面。

**影响**：`docs/omni_powers_design.md`（§0 加导航表 + §0.2 快照表、原则 7 拆分、§1.2/§3/§5.1/§5.2/§6.3/§7.2/§7.4/§7.5/§8.1/§8.3/§10/§10.1/§11/§12/§13/§13.3/§14.1/§15 多处修订）；`docs/op_decisions.md`（本 D21）。待实现项随 §12 排期，状态见 §0.2 快照表。

## D22：spec 强制——不需要 spec 的需求不进 omni_powers（2026-07-08）

**触发**：用户拍板定位——omni_powers 服务需要 spec 的需求，不需要 spec 的别用这个 skill。

**决策**：spec 是 omni_powers 的硬性入场条件。需求命中三判据任一（跨范围 / 改契约 / 高代价，design §2.1）才进 omni_powers 走 spec 流程；三条全不中（改样式、加索引、改变量名、三行 fix）→ **不进 omni_powers**，用普通开发流程直接做。

**理由**：
- omni_powers 的全部价值（三方对同一份 spec 干活切断同源污染、reviewer 双裁决、Stage 4 验收、merge gate 防篡改）都建立在 spec 之上
- 无 spec 则这些机制全是空转开销——为三行 fix 走 intake / run / review / evaluator 是杠杆错位
- spec 是系统唯一质量单点（原则 1），没有 spec 就没有契约，多 agent 协作失去存在依据

**与现状的关系（待澄清）**：design §2.1 现写"轻量直做门禁：执行主体为 leader 主会话"——即三判据全不中时仍在 heavy 框架内由 leader 直接做（贴测试输出 + commit）。本决策进一步收紧为"连 heavy 都不必进场"。两者张力（轻量直做保留为 heavy 内嵌路径 vs 完全剥离出 omni_powers）留待后续裁决，本条先记定位意图。

## D23：feature 字段是锚点非硬映射——合入靠读 spec 全集判断（2026-07-08）

**触发**：用户纠正 design §2.2 `feature` 字段注释（"对应 op_blueprint/specs/{功能名}.md，closer 合入 baseline 时按此映射"）造成的误导——该措辞让人误以为合入是"工作 spec → 单一生效规格文档"的硬映射。

**决策**：`feature` 字段是**功能名锚点**（提示本次工作主要归属哪个功能），不构成"工作 spec 必须合入到唯一一份 op_blueprint/specs/{功能名}.md"的硬映射。closer 合入时**阅读 op_blueprint/ 全部文档**（specs/*、architecture、domain、conventions、test、baselines/*），判断本次实现内容应归入哪个或哪些文档——可能进一个功能 spec、可能横跨多个功能 spec、可能改 architecture/domain/conventions、可能因被上游覆盖而从某 spec 删除。

**理由**：
- 一次工作 spec 的实现不总落在单一功能边界内——跨功能更新（§2.6 baselines 跨功能更新已有此语义）、非功能维度改动（架构/约定/领域模型）都常见；硬映射会漏掉这些
- blueprint_update.md 本就是"diff 覆盖 op_blueprint 全部文档"形态（§2.6 per-leaf closer 提案），closer 的判断职责已设计在内，feature 字段只是它判断时的锚点之一
- 生效规格是按功能切分的稳定真相，但合入路径不该被一个 frontmatter 字段机械锁定

**分清两件事**：
- **specs 合入**（生效规格文本）：closer 读全集判断，非 feature 硬映射（本决策）
- **baselines 合入**（基准快照文件）：仍按功能名落 `op_blueprint/baselines/{功能名}/`（§2.6）——baselines 是按功能组织的代码资产，feature 字段在此是落点键，这与本决策不冲突

**影响（待改，本条仅记决策）**：design §2.2 `feature` 字段注释需改为"功能名锚点，合入靠 closer 读 op_blueprint 全集判断归属，非单一文档硬映射"；§2.6 per-leaf closer 提案段表述与此一致（已写"diff 覆盖全部文档"），无需改。

## D24：取消 P2——删 partial clone / blob 过滤 / 读取硬隔离 / 构建产物链路 / CI 三接口（2026-07-08）

**触发**：用户问清"读取硬隔离待 P2 blob 过滤 partial clone"与"构建产物链路（CI 三接口 ③）仍 P2"两段含义后，拍板取消整个 P2 计划。

**决策**：从 design 与全部运行时文件删除以下 P2 交付物——
- **evaluator 读取硬隔离**（blob 过滤 partial clone，`git clone --filter=blob:none`）：原计划让被排除路径的 blob 物理不在本地 object store，git 底层命令也取不到。
- **构建产物链路**（CI 三接口 ③，`OP_BUILD_CMD`）：CI 自动构建可运行应用包供 evaluator 操作。
- **CI 三接口契约**（§3.3.1 整节）：①跑测试 ②只读跑 e2e ③构建产物——整段删除，连带 `scripts/op_ci_local.sh` + `hooks/git/post-receive`（仅触发该脚本）一并删。
- per-task 机器证据 CI 化、e2e 集成信号 CI 回传、循环上限门禁化等 P2 能力矩阵条目。

**理由**：
- partial clone 是"同一仓库的浅克隆技术、按路径过滤 blob"，实现复杂且 evaluator 隔离靠 sparse-checkout（advisory 防无意耦合）+ merge gate（写入硬底线）已够用——读取侧硬隔离是过度工程
- 构建产物链路绑死 CI 基建，leader 人工构建后交付 op-eval worktree 即可，不值得为自动化预付一套 CI
- CI 三接口是 P2 整体交付，③ 删则契约不完整，①② 无 design 锚点——一并删，需要时另起独立 CI helper 不绑 design
- 删后 evaluator 隔离防线不变（sparse-checkout advisory + merge gate 硬底线），可信度靠 reviewer 双裁决 + evaluator 独立验收 + merge gate 兜底，与 P1 现状一致

**影响**：design §0 原则 7、§0.1（删读取硬底线段，三层→两层）、§0.2 能力矩阵（删 5 行 P2 条目）、§2.5（结构隔离层去 partial clone 句、删 Bash 读源码审计段）、§3.1（删 e2e 只读信号回传段）、§3.3（机器证据去 CI 代）、§3.3.1（整节删）、§3.4 工作台表格、§4.2（旧 P2 删，旧 P3 并入新 P2）；运行时：op-evaluator.md / oprun SKILL / RULES.md 去引用；删 `scripts/op_ci_local.sh` + `hooks/git/post-receive`。

## D25：删钓鱼审计 + 刻薄化调教循环（2026-07-08）

**触发**：用户拍板删 design 中全部钓鱼审计（phishing audit）相关——P3 交付的"独立验证环境副本 + 植 bug 脚本"，定期植已知 bug 测 evaluator 判别力。

**决策**：删除——
- `scripts/op_phishing_audit.sh`（植 bug 骨架）整文件
- design §2.5 防放水机制第 4 层（刻薄化调教循环/钓鱼审计）、§4.2 P3 钓鱼审计基建段
- 能力矩阵 evaluator baseline 对照评行去"+ 钓鱼审计"
- §0.2 防线映射、各处"刻薄化调教"字样

**理由**：
- 钓鱼审计是"测 evaluator 判别力本身"的持续运营成本，需独立验证环境副本基建——未验证假设前不预付（原则 12 护栏按需付费）
- evaluator 放水靠前三层（hard-pass gate + 预期失败模式 + 破坏检查）已拦低级假测试，深层耦合缺陷无低成本收敛判据
- 删后防放水机制三层（design §2.5），baseline 对照评保留（P2 随验收上线即建）

**影响**：design §2.5（防放水第 4 层删、能力边界句去钓鱼审计）、§2.6 二阶判断、§4.2 P2 段、§0.2 能力矩阵；运行时：op-evaluator.md（删钓鱼审计/刻薄化）；删 `scripts/op_phishing_audit.sh`。

## D26：删自举期例外 + spec 字段清理 + 用词规范（2026-07-08）

**触发**：用户逐项审 design 残留机制，拍板删自举期例外、确认 risk_probe/技术探针已删、统一用词（水位→级别、①②③→顿号）。

**决策**：
- **删自举期例外**：原"P2 首 task 造 evaluator 浏览器基建时，evaluator 还不存在，走人工/降级验收"。理由——evaluator 是 Claude subagent（prompt 文件），Playwright MCP 已就绪，从首 task 起就能标准验收，无鸡生蛋问题。
- **risk_probe / 技术探针**：tasks_list.json 字段 + opspec 信号③ 引用——确认已删（早前轮），本轮扫净残留。
- **用词规范**：全文"水位"→"级别"或删冗余；"①②③"圈号→顿号/分号连接（模板代码块内编号除外）。

**理由**：
- 自举期例外是为不存在的循环依赖打的补丁——evaluator 不是要造的软件，是 prompt
- risk_probe 字段无人消费，是死字段
- "水位"是隐喻负担，"级别"直白；圈号数字在 markdown 渲染外（纯文本流、grep）不可读

**影响**：design §2.5（自举期例外句删）、§4.2 P2（op-evaluator 浏览器基建作为自举第一 task 段删）、§0.1/§0.2/§2.5（水位→级别）、全文圈号替换；运行时：tasks_list.json 模板（删 risk_probe）、opintake/oplintake/opspec SKILL、op-evaluator/op-reviewer/oprun/oplrun SKILL、RULES.md、hooks/README（①②③→顿号）。

## D27：review.md 两轮审阅处置——硬门闭合 + 闸门 C 批量化 + 状态机校正（2026-07-08）

**触发**：`docs/review.md` 两轮架构审阅（威胁模型诚实度获肯定，问题集中在 merge gate 硬度/merge 时序/状态机一致性）。处置清单存 `docs/review_response.md`（E1-E3 审阅错误 / A1-A25 照改 / D1-D9 用户定夺）。

**决策（D1-D9 用户裁定）**：
- **D-1=A**：evaluator 验收挪到 squash-merge 前（task 分支上验，构建产物从分支构建）。原"merge 后验收"致未验收代码进主分支、下游踩着切，且修复回流同分支再 squash 靠三方合并侥幸。
- **D-2=C**：执行期 spec-delta 维持现状（leader 自批 + 闸门 C 事后报），不升级人审——守原则 3"执行期不设人工阻塞点"。
- **D-3=A**：闸门 C 批量化（攒一批 task 的 closer 提案一次审），per-task 中断压到 1 次；快速审只读自然语言，>5 条变更或跨功能 baseline/e2e 升级详细审。
- **D-4=A**：非行为型 task（接口先行/脚手架/纯内部重构）免派 evaluator——无用户可观察行为，hard-pass gate 无从落地；evaluator 是最贵护栏，与原则 12 按需付费一致。
- **D-5=B**：baseline 功能名维持 closer 判断（D23 不变），接受漂移风险。
- **D-6=A**：tasks_list.status 机读值改 ASCII（pending/ready/in_progress/reviewing/closing/done/suspended/blocked），opstatus 渲染层映射中文——跨平台 locale 无关，Windows Git Bash/PowerShell 下 jq/grep 稳定。
- **D-7=A**：lite 改共享 scripts 目录（install.sh 装 `~/.claude/scripts/omni_powers/`），消灭 per-skill 副本同步（build_lite.sh 及三份 op_check_env 互检淘汰）。
- **D-8=自定义**：e2e 路径初始化时问用户，记项目级 `docs/omni_powers/config`（`OP_E2E_DIR=...`），脚本读此不硬编码；用户项目已有顶层 e2e/ 时 init 探测提示。
- **D-9=B**：不上 merge gate trailer 强制，§0.1 诚实声明信任根——硬底线之"硬"以 leader 执行协议为前提，leader 失守靠 git 历史审计 + 闸门 A/C 人审。

**A1-A25 照改（硬门闭合三件最关键）**：
- **A1 review.md 单写者化**：verdict 由 leader 落盘主分支 review.md（task 分支不许碰，merge gate 白名单 REJECT）；Fix-N 并入 report.md。消除"verdict 落被监督者可写域"违反第一原则 + 双物理副本 squash-merge 冲突。
- **A2 merge gate 黑名单→白名单**：task 分支允许触碰 = workset ∪ `tasks/{TID}/report.md` ∪ 结构层测试路径，其余 REJECT。比枚举受保护路径严、简，越界检查从 advisory 升硬。
- **A3 tasks_list.json 读取矛盾**：dispatch 脚本提取 workset/depends_on 注入 prompt/review-package，tasks_list.json 不挂给任何 subagent。
- **A4 spec 变更子流程 task 处置**：不引入 cancelled 终态——改 spec → 更新当前 task 记录 → 扫后续所有 task 检查受影响逐个更新 → 从当前 task 重新跑 implementer（同 TID，不重拆）。frontmatter approved 后冻结，状态只走 tasks_list；"清出"统一改"标完成"。
- **A5 TID 四位数**：T001→T0001 风格全文统一（原 T01/T001 混用，宽度不统一在 T9/T10 处坏）。
- **A6 closer gate**：closer 返回后机械校验触碰路径 ⊆ {decisions.md, issues/, acceptance/{TID}/}，越界 reset。
- **A7 落盘者赋 P 统一协议**：reviewer 范围外发现写返回文本暂存段 → leader 收口落 issues 赋 P（对齐 evaluator 协议）。
- **A8-A11 lite 机械洞**：oplrun 收口按实际 diff add（非预估 workset）/ dispatch 记 HEAD sha 锚定 reviewer diff（防 implementer 自行 commit 致 diff 空）/ specs/ git diff 非零即停（spec 写保护升机械）/ 验收后 git status 干净才归档。
- **A12 leader 亲跑收敛**：heavy 侧"亲跑验证"统一为"脚本跑 + 单行 verdict 回传"（对齐 lite op_read_verdict），不把完整测试输出/diff 灌进主会话。
- **A13 subagent 重派协议**：崩溃/超时按 report 累积总结判恢复点（复用分支续做 vs 重切重做）。
- **A14 阻塞 task 归因沉淀**：review/验收到顶标阻塞时，leader 亲提红灯归因 append decisions.md（blocked-attribution），不让归因停在 report.md。
- **A15 spec-delta 受影响清单**：delta 记录强制列受影响 spec/task 清单，脚本 grep 核对覆盖。
- **A16 eval_brief 剥探索结论**：组装时剥 spec"设计探索结论/已知坑"段（实现路径蒸馏），留条件强制 + 可测性契约。
- **A17 能力矩阵补 e2e trailer 行**；**A18/D-9 §0.1 信任根诚实声明**；**A23 闸门 C 升级阈值定义（>5 条）**；A19-A25 编辑级（fix 枚举去重/防防水衍字/depends_on 措辞/closer 重复行/归因(b)/流程图箭头）。

**清标记 + T0001**：处置落地后清 design 全文 review 追踪标记（A1-A25/D1-D9/审1-X 不留在设计文档），TID 全文统一四位 T0001。

**影响**：design.md（§0-§5 全文，硬门闭合 + 闸门 C 批量 + 状态机校正 + ASCII 机读 + 共享脚本 + e2e config + T0001 + 清标记）；运行时（agents/skills/scripts/RULES/docs_template 同步关键冲突——D-1 顺序/A1 单写者/A5 T0001/D-7 共享目录/D-6 模板 ASCII/归因(b)/op-evaluator merge 前验；脚本实现细节——op_merge_gate 白名单逻辑、op_closer_gate 新建、oplrun 收口 A8/A9/A11、opinit/oplinit D-8 e2e config——属 P1 实现工作，design 已正本清源）。

## D28：将 OP 导航文件改为 op_readme.md / op_index.md（2026-07-13）

**触发**：`docs_template/omni_powers/README.md` 与 `index.md` 与宿主同名文件产生冲突——当 `$OP_DOCS_DIR=docs` 时需 managed block 共存，增加了配置、生成、迁移和卸载的复杂度。

**决策**：模板文件重命名为 `op_readme.md` 和 `op_index.md`，升级为 OP 独占资产（与 `profile`、`op_blueprint/` 同级），不再使用 managed block。`$OP_DOCS_DIR=docs` 共享根下，只有 `.gitignore` 继续使用 managed block。

**理由**：
- `op_` 前缀明确归属，避免与宿主 `README.md`、`index.md` 同名冲突
- managed block 是"共享"约定，一旦文件不再共享，就不应继续维护
- 旧版 managed block 清理作为兼容路径保留在迁移和卸载中，现有项目升级不丢失内容

**迁移不变量**：
- `docs` 共享根：旧 managed block 内容提取到 `docs/op_*.md`，宿主文件只保留非 OP 内容
- 非 `docs` 根：旧完整文件视为 OP 独占，内容迁为 `op_*` 后删除旧名
- 新旧内容不一致时 fail closed，不改任何文件
- 运行 `op_configure_project.sh` 触发，current==target 时执行原地升级

**影响**：`docs_template/omni_powers/op_readme.md`（rename + 自引用）、`docs_template/omni_powers/op_index.md`（rename）、`scripts/op_paths.sh`（变量值）、`scripts/op_configure_project.sh`（owned 数组 + nav upgrade）、`uninstall.sh`（删除新文件 + 保留旧 block 清理）、`skills/opinit/SKILL.md`（生成契约）、`CLAUDE.md`、`docs/omni_powers_design.md`（所有权模型）、`tests/scripts/op_configure_project.bats`、`tests/scripts/uninstall.bats`。

## D29：agent 不注册全局，skill 禁止模型自触发（2026-07-14）

**触发**：全局注册 `op-*` agents 会进 `/agents` 列表，Claude 可能在非 OP 会话按 description 自动委派；skill 的 description 也会自动触发。

**决策**：
1. **agents 只放 `$OP_HOME/agents/` 作提示词模板**，`install.sh` 不再软链到 `~/.claude/agents/`；重装时清理旧软链
2. **派发协议**：`Read` 模板 → `subagent_type: "general-purpose"` + `prompt = 模板全文 + brief`（禁止 `subagent_type: "op-*"`）
3. **全部 skill** `disable-model-invocation: true`——只响应用户 `/` 调用；内部 `opspec`/`opred` 另加 `user-invocable: false`

**影响**：见 D30 安装分层后的最终形态。

## D30：全局仅 opinit/oplinit，业务 skill 项目级 bind（2026-07-14）

**触发**：全局装全部 op\* skill 会在非 OP 项目污染 `/` 菜单与 description 池；又不想引入统一 `/op` 路由器。

**决策**：
1. **`install.sh` 全局只软链 `opinit` + `oplinit`**，并清理旧版全局业务 skill
2. **`op_bind_project_skills.sh --profile heavy|lite`**：init 第一步把对应 skill 软链到项目 `.claude/skills/`（含本侧 init）
3. **heavy 集**：opinit opintake oprun opstatus optriage opspec opred
   **lite 集**：oplinit oplintake oplrun opstatus optriage opspec opred
4. 不设 `/op`；不装 agents 到任何发现路径
5. **所有权**：覆盖/删除 skill 前必须是 OP 软链（`op_asset_ownership.sh`）；非 OP 同名路径 die 或 SKIP
6. **profile 互斥在 bind 前**：冲突零写入
7. **软链失败 die**，无 cp fallback

**理由**：bootstrap 需要可发现的 init 命令，故全局保留两个入口；业务 skill 仅已 init 项目可见。软链 OP_HOME 便于升级。

**影响**：`install.sh` / `uninstall.sh` / `scripts/op_bind_project_skills.sh` / `op_asset_ownership.sh` / `opinit`/`oplinit` SKILL / CLAUDE / RULES / design §4.1 / tests。


