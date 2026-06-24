# harness workflows

> 落地脚本。Workflow tool 加载执行的可运行 JS（非文档示例）。
>
> **接口手册（how）在此；何时调（when）在 agent_protocol.md；设计决策在 workflow_design.md。**

## 脚本清单

| 脚本 | 覆盖 | 状态 |
|---|---|---|
| `task_review.js` | 单 task 单轮 review gate（双 review + schema verdict） | 待跑通（主用） |
| `task_review_autofix.js` | review + 1 轮 scope 内 autofix，超限 escalate | 待跑通（可选） |
| `task_full.js` | 单 task 全流程（code→review→FAIL），方案 B 全自动 | 待跑通（可选，默认不用） |

**定位**：Workflow 只做单 task review gate。不替代 coder、不替代并发调度、不替代收口、不替代 task 间隔离。tech_debt 寄生在 `VERDICT` schema 里顺带结构化吐出，leader 从返回值直接读，不 grep review 正文。

脚本选择标准、FAIL 两档、worktree 设计决策见 `docs/harness/workflow_design.md`（设计 why），本文件只讲接口 how。

## ⚠️ worktree 关键约束

`isolation:'worktree'` 每个 `agent()` 各开**独立 worktree + 独立分支**，stage 间不共享（git worktree 共享 object DB 但不共享分支 HEAD，reviewer 看不见 coder 改动）。故 `isolation` 只适合**互相独立的 fan-out**（各审各的文件），不适合 stage 间有文件依赖的 pipeline。

所有脚本因此**都不用 isolation**，全靠共享会话工作树：单 task 串行无碰撞，coder 写未提交改动 reviewer 直接读 `git diff`。

**task 间隔离 ≠ Workflow 的活**：并发时 leader 手动 `git worktree add` 给每个 task 一个独立工作目录，Teams coder 各自工作。要隔离整个 task 出主树 → leader 在预建 worktree 里发起 Workflow。详见 `docs/harness/worktree_isolation.md`。

## task_review.js（主用）

单 task 单轮 review gate：并行跑 code-reviewer + test-reviewer，schema 强制 verdict，返回结果。**不做 FAIL 轮修复**——FAIL 默认交回 Teams coder（leader 把 blockers 发给原 coder，改完再调本脚本）。

**调用**：
```js
Workflow({
  scriptPath: "docs/harness/workflows/task_review.js",
  args: { taskId: "T05" }
})
```
> ⚠️ leader 必须在目标 worktree 内发起 Workflow。脚本不做 worktree 切换。

**args**：
| 字段 | 必填 | 说明 |
|---|---|---|
| `taskId` | 是 | 如 `T05`，脚本据此定位 `docs/work/tasks/{taskId}/` |

**返回**：
```js
{
  taskId: "T05",
  passed: true,            // 双 PASS 才 true
  blockers: [{ role: "code", blocker: "..." }],  // FAIL 时的 CRITICAL/HIGH 列表
  techDebt: [{ id, source, item, severity }, ...],  // 直接落 tech_debt.md
  finalVerdicts: [{ role: "code", verdict: "PASS", blockers: [] }, ...]
}
```

**leader 怎么用返回值**：
- `passed === true` → 进收口
- `passed === false` → 把 `blockers` 发回原 Teams coder 改，改完**再调本脚本**，max 3 轮；第 3 轮仍 FAIL → 标 `status=阻塞, blocked_by=quality`，写 `issues/{TID}_quality.md`
- `techDebt` → 收口时直接追加 `docs/work/tech_debt.md`，不读 review 正文

**机制要点**：
- `VERDICT` schema 强制结构化 verdict，替代 review_*.md 首行 `verdict:` hack，model 输出不符自动 retry
- **空 verdicts 守卫**：`passed` 要求 `verdicts.length === reviewSpecs.length`——任一 agent crash 返回 null 被 filter 过滤后，length 不够直接判 FAIL，不会因 `[].every()` 偷渡 PASS
- 单轮 `parallel`（barrier，两份齐才返回）；FAIL 轮由 leader 驱动（不进脚本），leader 跨轮计数
- 并发时：每个 task 在各自 worktree 里单独调本脚本，产出落各自 review_*.md 互不干扰

## task_review_autofix.js（可选）

review + 1 轮 scope 内 autofix。仅 FAIL 项都是局部小修（lint/测试断言/小边界/类型错误）时用。**写死的限制**：最多 1 轮、改动必须在 `scopeFiles` 内、改动超 50 行或涉及架构/接口/数据模型 → 立即 `escalate:true` 交回 Teams coder。autofix 后有**确定性硬校验**（`git diff --name-only` + `--numstat`），不靠 AI 判断 scope。

**调用**：
```js
Workflow({
  scriptPath: "docs/harness/workflows/task_review_autofix.js",
  args: { taskId: "T05", scopeFiles: ["src/api/foo.py", "tests/api/test_foo.py"] }
})
```
> ⚠️ leader 必须在目标 worktree 内发起 Workflow。脚本不做 worktree 切换。

**args**：
| 字段 | 必填 | 说明 |
|---|---|---|
| `taskId` | 是 | 如 `T05` |
| `scopeFiles` | 是 | 允许 autofix 改的文件白名单；超出即 escalate |

**返回**：
```js
{
  taskId: "T05",
  passed: true,            // autofix 后双 PASS 才 true
  rounds: 1,               // autofix 轮数（0=首审即过未 autofix，1=autofix 过）
  blockers: [...],
  techDebt: [...],
  escalate: false          // true=超限，blockers 交回 Teams coder
}
```

**leader 怎么用返回值**：
- `passed === true` → 进收口
- `escalate === true` 或 `passed === false` → 交回 Teams coder（按 task_review.js 默认 FAIL 路径走）
- 默认不用本脚本；仅 leader 判断 FAIL 项全是 scope 内小修时用

## task_full.js（可选，默认不用）

单 task 完整流程，全自动（方案 B）：coder TDD → 双 review → FAIL 轮。仅小而独立、不需介入、失败成本低的 task 用（改文案、补纯工具函数、增孤立测试、修明确 bug）。

**调用**：
```js
Workflow({ scriptPath: "docs/harness/workflows/task_full.js", args: { taskId: "T05", steps: [...] } })
```

**args**：`taskId`（必填）、`steps`（可选，plan 的 step 列表，给 coder 参考）。

**返回**：`{ taskId, passed, rounds, sharedFileNeeds, techDebt }`。coder 没跑通测试 → 直接返回 `passed:false, reason`。

**leader 用返回值**：`passed` 决定收口 or 阻塞；`sharedFileNeeds` 收口时落共享文件；`techDebt` 追加 tech_debt.md。

## wave 并发怎么做

并发不靠脚本。leader 算 DAG layer → 每个 task `git worktree add` 一个独立工作目录 → 派 Teams coder 各自在自己 worktree 工作（task 间天然隔离）→ 每个 worktree 内单独调 `task_review.js` → leader 按依赖序串行合并收口。`isolation:'worktree'` 粒度是 agent 不是 task，做不了 task 间隔离（详见 `worktree_isolation.md`）。

## 已知冗余

`task_full.js` 的 review 段是 `task_review.js` 逻辑的**内联复制**。Workflow 脚本单文件必须自包含（不能 import 另一脚本），故有意冗余。**改 review 逻辑要同步改两处**——三份 VERDICT schema 均有 `// VERDICT schema — 同步修改点` 注释标记。若未来验证 Bun runtime 支持跨文件 import，可抽 `shared.js` 消除冗余。

落地纪律见 `docs/harness/workflow_design.md`。
