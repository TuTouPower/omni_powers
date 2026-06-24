# Workflow 落地设计

> 用 Claude Code Dynamic Workflows 把协议里的确定性 fan-out（code/review/FAIL 轮/波次并发）从 leader 手工编排搬进可执行脚本。
> 脚本在 `docs/harness/workflows/`，接口手册在 `workflows/README.md`，本文件只讲设计。

## 分工：哪些进 Workflow，哪些留 leader/Teams

| 层 | 谁做 | 为什么 |
|---|---|---|
| 状态机 / tasks_list / checkpoint / commit / 收口 / 选 task / 阻塞判定 | **leader 主会话** | 有状态、跨 compact、改共享文档，Workflow 替代不了 |
| 常驻 coder / reviewer（方案 A 时） | **Teams** | 有状态、可唤醒复用、人可中途介入 |
| 确定性 fan-out：双 review / FAIL 轮 / 波次并发 | **Workflow 脚本** | 无状态扇出、结构化返回，正是它强项 |

## 三个脚本

| 脚本 | 干什么 | 用在 |
|---|---|---|
| `task_full.js` | 单 task 全流程：coder TDD → 双 review → FAIL 轮 | 方案 B（小独立 task 全自动） |
| `task_review.js` | 只 review + FAIL 轮（coder 留 Teams） | 方案 A（大/需介入 task） |
| `wave_parallel.js` | 波次内多 task 并发，各自走 code→review→FAIL | 波次宽度>1 |

## 方案 A vs B：单 task 怎么选

| | A（task_review.js） | B（task_full.js） |
|---|---|---|
| coder 在哪 | 留 Teams（haiku 常驻、可唤醒） | 进 Workflow（无状态） |
| Workflow 管 | 只 review+FAIL | 整个 code→review→FAIL |
| 人能中途介入 | 能（SendMessage 改方向） | 难（后台跑，等结束或 kill） |
| FAIL 轮 coder | 记得上一轮 | 无状态，从 spec/diff 重建 |
| 适合 | **大 task / 需盯方向 / 长 step 链** | **小独立 / 不需介入 / 一把梭** |

leader 立项时按 task 性质挑。大、长、有状态的 task 必走 A。

## 两个关键设计决策

### 1. schema 替代 verdict 首行 hack

协议原本靠 `head -1 review_*.md` 取 `verdict: PASS/FAIL`，脆弱。脚本里 review agent 用 `VERDICT` schema 强制结构化返回 `{verdict, blockers, tech_debt}`，model 输出不符自动 retry。leader 直接读返回值 `{passed, rounds, techDebt}`，不读 review 正文。tech_debt 也寄生在这个 schema 里顺带吐出，不再 grep。

### 2. worktree：每 agent 独立、stage 间不共享

`isolation:'worktree'` 是**每个 `agent()` 各拿独立 worktree，stage 间不共享，路径 runtime 管**。由此：

- **task_full.js**：脚本内**不用** isolation。单 task 串行无碰撞，所有 agent 共享会话工作树，coder 写完 reviewer 直接看见。要隔离整个 task → leader 在预建 worktree 里发起 Workflow。
- **wave_parallel.js**：跨 task 隔离**不能靠共享未提交改动**（review agent 拿到新 worktree，看不见 coder 的）。正确做法：coder 在自己 worktree 内 **commit**，downstream 读已提交状态。**首跑第一要验证此点。**

## 落地纪律

1. 脚本写完先挑**一个旧的、可丢弃的 task** 试 `task_review.js`（review 只读，跑坏重跑不污染代码），验证 schema / adversarial loop / worktree 习性
2. 跑通后才改 `agent_protocol.md`：把手工派 review 那段换成调脚本（协议只留指针，不抄接口细节）
3. `task_review` 稳了再上 `task_full`、`wave_parallel`（后者动合并顺序，风险最高）
4. **协议是真相，未验证的脚本不写进协议指令**——现在协议里是"提案"状态，跑通才转正
