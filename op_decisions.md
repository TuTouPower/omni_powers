# Harness 决策记录

> 记录架构和设计决策及其依据。最终规则见 RULES.md。

## D1：Agent Team vs Workflow（2026-06-25）— ⚠️ 已被 D4 取代

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

## D4：放弃 Workflow，全面使用 Agent Team（2026-06-25）

**变更**：review 从 Workflow（task_review.js）迁移到 Agent Team（code-reviewer + test-reviewer）。

**理由**：
- Workflow 每次重新填充上下文，token 成本高
- Agent Team 跨 task 复用上下文，FAIL 轮保留状态
- Workflow 的 schema 强制优势可通过 teammate 输出 review_*.md 首行 verdict 实现
- teammate 输出 review_*.md，leader 读文件判 verdict，兼得复用和结构化

**影响**：
- `docs/harness/workflows/` 已删除
- review 流程改为：leader SendMessage 派 review → code-reviewer/test-reviewer 写 review_*.md → leader 读首行 verdict

## D5：放弃上下文监控，全面复用（2026-06-25）

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

## D7：test-reviewer 使用 Round 格式（2026-06-25）

**变更**：test-reviewer 从 10 段通用测试审查报告改为 Round N-1/N-2 轮次结构，与 code-reviewer 格式一致。

**理由**：模板 `review_test.md` 定义了 Round N-1/N-2 结构，但 test-reviewer agent 输出 10 段通用报告，格式完全不匹配。统一格式后 leader 判定逻辑一致，coder FAIL 轮处理也一致。

## D8：删除 agent frontmatter model 字段（2026-06-25）

**变更**：三个 harness agent 定义文件（op-coder、op-code-reviewer、op-test-reviewer）删除 frontmatter 中的 `model` 字段。

**理由**：spawn 时 Agent 工具不读 frontmatter 的 model，必须显式传 `model` 参数。保留 model 字段会误导读者以为它会生效。

## D9：保留 op-debt2tasks HARD-GATE（2026-06-25）

**决策**：不改 op-debt2tasks SKILL.md 中的 `<HARD-GATE>` 标签。

**理由**：op-generate-spec 和 op-generate-plan 已注册到本项目的 `.claude/` 目录，Skill 工具可以调用。手动写 spec/plan 容易格式不一致、跳过自审流程，HARD-GATE 强制走标准化流程。

## D10：标记文件为完成判定唯一真相源，去双通道（2026-06-26）

**变更**：取消"双通道确认"（SendMessage + 标记文件必须同时满足）。完成判定以标记文件为唯一依据，SendMessage 降级为加速信号。

**规则**：
- teammate **先 touch 标记文件、再 SendMessage**（文件先落盘，消息丢了也能恢复）
- 标记文件路径：`.worktrees/{TID}/.harness/signals/` 下，不在 git 跟踪区
- leader 每次主循环迭代前扫标记文件。文件存在即完成，不依赖 SendMessage
- 扫到 `coder_done` → 删文件 → 派 review
- 扫到 `reviewer_code_done` + `reviewer_test_done` 同时存在 → 删两文件 → 读 verdict
- 全在等时 `ScheduleWakeup(180s)` 兜底轮询
- FAIL 轮重新派 coder 前标记文件已在上一轮处理时删空

**理由**：
- SendMessage 跨 agent 通信不是 100% 可靠——消息可能丢失
- 双路并行等待引入竞态（消息和文件哪个先到）和重复判定问题
- 标记文件在 worktree 磁盘上，compact/crash 后也不丢——天然覆盖恢复场景
- SendMessage 仍保留：到达时触发提前扫描，省去 3 分钟等待
- 删除标记文件确保下一轮不会误读上一轮的旧标记

## D13：放弃 task 拆分（2026-06-26）

**变更**：删除 task-splitter subagent，删除所有 task 拆分逻辑。

**理由**：
- task 拆分是运行时动态行为，无法在 /op-start 的循环中可靠执行——拆后 tasks_list.json 变化，循环已跑过半
- task-splitter 要读原 spec/plan 全文、切片、重写——中间内容大量挤占 leader 上下文
- 实际使用中需要拆分的场景极少。真需要拆时，用户直接 /op-task 拆好了再 /op-start

**影响**：
- 删除 `agents/op-task-splitter.md`
- RULES.md / SKILL.md / CLAUDE.md 中所有相关段落删除

## D14：放弃 coder 并发（2026-06-26）

**变更**：只保留 coder，删除 coder-2/3。所有 task 串行执行。

**理由**：
- worktree 并发收口时的合并冲突、控制平面竞争、FF 策略选择——复杂度远超收益
- omni_powers 自身是单项目开发，不存在 trivially parallelizable 的 task
- 串行简化整个系统：无同层波次、无下游顺延、无并发 merge 冲突

**影响**：
- 花名册 coder/2/3 → coder
- RULES.md / SKILL.md 中所有"并发"、"波次"、"同层"段落重写
- DAG 仍保留给串行 task 的拓扑顺序计算

**变更**：删除并发判定算法（从 plan.md 提取文件列表→算冲突图→定联通分量）。并发直接按 DAG 拓扑同层，上限 3，不做文件冲突预检。

**理由**：
- worktree 隔离已防止互相覆盖，不存在并发写同一个文件的问题
- 合并冲突在收口时由 leader 按依赖优先规则解决，不是灾难
- 文件冲突预检依赖 AI 读 plan.md"文件结构"段提取路径——格式不可靠，脆弱
- 同层直接并发的逻辑可全脚本化（dag_gen.sh 已算拓扑），无需 AI 推理

## D12：代码平面 vs 控制平面分离，一个 task 两个 commit（2026-06-26）

**变更**：工作区文件分为两层——代码平面（per-task，进 feat 分支）和控制平面（全局共享，仅 leader 在主 repo 串行写）。收口从"worktree 内一次 commit 包含所有文件"改为两阶段：A. closer 在 worktree 做 per-task 操作 → leader commit 代码提交 → merge 回主线；B. leader 在主 repo 串行更新控制平面文件 → harness commit。

**规则**：
- 代码平面：`src/`、`tests/`、`docs/op_execution/tasks/{TID}/`、`docs/op_record/tasks/{TID}/`
- 控制平面：`tasks_list.json`、`specs/{feature}.md`、`progress.md`、`decisions.md`、`tech_debt.md`、`leader_checkpoint.md`
- closer 绝不碰控制平面文件，输出 `closer_output` 供 leader 使用
- leader 在主 repo 串行处理收口，A 阶段 merge 后，B 阶段改控制平面

**理由**：
- 并发波次两个 worktree 各自有基线的 tasks_list.json / specs 等共享文件，各自改→merge 必冲突
- 控制平面文件应当在唯一位置（主 repo）由唯一写入者（leader）串行操作
- 两个 commit 语义清晰：代码 commit 是 task 产出，控制平面 commit 是收口记录
