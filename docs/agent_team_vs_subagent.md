# Agent Team vs Sub Agent：深度对比分析

> 基于 Claude Code 官方文档（v2.1.178）、Anthropic 工程博客、社区实测数据综合整理。
> 2026-06-27

---

## 一、定义

### Sub Agent

Sub Agent 是主会话派出的**独立工人**。有独立上下文窗口，干完活只把结果摘要返回主会话。中间过程（读取文件、搜索、推理）全部留在子代理里，不污染主线。

```
主 Agent → 派 Sub Agent → 子代理独立干活 → 结果返回 → 子代理销毁
           ↘ 派 Sub Agent → 子代理独立干活 → 结果返回 → 子代理销毁
```

核心价值：**上下文隔离 + 结果压缩**。

### Agent Team

Agent Team 是多个**完整 Claude Code 实例**组成的协作团队。一个 Team Lead + N 个 Teammate，通过共享任务列表 + 邮箱消息系统协调工作。Teammate 之间可以直接通信，不经过 Leader。

```
Team Lead ←→ 共享任务列表 ←→ Teammate A
    ↕                            ↕ (SendMessage)
Teammate B ←→ 共享任务列表 ←→ Teammate C
```

核心价值：**对等通信 + 持续协作**。

---

## 二、架构对比

| 维度 | Sub Agent | Agent Team |
|------|-----------|------------|
| **拓扑结构** | 星形（主 Agent 是唯一协调者） | 网状（Teammate 可以直接互发消息） |
| **上下文** | 独立上下文窗口，结果返回主会话 | 独立上下文窗口，完全独立 |
| **通信方式** | 只能向主 Agent 汇报，不能互相通信 | Teammate 之间直接 SendMessage |
| **任务协调** | 主 Agent 统一管理 | 共享任务列表，自主认领 |
| **生命周期** | 任务结束即销毁 | 跨 task 常驻，持久运行 |
| **状态** | 无状态，每次调用重新开始 | 有状态，上下文跨任务累积 |
| **可重复性** | Worker 定义可复用，执行是一次性的 | Teammate 持续运行，可被多次唤醒 |
| **嵌套** | 可嵌套最多 5 层（v2.1.172+） | 不能嵌套（Teammate 不能再开自己的 Team） |
| **Team 数量** | N/A（没有 Team 概念） | 每会话一个 Team |
| **成熟度** | 稳定，默认开启 | 实验性，需设环境变量 |

---

## 三、通信机制详解

### Sub Agent 通信

```
主 Agent 调用 Agent 工具 → 子代理启动 → 独立上下文工作 → 最终消息返回主 Agent
```

- 信息流：单向。主→子（任务指令），子→主（结果摘要）。
- 中间过程对主不可见。子代理读了 30 个文件，主只看到 200 token 的结论。
- 主 Agent 是唯一协调点。所有决策、汇总在主线程完成。
- 多个子代理可并行运行，但它们彼此不知道对方存在。

### Agent Team 通信

```
文件系统即状态后端：
~/.claude/teams/{team-name}/
├── config.json          # 团队配置：成员列表、角色
├── members/
│   ├── team-lead/inbox/ # 收件箱
│   ├── teammate-a/inbox/
│   └── teammate-b/inbox/
└── tasks/
    ├── task-001.json    # 任务元数据：状态、依赖、所有者
    └── task-002.json
```

- **任务列表**：三态（pending/in_progress/completed），支持依赖关系。文件锁防竞态。
- **邮箱系统**：Teammate 之间通过文件收件箱通信。SendMessage 工具追加 JSON 到目标收件箱。
- **消息自动投递**：收到消息自动出现在对话中，不需要轮询。
- Teammate 可以自我组织：认领任务、标记完成、给其他 Teammate 发消息。

---

## 四、Token 成本

两种说法的前提不一样，先拆清楚。

### 官方文档的说法

> "Agent teams use significantly more tokens than a single session. Each teammate has its own context window, and token usage scales with the number of active teammates."
>
> "Token cost — Subagents: Lower (results summarized back to main context) / Agent teams: Higher (each teammate is a separate Claude instance)"

**单个对比**：一个 Sub Agent 比一个 Teammate 省 token，因为 Sub Agent 只把压缩结果返回主线，Teammate 是完整 Claude Code 实例持续消耗。

### MindStudio 实测的说法

> 10 个 Agent 各产生 2,000 token 输出时，Team 整体可以比 Sub Agent 便宜 3-5 倍。

**大规模并行对比**：Sub Agent 模式下所有结果汇聚到编排器，编排器上下文随结果累积膨胀（最终 20,000+ token）；Team 模式下每个 Agent 只加载自己需要的上下文（2,000-4,000 token）。总量 Team 更高，但没有单一瓶颈点，且编排不卡。

### 统一结论

**规模决定谁更省。** 不矛盾——引用不同前提：

| 规模 | 谁更省 | 原因 |
|------|--------|------|
| 小规模（1-5 Agent） | **Sub Agent** | 压缩返回、无 Team 常驻开销 |
| 中规模（5-10 Agent） | 差不多 | 压缩收益 ≈ 常驻开销 |
| 大规模（10+ Agent） | **Agent Team** | 编排器不是瓶颈，分布式上下文 |

**omni_powers 属于小规模**（coder + code-reviewer + test-reviewer + closer = 2-4 个并行），所以 Sub Agent 更便宜。

---

## 五、已知限制

### Sub Agent 限制

- 不能互相通信（设计如此，不是缺陷）
- 结果必须回主 Agent 汇总
- 没有跨任务记忆（每次调用重新开始）

### Agent Team 限制（官方标注）

| 限制 | 详情 |
|------|------|
| 无会话恢复 | `/resume` 和 `/rewind` 不恢复 in-process teammate |
| 任务状态延迟 | teammate 有时不标记任务完成，阻塞后续 |
| 关闭缓慢 | teammate 完成当前请求后才关闭 |
| 每会话一 Team | 不能创建多个命名 Team 或跨会话共享 |
| 不能嵌套 | teammate 不能再创建自己的 teammate |
| Lead 固定 | 不能提升 teammate 或转移领导权 |
| 权限设定 | 所有 teammate 以 Lead 的权限启动，不能设 per-teammate 权限 |
| 分割窗格需 tmux | 默认 in-process 模式任何终端可用，但 split-pane 需要 tmux 或 iTerm2 |

---

## 六、适用场景

### 用 Sub Agent 的场景

1. **并行探索**：搜索代码库 10 个不同方向，只需结论
2. **重量级上下文任务**：读 30 个文件分析，中间过程不需要保留
3. **专业审查**：安全检查、代码审查——独立上下文 + 结果明确
4. **Fire-and-forget**：派一个任务，等结果，不关心过程
5. **短 pipeline**：少于 5 个任务，编排器上下文不会过大
6. **需要审计追踪**：所有决策流经主 Agent，易于日志记录和回放
7. **动态任务分解**：需要边看结果边决定下一步

### 用 Agent Team 的场景

1. **竞争假设调试**：5 个 Agent 同时调查 5 种可能，互相挑战结论
2. **跨层协调**：前端、后端、测试同时改，各管各的
3. **多维度并行审查**：代码审查 + 测试审查 + 安全审查 + 性能审查并行
4. **需要 Agent 之间的持续对话**：不是简单汇总，而是辩论和协作
5. **大规模并行**：10+ 独立子任务，避免单一编排器成为瓶颈
6. **持续项目**：Agent 需要记住之前做过什么，跨任务复用上下文

### 混合方案

实际复杂系统推荐混合使用：
- 顶层用 Sub Agent 模式（编排器做高层决策）
- 需要并行的阶段委托给 Team（共享任务列表 + 对等通信）
- 编排器只收集 Team 的最终合成输出，不收集每个 Agent 的输出

---

## 七、对 omni_powers 的适用性分析

### omni_powers 当前设计

```
leader（主会话）
  ├─ op-coder（Agent Team，haiku）    —— 写代码
  ├─ op-code-reviewer（Agent Team，sonnet）—— 审代码
  ├─ op-test-reviewer（Agent Team，sonnet）—— 审测试
  └─ op-closer（Sub Agent，haiku）    —— 机械收口
```

### 工作流特征

1. **串行为主**：op-coder → review（并行）→ closer → 下一个 task
2. **task 之间独立**：每个 task 在自己的 worktree 里，不共享上下文
3. **通信简单**：leader 派活，teammate 通过标记文件通知完成
4. **不需要 teammate 互聊**：op-code-reviewer 和 op-test-reviewer 各自审各自的，不需要通信
5. **跨 task 复用上下文有价值**：同类型 worktree 的上下文可以复用

### 分析

**用 Agent Team 的理由（当前设计）：**
- 跨 task 存活，上下文复用（D4, D5 决策依据）
- FAIL 轮唤醒同一实例，保留上一轮上下文
- op-coder、reviewer 长期运行，不需要每次 task 重新 spawn

**用 Sub Agent 的理由：**
- 工作流本质是 leader 派活→收集结果的星形拓扑
- reviewer 之间不需要通信
- 跨 task 复用上下文其实没那么重要——每个 task 是新 worktree，新代码
- Sub Agent 更成熟稳定，不需要实验性环境变量
- Token 成本更低
- 可以真正并行派 review（Agent Team 也能，但 Sub Agent 更轻量）
- FAIL 轮：把 review 结果发给新的 Sub Agent 即可，不需要"恢复同一实例"

### 关键问题

1. **跨 task 上下文复用真的重要吗？**
   - 每个 task 在新 worktree 里，代码完全不同
   - op-coder 每次面对新的 spec/plan，上一轮的代码上下文可能反而是干扰
   - reviewer 每次审不同的代码，不需要记住上次审了什么

2. **FAIL 轮需要同一实例吗？**
   - 把 FAIL 内容和 review_*.md 发给 op-coder（新 Sub Agent），一样能修
   - Sub Agent 重新 spawn 的成本远低于 Team 常驻的 token 成本

3. **并行 review 用 Agent Team 还是 Sub Agent？**
   - 两者都能做到并行派发
   - Sub Agent：同步等待 or 后台运行，结果返回主会话
   - Agent Team：SendMessage 并行派发，标记文件通知完成
   - 效果一样，但 Sub Agent 更简单

---

## 八、Sub Agent 的已知致命 Bug："Tool result missing due to internal error"

Sub Agent 不是完美的。它有一个**已知且未修复**的严重 bug：子代理内部出错后**静默挂起**，不给父代理任何错误信号。

### Bug 本质

当 Sub Agent 内部发生错误（Bash 调用失败、MCP 工具异常、内部状态损坏等），它可能：

1. 返回 `[Tool result missing due to internal error]` 给父代理
2. **不传播任何 tool-level error**——父代理收到的不是一个错误，而是一个看似正常的"部分结果"
3. 父代理不知道子代理已崩溃，**无限等待**——从用户视角就是 Claude Code 挂了
4. 没有任何超时机制、没有重试路径、没有可见异常

更严重的变体（#65423）：≥3 个并行子代理时，部分子代理变成**永久僵尸**——工作已做完，但永不终止、不可 kill、忽略所有输入队列、存活 8 小时以上，只有重启会话才能清除。

### 四个独立缺陷（#63678 详细分析）

| 缺陷 | 说明 |
|------|------|
| 内部错误本身 | Bash 传输路径间歇性丢弃结果，底层 shell 可能根本没运行 |
| 错误不自报来源 | 只有裸字符串 `[Tool result missing due to internal error]`，不知道哪个组件产生的 |
| 零诊断信息 | 无退出码、无 PID、无耗时、无日志路径、无关联 ID |
| 主循环挂起 | CLI 收到内部错误后继续等更多输出，Agent 不知道要重试/放弃/等待 |

### 三个相关 Issue

| Issue | 标题 | 状态 | 平台 |
|-------|------|------|------|
| [#56869](https://github.com/anthropics/claude-code/issues/56869) | 子代理返回 `Tool result missing due to internal error` 导致父代理静默挂起——无错误传播 | **已关闭** (not_planned, 2026-06-10) | Windows |
| [#63678](https://github.com/anthropics/claude-code/issues/63678) | `[Tool result missing due to internal error]` 无来源、无诊断、挂死 Agent | **仍开启** (stale) | macOS |
| [#65423](https://github.com/anthropics/claude-code/issues/65423) | 并行子代理完成工作后永久卡住——不可 kill、忽略队列输入、8h+ 僵尸 | **仍开启** (stale) | Windows |

关键信号：**#56869 被关了但没修**——Claude Code 团队标记为 `closed/not_planned`，意味着官方没有计划修复这个错误传播问题。

### 对 omni_powers 的影响

如果用 Sub Agent 替代 Agent Team：

1. **coder 内部出错**：leader 永远收不到通知，一直等 `coder_done` 标记文件 → **永久阻塞**
2. **reviewer 内部出错**：同上，等不到 `reviewer_code_done` / `reviewer_test_done`
3. **并行派 review 时**：≥3 个并行子代理时 bug 触发概率更高（#65423）
4. **无法区分"正在干活"和"已死"**：标记文件没出现可能是还没干完，也可能是已崩溃

### 缓解措施

如果必须用 Sub Agent，需要加上防御层：

1. **标记文件 + 超时双保险**：leader 不只看标记文件，还要设超时。超时后用 `ctx_search` 查 session 日志确认 teammate 是否还活着
2. **文件系统验证**：不依赖子代理报告——直接检查文件系统验证工作是否完成
3. **限制并行数量**：≤2 个并行子代理，降低 #65423 触发概率
4. **重试机制**：超时后 kill 旧子代理，重新 spawn

---

## 九、结论

| | Sub Agent | Agent Team |
|---|---|---|
| **omni_powers 适合度** | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| **稳定性** | ~~生产就绪~~ 有未修复致命 bug | 实验性，有已知限制 |
| **复杂度** | 低（星形拓扑） | 高（网状拓扑 + 任务列表 + 邮箱） |
| **Token 成本** | 小规模更便宜（omni_powers 属于此类） | 常驻开销，小规模更贵 |
| **跨 task 上下文** | 不需要（每次 task 新上下文更好） | 支持，但 omni_powers 场景价值有限 |
| **FAIL 轮恢复** | 重新 spawn 即可 | 唤醒同一实例 |
| **并行 review** | 完美支持（但并行有 bug 风险） | 完美支持 |
| **错误可见性** | **Bug：内部错误可能静默丢失** | 标记文件机制可检测（文件不出现=异常） |

**结论变了：两个方案都不完美。**

- **Agent Team**：实验性、更贵、更复杂，但标记文件机制给了 leader 一个"超时兜底"的检测手段——文件不来就是异常
- **Sub Agent**：更简单、更便宜、更成熟，但**致命 bug 未修复**——子代理崩溃时 leader 可能永久等待

**建议：当前保持 Agent Team 方案不变。** 核心原因不是 Agent Team 更好，而是 Sub Agent 的错误传播 bug（#56869 closed/not_planned + #63678 仍开启）让依赖 Sub Agent 做关键路径任务风险太高。等这个 bug 修复后再重新评估。

---

## 十、对比 Superpowers

[Superpowers](https://github.com/obra/superpowers) 是目前最成熟的 Claude Code 插件体系（v6，MIT），由 Prime Radiant 维护。以下是和 omni_powers 的深度对比。

### Superpowers 架构

Superpowers 是一套**skills 集合**，通过 `using-superpowers` skill 在 session 启动时自动加载，之后按场景自动触发对应 skill。

核心工作流链：

```
brainstorming → writing-plans → subagent-driven-development
                                  ├─ implementer subagent（per task）
                                  ├─ task reviewer subagent（per task，双维度：spec 合规 + 代码质量）
                                  ├─ fix subagent（Critical/Important 发现时）
                                  └─ final code review subagent（全分支审查，最后一道）

→ finishing-a-development-branch（验证→合并/PR）
```

**关键设计决策：**

1. **全部用 Sub Agent**：implementer、task reviewer、fixer、final reviewer 全部是 `general-purpose` subagent。不用 Agent Team。
2. **Fresh subagent per task**：每个 task 新建一个 subagent，不准复用，确保上下文隔离。
3. **文件交接而非 Paste**：task brief、report、diff 全部写成文件传给 subagent，不塞进 prompt。控制器自己的上下文保持精简。
4. **双维度 review**：每个 task 审查有两个维度——spec 合规（Missing/Extra/Misunderstood）+ 代码质量。两个 verdict 都通过才算 task 完成。
5. **进度账本**：`.superpowers/sdd/progress.md` 记录每个 task 的完成状态和 commit hash。compact 恢复不靠记忆，靠账本。
6. **模型分层**：机械实现用便宜模型，review 用标准模型，最终全分支审查用最强模型。

### 和 omni_powers 逐项对比

| 维度 | Superpowers | omni_powers |
|------|-------------|---------|
| **定位** | 通用 skills 插件（零依赖） | 项目级多 agent 编排系统 |
| **安装** | `/plugin install superpowers@claude-plugins-official` | git clone + install.sh（SessionStart hook） |
| **可移植性** | 25+ AI 工具（Claude Code, Codex, Cursor, Gemini CLI...） | Claude Code 专用（Agent Team + SendMessage + worktree） |
| **Agent 模型** | 全部 Sub Agent（general-purpose） | 混合：3 个 Agent Team + 1 个 Sub Agent |
| **Task 并发** | 串行（明确禁止并行 implementer） | 串行（每个 task 一个 coder，但 review 可以并行） |
| **Review 模型** | 双维度 per task（spec+quality）+ 最终全分支 review | 并行双 reviewer（code + test），一个 task 一次 review |
| **FAIL 处理** | 发 fix subagent → 重新 reviewer review | 唤醒同一 coder → 重新并行 review，max 3 轮 |
| **工作隔离** | Git worktree（`using-git-worktrees` skill） | Git worktree（per task） |
| **上下文管理** | Fresh subagent + 文件交接（文件不污染控制器上下文） | Agent Team 跨 task 复用上下文 |
| **进度恢复** | `progress.md` 账本（记录 commit hash） | `tasks_list.json` + `leader_checkpoint.md` |
| **控制平面** | 无。所有状态靠 git 和文件系统 | 有。tasks_list.json / specs/ / progress.md / tech_debt.md |
| **质量门** | spec 合规 + 代码质量（per task）+ 全分支审查 | 双 review PASS + FAIL 轮 + 阻塞传播 + 下游跳过 |
| **文档归档** | 无。git 历史即记录 | 三态文档 + specs 累积 + task 归档 |
| **Spec 系统** | 无独立 spec 文件，需求和 plan 合在一起 | 独立 spec → plan → task 工作区 → 闭环后整理进 specs/ |
| **人机交互** | 循环中不打断人，除非 BLOCKED 或全完成 | 自治循环，不打断人，除非全完成或全阻塞 |
| **Token 优化** | 极简。控制器上下文保持精简，大量文件交接 | 中等。Agent Team 常驻有开销 |

### Superpowers 做对了什么（omni_powers 没做的）

1. **文件交接模式**：task brief → report file → diff file，全部走文件，控制器 prompt 永远精简。omni_powers 没有这个——SendMessage 里的内容直接进上下文。
2. **模型分层省钱**：机械任务用 haiku/便宜模型，只有最终全分支审查用最强模型。omni_powers 让 coder 用 haiku 是对的，但 reviewer 常驻消耗持续。
3. **双维度 review**：spec 合规和代码质量是两个独立维度，而不是分成 code-reviewer + test-reviewer。更合理——test 质量是代码质量的一部分。
4. **Fresh subagent 强制隔离**：每个 task 新上下文，没有跨 task 上下文污染。omni_powers 的跨 task 上下文复用可能是过度设计。
5. **进度账本**：`.superpowers/sdd/progress.md` 记录 commit hash，compact 恢复靠 git log，不靠记忆。
6. **零依赖 + 跨平台**：一个 plugin，25+ 工具可用。omni_powers 绑死 Claude Code Agent Team。

### omni_powers 做对了什么（Superpowers 没做的）

1. **控制平面**：tasks_list.json 是唯一状态源，leader 做全局调度。Superpowers 没有"所有 task 的状态概览"——它只是逐个 task 推进，没有全局视图。
2. **阻塞传播**：FAIL 3 轮自动阻塞下游依赖。Superpowers 是线性任务列表，没有依赖管理。
3. **Spec 持续积累**：每 task 闭环整理 specs/{feature}.md。Superpowers 的 spec 在 plan 文件里，归档后没有"当前真相"文件。
4. **技术债追踪**：tech_debt.md 累积 + /op-debt2tasks。Superpowers 没有技术债概念。
5. **compact 恢复协议**：RULES.md + jq + checkpoint。Superpowers 靠 `progress.md`，更轻量但也更脆弱——如果文件被 `git clean -fdx` 就丢了。
6. **Agent Team 错误检测**：标记文件机制给 leader 一个"超时兜底"。Superpowers 的 Sub Agent 模式同样受 #56869 bug 威胁。

### 关键差异：价值观

| | Superpowers | omni_powers |
|---|---|---|
| **人机关系** | "your human partner"——人在 loop 里，agent 是工具 | Leader 自治——人只负责启动，中间不打扰 |
| **设计哲学** | 极简、通用、零依赖、跨平台 | 重型、专用、完整生命周期、Claude Code 深度绑定 |
| **质量策略** | 多道 review 门 + 每次 fresh context | 双 review + 重试循环 + 阻塞传播 |
| **灵活性** | Skills 可按场景自动触发，适合任何项目 | 固定流程，只适合有 tasks_list.json 的项目 |

### 结论

**Superpowers 和 omni_powers 是不同重量级的方案，面向不同的使用场景。**

- **Superpowers**：轻量、通用、即装即用。适合单人项目、通用开发。本质是一套"最佳实践 skills"——教 agent 怎么规划、怎么执行、怎么审查。
- **omni_powers**：重型、专用、完整控制平面。适合多 task 长期项目、需要自治执行和质量保证的场景。本质是一套"操作系统"——管理 agent 生命周期、状态流转、文档归档。

**Superpowers 证明了 Sub Agent 模式是可行的**——它全线使用 Sub Agent，社区大量用户在用。如果 #56869 真的那么频繁，Superpowers 不可能成为最流行的 Claude Code 插件。

这动摇了之前"Agent Team 更可靠"的结论——Superpowers 的实践证明，Sub Agent 的 bug 可能没想象中那么致命，或者说触发条件比较特定。同时 Superpowers 的文件交接 + Fresh subagent 模式在很多方面比 omni_powers 当前设计更优。
