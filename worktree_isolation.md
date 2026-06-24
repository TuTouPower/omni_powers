# Task 间隔离问题与决策

> 记录：在多 agent 协作开发里，为什么不能用 Claude Code Workflow 的 `isolation:'worktree'` 做 task 间的代码隔离，最终怎么解决。
> 读者无需了解项目背景，本文自包含。

## 背景：这个项目怎么开发

这是一个全栈网站项目，用**多 agent 协作**的方式开发：

- 一个 **leader**（主会话）负责编排：拆任务、派活、收口、提交。
- 几个 **teammate** 角色干活：
  - **coder**：按 TDD 写代码（先写测试→写实现→跑测试）
  - **reviewer**：审代码（安全/架构/错误处理）
  - **test-reviewer**：审测试是否真能发现 bug

开发以 **task** 为单位。一个 task 的生命周期：

```
coder 写代码 → reviewer + test-reviewer 并行审 →
  两份都 PASS → 收口提交
  任一 FAIL  → FAIL 轮：coder 改 + reviewer 重审，最多 3 轮
```

任务之间存在依赖（T9 依赖 T5 完成），无依赖的任务可以**并发**跑以加速。

## 为什么要 task 间隔离

并发时，多个 coder 同时改代码。即使协议规定"每个 coder 只改自己 task 范围内的文件"，AI coder 会越界——改到共享的工具函数、同一模块的边角。结果：

- T08 的 coder 和 T09 的 coder 改了同一文件，互相覆盖
- 收口时改动混在一起，commit 边界模糊，回滚困难
- 一个 task 的半成品代码污染另一个 task 的测试

"scope 不相交"是**期望**，不是**保证**。隔离必须有机制兜底，不能只靠规则约束 AI。

所以并发时，每个 task 的代码改动需要**互相隔离**——T08 在自己的工作区改，T09 看不见也碰不到，直到 leader 收口时合并。

## 可用的并行原语

Claude Code 提供几个并行能力，先讲清各自是什么：

| 原语 | 是什么 | 隔离粒度 |
|---|---|---|
| **Teams** | leader 派常驻 teammate，互相 SendMessage 通信 | 无内置文件隔离，靠人手动管 |
| **Workflow**（Dynamic Workflows） | 一段 JS 脚本，用 `agent()` 函数 fan-out 子 agent | `isolation:'worktree'` 选项，**每个 agent() 一个** worktree |
| **git worktree** | git 原生：一个仓库多个工作目录，各有自己的分支 | 工作目录级，**目录内所有进程共用** |

关键区别在隔离粒度：

- **git worktree** 是"一个目录"，谁在这个目录里跑就共用这个目录的文件。适合"task 级隔离"——一个 task 一个 worktree，task 内的 coder/reviewer/fix 都在这个目录里，互相看得见改动；不同 task 在不同目录，互相隔离。
- **Workflow 的 `isolation:'worktree'`** 是"每个 `agent()` 调用各开一个新 worktree"。coder 调一次开一个，reviewer 调一次又开一个，fix 再开一个。粒度是 **agent 级，不是 task 级**。

## 我们试过什么，为什么不行

### 试 A：用 Workflow `isolation:'worktree'` 隔离并发 task

最初的想法：写个 wave_parallel 脚本，每个 task 的 coder/reviewer/fix 都加 `isolation:'worktree'`，让它们各自在隔离 worktree 跑。

**问题：stage 之间看不见彼此的改动。**

pipeline 结构是 `code → review → FAIL轮fix → reverify`，每个阶段是独立的 `agent()` 调用。加了 isolation 后：

- coder 在 worktree-A（分支 `wf-coder-xxx`）写代码
- reviewer 是另一个 `agent()`，拿到的是**全新的 worktree-B**（分支 `wf-reviewer-yyy`），里面是基线代码，**看不见 coder 在 worktree-A 的改动**
- reviewer 跑 `git diff` 看到空 diff，审个寂寞

根本原因：`isolation:'worktree'` 的粒度是 agent，不是 task。要让 coder 和它的 reviewer 共用同一个 worktree，API 没有这个参数。`isolation` 只能"每个 agent 各开一个"，开不了"这几个 agent 共用一个"。

`isolation:'worktree'` 适合的是**互相独立的 fan-out**——比如"50 个文件各审各的"，agent 之间无文件依赖。不适合 `code→review` 这种 stage 间有文件依赖的 pipeline。

### 试 B：coder 提交 commit，reviewer 跨 worktree 读

试 A 失败后，想到：git worktree 共享 object database，分支引用是全局的。那让 coder 在自己的 worktree 里 `git commit`，reviewer 用 `git diff HEAD~1..HEAD` 读 coder 的 commit 不就行了？

**问题：这个 git 假设是错的。**

git worktree 共享 object database（裸对象），但**不共享分支的 HEAD**。coder 在 worktree-A 的 `wf-coder` 分支 commit，worktree-B 的 HEAD 指向 `wf-reviewer` 分支的老位置。reviewer 在自己 worktree 跑 `git diff HEAD~1..HEAD`，看到的是**它自己基线**的 commit 历史，不是 coder 的。

要让 reviewer 真看到 coder 改动，得显式 `git diff main...wf-coder`（读 coder 的具名分支）。但 isolation worktree 的分支名是 runtime 自动生成的（如 `worktree-bugfix-123`），**不暴露给脚本**——脚本拿不到 coder 的分支名，没法告诉 reviewer 该 diff 哪个分支。

退一步说，就算能读，**fix agent 改 coder 代码**这个问题还在：fix 又是新的 `agent()`，又开新 worktree、新分支，它改的代码落在 fix 自己的分支上，coder 的分支和 reverify 都看不见。stage 间的写依赖，isolation 根本接不住。

### 为什么不"让两个 agent 共用一个 worktree"

Workflow 的 `agent()` 没有"指定共用某个 worktree"的参数。`isolation:'worktree'` 是布尔开关——要么不开（共享会话工作树），要么开了就给你一个新的。没有"开 worktree-X，让后续 agent 也用 worktree-X"的接口。

这是 API 的能力边界，不是 prompt 能修的。

## Workflow 的能力边界

把上面综合起来，Workflow 在隔离这件事上的边界：

- **能给**：每个 `agent()` 各自的独立 worktree（适合无依赖 fan-out）
- **给不了**：task 级 worktree（一个 task 的多个 agent 共用一个 worktree，task 间隔离）
- **给不了**：stage 间有文件读/写依赖的 pipeline 隔离

Workflow 擅长的是"无状态、互相独立的 fan-out + 结构化返回"——比如派 50 个 reviewer 各审一个文件、用 schema 收结构化结果。不擅长"有状态、stage 间有文件依赖、需要 task 级隔离"的 code→review 循环。

## 决策

隔离需要的粒度是 **task 级**（task 内共用、task 间隔离），这恰好是 **git worktree 原生**提供的，不是 Workflow 提供的。

分工：

| 活 | 谁做 | 为什么 |
|---|---|---|
| task 间代码隔离 | **leader 手动 `git worktree add`** | git worktree 原生就是 task 级粒度：一个 task 一个 worktree，task 内 coder/reviewer/fix 共用，task 间隔离 |
| coder / FAIL 轮 fix | **Teams teammate**（常驻、可唤醒） | 有状态、跨 step/跨轮复用、leader 能中途 SendMessage 介入；FAIL 默认发回原 coder，不进脚本 |
| 单 task review 判定 | **Workflow `task_review.js`** | 无状态 fan-out + schema 强制 verdict，正是 Workflow 强项，且单 task 无并发不需隔离 |

具体怎么跑一个并发波次：

1. leader 算 DAG，挑出当前波次可并发的 task（依赖全完成、scope 不相交）
2. 给每个 task `git worktree add` 一个独立工作目录
3. 在每个 worktree 里派 Teams coder 干活（task 间因不同 worktree 而隔离）
4. coder 完成 → leader 调 `task_review.js`（在该 task 的 worktree 里发起，单 task 无并发，reviewer 共享该 worktree 直接读 coder 的未提交 diff）
5. review 返回 `{passed, blockers}` → FAIL 默认发回原 Teams coder 改，改完再调 `task_review.js`（max 3 轮）→ PASS 后 leader 收口、按依赖序合并各 worktree、提交

这样：
- **隔离**靠 git worktree（task 级，正确粒度）
- **review 自动化**靠 Workflow（单 task fan-out，无隔离难题）
- **coder 有状态 + 可介入**靠 Teams

## Workflow 相比 leader 手动，优势到底在哪

容易误以为"用 Workflow 就是更先进、更自动"。但掰开看，Workflow 的优势**只在一个地方**，且**不在隔离**。

对比两种方案（都以 leader 开 worktree 做隔离为前提）：

**方案 X：leader 开 worktree + Teams 全程手动**
```
leader: git worktree add (隔离)
leader: 派 coder 写代码              ← 手动派
coder 报告完成
leader: 派 reviewer + test-reviewer  ← 手动派
leader: head -1 取 verdict 判断      ← 手动判断
FAIL 轮: leader 派 coder 改           ← 手动派
        leader 派 reviewer 重审       ← 手动派
        leader 取 verdict 再判断      ← 手动判断
```

**方案 Y：leader 开 worktree + 调 task_review.js（单轮 review gate）**
```
leader: git worktree add (隔离)
leader: 派 coder 写代码              ← 仍手动派（coder 留 Teams）
coder 报告完成
leader: 调 Workflow(task_review.js)  ← 一行
  └ 脚本自动: 并行派 reviewer + test-reviewer
  └ 脚本自动: 取 schema verdict
  └ 返回 {passed, blockers, techDebt}
FAIL 轮: leader 把 blockers 发回原 Teams coder  ← 仍 leader 驱动
        coder 改 + 追加 review_*.md 修改记录
        leader 再调 task_review.js（max 3 轮）
```

**方案 Y 唯一的优势**：review 判定那一段自动化了（并行派双 review + schema verdict + 汇总 blockers/techDebt）。leader 不再 `head -1` 取首行、不再 grep tech_debt。FAIL 轮仍由 leader 驱动——因为 coder 有状态、可介入，留在 Teams 比塞进无状态脚本强。

**方案 Y 没有的优势**（容易误以为有的）：

| 环节 | 方案 Y 比 X 有优势吗 |
|---|---|
| task 间隔离 | ❌ 没有。两个方案都是 leader 手动 `git worktree add`。隔离的活是 git 干的，Workflow 没插手 |
| coder | ❌ 没有。两个方案 coder 都走 Teams（有状态、可介入） |
| 并发调度 | ❌ 没有。两个方案都是 leader 手动并发——同时开多个 worktree、同时派多个 coder |
| FAIL 轮 | ❌ 没有。两个方案 FAIL 都发回原 Teams coder，leader 驱动 |
| review 判定（双 review + verdict + techDebt 汇总） | ✅ 只有这块自动化了 |

**关键**：Workflow 的优势**不在隔离、不在 coder、不在并发、不在 FAIL 轮**，只在 review 判定那一段。隔离永远是 git worktree 的活，跟用不用 Workflow 无关。

### 那为什么不把 coder 也塞进 Workflow（全自动）

如果"task 级 workflow"指整个 task（code+review+FAIL）都进脚本（即 `task_full.js`），对比变成：

| | task_full 全自动 | Teams 手动 |
|---|---|---|
| review/FAIL 自动化 | ✅ | ❌ 手动 |
| coder 有状态复用 | ❌ 无状态，FAIL 轮从 spec 重建 | ✅ 跨 step 累积 |
| leader 可中途介入 | ❌ 脚本后台跑 | ✅ SendMessage 改方向 |
| 隔离 | 仍靠 leader+git | 仍靠 leader+git |

这时 Workflow 的优势（review 自动化）被代价（coder 无状态、难介入）抵消。大 task、需要盯方向的，反而亏。

所以最终选择是**方案 Y**：coder 留 Teams（保住有状态+可介入+FAIL 跨轮复用），只把 review 判定交给 Workflow（拿到自动化收益，无隔离难题）。这就是 `task_review.js` 的定位——**只自动化 review 判定，不碰 coder、不碰 FAIL 轮驱动、不碰隔离**。FAIL 轮默认发回 Teams coder，leader 跨轮再调 task_review.js；scope 内小修可选 `task_review_autofix.js`。

## 为什么不把 coder 也塞进 Workflow

有过一个方案（task_full.js）：整个 code→review→FAIL 都进一个 Workflow 脚本，全自动。否决原因：

- coder 进 Workflow 就成无状态 agent，FAIL 轮要从 spec 重建上下文，丢跨 step 累积
- 脚本后台跑，leader 难中途介入改方向
- 大 task 的 step 拆分要塞进脚本，复杂
- 隔离问题并没因此消失——多 task 并发仍要靠 git worktree，Workflow 帮不上

coder 是"有状态、长、需介入"的活，留在 Teams 更合适。Workflow 只接管它擅长的、且不涉及隔离的 review fan-out。

## 结论

- **`isolation:'worktree'` 不能用来做 task 间隔离**——粒度是 agent 不是 task，stage 间不可见，且跨 worktree 读 commit 的 git 假设不成立。
- **task 间隔离靠 git worktree**（leader 手动开，task 级粒度）。
- **Workflow 只做单 task 的 review 判定**（`task_review.js`，单轮 gate），不碰并发隔离、不碰 coder、不碰 FAIL 轮驱动。FAIL 默认发回 Teams coder，leader 跨轮再调 task_review.js。
- 曾考虑用 Workflow 做并发隔离（wave_parallel 方案），是过度设计，已否决——并发隔离靠 leader 手动 git worktree。
- `task_full.js`（coder 也进 Workflow）降级为可选，仅小独立 task 全自动时用，默认不用。
- `task_review_autofix.js`（可选）处理 scope 内小修，1 轮，超限 escalate 回 Teams coder。
