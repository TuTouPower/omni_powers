# Workflow 落地设计

> 用 Claude Code Dynamic Workflows 把协议里的**单 task review 判定**那段确定性 fan-out 从 leader 手工编排搬进可执行脚本。
> 不追求全流程自动化。脚本在 `docs/harness/workflows/`，接口手册在 `workflows/README.md`，本文件只讲设计 why。

## 核心定位（定死）

**Workflow 只做单 task 的 review gate。** 不替代 coder、不替代并发调度、不替代收口、不替代 task 间隔离。

这个定位是下面"关键设计决策 2"推导出的能力边界：Workflow 的 `isolation:'worktree'` 粒度是 agent 不是 task，做不了 task 间隔离；coder 进 Workflow 会丢状态+难介入。所以 Workflow 只接管它唯一擅长的——无状态 fan-out + schema 强制 verdict 的 review 判定。

## 分工：哪些进 Workflow，哪些留 leader/Teams

| 层 | 谁做 | 为什么 |
|---|---|---|
| 状态机 / tasks_list / checkpoint / commit / 收口 / 选 task / 阻塞判定 | **leader 主会话** | 有状态、跨 compact、改共享文档，Workflow 替代不了 |
| task 间隔离 | **leader 手动 `git worktree add`** | git worktree 原生 task 级粒度，Workflow 帮不上 |
| 并发调度（DAG 分层、开多个 worktree） | **leader** | leader 编排，不外包 |
| coder（写代码 + FAIL 轮修复） | **Teams teammate**（默认） | 有状态、跨 step/跨轮复用、leader 能 SendMessage 介入 |
| 单 task review 判定 | **`task_review.js`** | 无状态 fan-out + schema verdict，Workflow 强项 |
| FAIL 轮小修（可选） | `task_review_autofix.js` | 仅 scope 内 lint/断言/边界/类型小修，1 轮 |
| 小独立 task 全自动（可选） | `task_full.js` | 仅小而独立、不需介入的 task |
| 合并 worktree / 跑全量测试 | **leader 串行** | 收口是 leader 职责 |

## 脚本清单与状态

| 脚本 | 定位 | 状态 |
|---|---|---|
| `task_review.js` | **主用**。单 task 单轮 review gate：并行双 review + schema verdict | 待跑通 |
| `task_review_autofix.js` | 可选。review + 1 轮 scope 内 autofix，超限 escalate 回 Teams coder | 待跑通 |
| `task_full.js` | 可选。小独立 task 全自动（coder 也进 Workflow） | 待跑通，默认不用 |

## FAIL 轮两档

### 默认：FAIL 交回 Teams coder（最稳）

```
leader 派 Teams coder 写代码
→ leader 调 task_review.js
→ FAIL：脚本返回 blockers
→ leader 把 blockers 发回原 Teams coder
→ coder 改 + 在 review_*.md 追加修改记录（禁碰 context.md）
→ leader 再调 task_review.js
→ max 3 轮
```

coder 跨轮留在 Teams，保留 spec/plan/上一轮代码状态，不必从 spec 重建。符合协议"FAIL 唤醒原实例不新 spawn"。

### 可选：小修才用 autofix

`task_review_autofix.js`，只处理局部小修：lint、测试断言、小边界条件、类型错误。**写死的限制**：

- 只在当前 task worktree 跑，**禁用 `isolation:'worktree'`**
- 最多 **1 轮** autofix
- 改动文件必须在 task scope 内（`scopeFiles` 参数声明）
- 改动超过 N 行（默认 50）或涉及架构/接口/数据模型 → 立即 `escalate:true` 返回，交回 Teams coder

默认不用 autofix。仅在 leader 判断 FAIL 项全是小修时用。

## 三个关键设计决策

### 1. schema 替代 verdict 首行 hack

协议手工模式靠 `head -1 review_*.md` 取 `verdict: PASS/FAIL`，脆弱。脚本里 review agent 用 `VERDICT` schema 强制结构化返回 `{verdict, blockers, tech_debt}`，model 输出不符自动 retry。leader 直接读返回值 `{passed, blockers, techDebt}`，不读 review 正文。tech_debt 也寄生在这个 schema 里顺带吐出，不再 grep。

### 2. isolation 不适合 stage 间有依赖的 pipeline

`isolation:'worktree'` 每个 `agent()` 各开**独立 worktree + 独立分支**，stage 间不共享（git worktree 共享 object DB 但不共享分支 HEAD，reviewer 看不见 coder 改动）。它只适合**互相独立的 fan-out**（各审各的文件），不适合 code→review 这种 stage 间有文件依赖的 pipeline。

故所有脚本**都不用 isolation**，全靠共享会话工作树：单 task 串行无碰撞，coder 写未提交改动 reviewer 直接读 `git diff`。要隔离整个 task 出主树 → leader 在预建 worktree 里发起 Workflow。

**已否决的两条隔离路（踩坑实录，留此防重蹈）**：
- **试 A：每个 agent 加 `isolation:'worktree'`**。coder 在 worktree-A 写代码，reviewer 是另一个 `agent()`、拿到全新 worktree-B（基线代码），跑 `git diff` 看到空 diff，审个寂寞。根因：isolation 粒度是 agent 不是 task，API 无"多 agent 共用一个 worktree"参数。
- **试 B：coder 在自己 worktree commit，reviewer 跨 worktree 读**。失败：worktree 共享 object DB 但不共享分支 HEAD，reviewer 跑 `git diff HEAD~1..HEAD` 读到的是自己基线历史；要读 coder 改动须 `git diff main...wf-coder`，但 isolation 的分支名 runtime 自动生成、不暴露给脚本，拿不到。且 fix agent 又是新 worktree，改动落自己分支，coder/reverify 都看不见——stage 间写依赖 isolation 根本接不住。

### 3. task 间隔离永远是 git worktree 的活，与 Workflow 无关

并发时 leader `git worktree add` 给每个 task 一个独立工作目录，Teams coder 各自在自己 worktree 工作，task 间天然隔离。曾考虑用 Workflow 做并发隔离（wave_parallel 方案）是过度设计（理由见决策 2/3），已否决。并发调度 + 合并收口始终 leader 手动。

## 为什么不把 coder 也塞进 Workflow（默认）

`task_full.js` 把整个 code→review→FAIL 都进脚本，coder 成无状态 agent：

| | task_full 全自动 | Teams 手动（默认） |
|---|---|---|
| review/FAIL 自动化 | ✅ | ❌ 手动（但 task_review.js 已半自动） |
| coder 有状态复用 | ❌ 无状态，FAIL 轮从 spec 重建 | ✅ 跨 step/跨轮累积 |
| leader 可中途介入 | ❌ 脚本后台跑 | ✅ SendMessage 改方向 |
| 隔离 | 仍靠 leader+git | 仍靠 leader+git |

Workflow 的优势（review 自动化）被代价（coder 无状态、难介入）抵消。大 task、需盯方向的，反而亏。所以 `task_full.js` 降级为**可选**，仅小而独立、不需介入、失败成本低的 task 用（改文案、补纯工具函数、增孤立测试、修明确 bug）。

## 落地纪律

1. 脚本写完先挑**一个旧的、可丢弃的 task** 试 `task_review.js`（review 只读，跑坏重跑不污染代码），验证 schema / worktree 习性
2. 跑通后才改 `agent_protocol.md`：把手工派 review 那段换成调脚本（协议只留指针，不抄接口细节）
3. `task_review.js` 稳了再上 `task_review_autofix.js`、`task_full.js`
4. **协议是真相，未验证的脚本不写进协议指令**——现在协议里是"提案"状态，跑通才转正
