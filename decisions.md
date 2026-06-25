# Harness 决策记录

> 记录架构和设计决策及其依据。最终规则见 agent_protocol.md。

## D1：Agent Team vs Workflow（2026-06-25）

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

## D6：一个 task 一次 commit，hash 回填延迟（2026-06-25）

**变更**：收口只有一次主 commit。progress.md 和 leader_checkpoint.md 中的 `<待回填>` hash 不单独 commit，延迟到下一个 task 收口时一并回填提交。

**理由**：收口主 commit + hash 回填单独 commit = 两次 commit，违反"一个 task 一次 commit"原则。合并到下一个 task 的 commit 中，保持一个 task 一次 commit 的简洁语义。

## D7：test-reviewer 使用 Round 格式（2026-06-25）

**变更**：test-reviewer 从 10 段通用测试审查报告改为 Round N-1/N-2 轮次结构，与 code-reviewer 格式一致。

**理由**：模板 `review_test.md` 定义了 Round N-1/N-2 结构，但 test-reviewer agent 输出 10 段通用报告，格式完全不匹配。统一格式后 leader 判定逻辑一致，coder FAIL 轮处理也一致。

## D8：删除 agent frontmatter model 字段（2026-06-25）

**变更**：三个 harness agent 定义文件（harness-coder、harness-code-reviewer、harness-test-reviewer）删除 frontmatter 中的 `model` 字段。

**理由**：spawn 时 Agent 工具不读 frontmatter 的 model，必须显式传 `model` 参数。保留 model 字段会误导读者以为它会生效。

## D9：保留 debt-to-tasks HARD-GATE（2026-06-25）

**决策**：不改 debt-to-tasks SKILL.md 中的 `<HARD-GATE>` 标签。

**理由**：spec-generator 和 plan-generator 已注册到本项目的 `.claude/` 目录，Skill 工具可以调用，不需要注册到 `~/.claude/skills/`。
