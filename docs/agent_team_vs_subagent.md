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

**harness 属于小规模**（coder + code-reviewer + test-reviewer + closer = 2-4 个并行），所以 Sub Agent 更便宜。

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

## 七、对 harness 的适用性分析

### harness 当前设计

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

### 对 harness 的影响

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
| **harness 适合度** | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| **稳定性** | ~~生产就绪~~ 有未修复致命 bug | 实验性，有已知限制 |
| **复杂度** | 低（星形拓扑） | 高（网状拓扑 + 任务列表 + 邮箱） |
| **Token 成本** | 小规模更便宜（harness 属于此类） | 常驻开销，小规模更贵 |
| **跨 task 上下文** | 不需要（每次 task 新上下文更好） | 支持，但 harness 场景价值有限 |
| **FAIL 轮恢复** | 重新 spawn 即可 | 唤醒同一实例 |
| **并行 review** | 完美支持（但并行有 bug 风险） | 完美支持 |
| **错误可见性** | **Bug：内部错误可能静默丢失** | 标记文件机制可检测（文件不出现=异常） |

**结论变了：两个方案都不完美。**

- **Agent Team**：实验性、更贵、更复杂，但标记文件机制给了 leader 一个"超时兜底"的检测手段——文件不来就是异常
- **Sub Agent**：更简单、更便宜、更成熟，但**致命 bug 未修复**——子代理崩溃时 leader 可能永久等待

**建议：当前保持 Agent Team 方案不变。** 核心原因不是 Agent Team 更好，而是 Sub Agent 的错误传播 bug（#56869 closed/not_planned + #63678 仍开启）让依赖 Sub Agent 做关键路径任务风险太高。等这个 bug 修复后再重新评估。
