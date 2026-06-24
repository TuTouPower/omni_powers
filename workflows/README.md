# harness workflows

> optimization.md 提案的落地脚本。Workflow tool 加载执行的可运行 JS（非文档示例）。
>
> **接口手册（how）在此；何时调（when）在 agent_protocol.md。** 落地顺序：脚本先跑通，协议后改。

## 脚本清单

| 脚本 | 覆盖 optimization 哪几行 | 状态 |
|---|---|---|
| `task_review.js` | review 派 reviewer+test-reviewer / FAIL 轮三方重审 / tech_debt 提取（schema 内嵌） | 待跑通 |
| `wave_parallel.js` | 波次内并发 task（+ 内联 review 逻辑） | 待跑通（step2，依赖 task_review 验证后） |

optimization 表格四行 → 2 脚本。第四行"tech_debt 提取"不是独立流程，是让 review agent 返回 verdict 时顺带结构化吐 `tech_debt[]`，寄生在两个脚本的 `VERDICT` schema 里，leader 从返回值直接读，不 grep review 正文。

## task_review.js

单 task 双 review + FAIL 轮 adversarial 重审。替代协议"派 reviewer+test-reviewer → head-1 取 verdict → FAIL 轮三方"那段手工编排。

**调用**：
```js
Workflow({
  scriptPath: "docs/harness/workflows/task_review.js",
  args: { taskId: "T05", worktree: "/path/to/worktree" }  // worktree 可省，默认 "."
})
```

**args**：
| 字段 | 必填 | 说明 |
|---|---|---|
| `taskId` | 是 | 如 `T05`，脚本据此定位 `docs/work/tasks/{taskId}/` |
| `worktree` | 否 | coder/reviewer 的工作目录，并发时传 worktree 路径；串行省略 |

**返回**：
```js
{
  taskId: "T05",
  passed: true,            // 双 PASS 才 true
  rounds: 1,               // 实际 FAIL 轮数（0 = 首审即过）
  finalVerdicts: [{ role: "code", verdict: "PASS", blockers: [] }, ...],
  techDebt: [{ id, source, item, severity }, ...]  // 直接落 tech_debt.md
}
```

**leader 怎么用返回值**：
- `passed === true` → 进收口
- `passed === false`（rounds 已到 3）→ 标 `status=阻塞, blocked_by=quality`，写 `issues/{TID}_quality.md`
- `techDebt` → 收口时直接追加 `docs/work/tech_debt.md`，不读 review 正文

**机制要点**：
- `VERDICT` schema 强制结构化 verdict，替代 review_*.md 首行 `verdict:` hack，model 输出不符自动 retry
- 首审 `parallel`（barrier，两份齐才判断）；FAIL 轮 coder 串行改（同 worktree 防写冲突）→ reviewer 并行重审
- FAIL 轮 coder 在 review_*.md 追加修改记录，**禁碰 context.md**（协议"边界类型切"规则）
- max 3 轮，reviewer 承认误判→PASS 可提前收敛

## wave_parallel.js

波次内多 task 并发，每 task worktree 隔离，各自走 code→test→双 review。替代协议"波次宽度>1 时手工派 worktree"那段。

**调用**：
```js
Workflow({
  scriptPath: "docs/harness/workflows/wave_parallel.js",
  args: { wave: [{ taskId: "T08", steps: [...] }, { taskId: "T09", steps: [...] }], baseRef: "main" }
})
```

**args**：
| 字段 | 必填 | 说明 |
|---|---|---|
| `wave` | 是 | 当前 DAG 层可跑 task 数组，每项 `{taskId, steps?}` |
| `baseRef` | 否 | worktree 基线分支，默认仓库默认分支 |

**leader 先算 DAG 层**（选 task / 拓扑分层留在 leader，Workflow 不替代），把可跑波次传进来。

**返回**：
```js
{ wave: [{ taskId, passed, rounds, sharedFileNeeds, techDebt }, ...] }
```

**leader 怎么用返回值**：
- 按**依赖序**串行合并各 task 的 worktree（合并、跑全量测试、收口、commit 仍是 leader 职责，脚本不碰共享文件、不 commit）
- `sharedFileNeeds` → 合并时统一在共享入口/路由/依赖注册落地（协议并发约束）
- 依赖在前的先合，每合一个跑全量测试绿了再合下一个

**边界**：脚本只负责"波次内 fan-out 到双 PASS"。合并/收口/commit 不在脚本内——它无状态、不碰共享文件。

## 已知冗余

`wave_parallel.js` 的 review 段是 `task_review.js` 逻辑的**内联复制**。Workflow 脚本单文件必须自包含（不能 import 另一脚本），故有意冗余。**改 review 逻辑要同步改两处**。若未来冗余成本高，再考虑用 `workflow()` 嵌套调用（一层），但当前两份各自独立可跑更简单。

## 落地纪律

1. 脚本写完先挑**一个真 task** 试跑 `task_review.js`，验证 schema/adversarial loop 习性
2. 跑通后才改 `agent_protocol.md`：把手工派 review 那段换成调脚本（协议只留指针，不抄接口细节）
3. `task_review` 稳了再上 `wave_parallel`（它动合并顺序，风险更高）
4. 协议是真相，未验证的脚本不写进协议指令
