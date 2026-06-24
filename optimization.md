# Harness 优化意见

> 对照 [[agent_protocol]] 与 [[harness_experience]] 的现状，结合 Claude Code 2026-05 GA 的 Dynamic Workflows，给出升级路径。
> 日期：2026-06-25

## 现状判断

当前协议 = Teams + 手工编排。骨架对，三处痛点：

1. **`head -1` 取 verdict** —— 脆弱 hack，靠文件首行格式约定，无校验。
2. **FAIL 轮三方重读重审** —— 全靠 leader 手工调度，上下文烧在协调上。
3. **波次并发** —— 手工派 worktree、手工合并、手工跑全量测试，易漏文件（见 [[harness_experience]] T11）。

`harness_experience.md` 里的 6 个问题里，#1（teammate 不复用）、#2（worktree 漏做）、#3（DAG 不重算）都是编排层失误，可被 Workflow 的确定性脚本消解。

## 升级方案：混合架构

**Leader 主会话保留**（Workflow 做不了）：
- 状态机 / tasks_list.json / checkpoint / commit / 收口
- 选 task 规则、阻塞判定、跨 compact 恢复
- 共享文档串行收口（progress/decisions/tech_debt/specs）

**Workflow 接管确定性 fan-out**（它的强项）：

| 协议步骤 | 换成 | 收益 |
|---|---|---|
| review 派 reviewer + test-reviewer | `pipeline([code_review, test_review])` + `schema:{verdict}` | 干掉 head-1 hack，结构化强制校验 |
| FAIL 轮三方重审 | `loop-until-dry` + adversarial verify | leader 不参与来回，只看最终 verdict |
| 波次内并发 task | `pipeline(wave_tasks, code→test→review, isolation:'worktree')` | 自动隔离 + 合并顺序 |
| tech_debt 提取 | review agent schema 带 `tech_debt[]` 字段 | leader 直接读 schema，不 grep 正文 |

## Claude Code 功能映射

- **Workflow tool**（dynamic workflows，2026-05-28 GA）：JS 脚本编排子 agent，最多 1000 agent / 16 并发，自带 resume、worktree、schema。就是"动态 workflow"。
- **`schema` 参数**：替代 `verdict: PASS/FAIL` 首行 hack，结构化强制校验，model 不符合会自动 retry。
- **`isolation: "worktree"`**：波次并发隔离，协议已要求，Workflow 原生支持，省手工派。
- **`pipeline()`**：无 barrier 流水线，item A 可在 stage 3 时 item B 还在 stage 1，wall-clock = 最慢单链。
- **`parallel()`**：barrier，需全部收齐再下一步（如合并前等所有 review）。
- **Agent tool `subagent_type`**：coder→general-purpose/haiku，reviewer→code-reviewer/sonnet，test-reviewer→test-reviewer/sonnet，直接复用现有角色定义。
- **Skills**：`superpowers:brainstorming` / `writing-plans` / `tdd` 协议已在用，继续。

## 单 task review 步骤的 Workflow 草稿

```javascript
export const meta = {
  name: 'task-review',
  description: '单 task 的双 review + FAIL 轮 adversarial 重审',
  phases: [{ title: 'Review' }, { title: 'Reverify' }],
}

const VERDICT = {
  type: 'object',
  properties: {
    verdict: { type: 'string', enum: ['PASS', 'FAIL'] },
    blockers: { type: 'array', items: { type: 'string' } },
    tech_debt: {
      type: 'array',
      items: { type: 'object',
        properties: { id: {type:'string'}, item:{type:'string'}, severity:{type:'string', enum:['LOW','MEDIUM','HIGH']} },
        required: ['id','item','severity'] } },
  },
  required: ['verdict'],
}

export const args = { taskId: 'T05', worktree: '/path/to/wt' }

phase('Review')
const reviews = await parallel([
  () => agent(
    `读 ${args.worktree} 的 git diff + context.md，审代码/安全/架构/错误处理。task=${args.taskId}`,
    { label: 'review:code', phase: 'Review', schema: VERDICT, agentType: 'code-reviewer' }
  ),
  () => agent(
    `读 ${args.worktree} 的 tests/ + context.md，审测试是否真能发现 bug。task=${args.taskId}`,
    { label: 'review:test', phase: 'Review', schema: VERDICT, agentType: 'test-reviewer' }
  ),
]).then(r => r.filter(Boolean))

// FAIL 轮：adversarial loop-until-dry，max 3
let round = 0
let failing = reviews.filter(r => r.verdict === 'FAIL')
while (failing.length && round < 3) {
  round++
  phase(`Reverify-${round}`)
  // coder 改（在 worktree 里），然后 reviewer 重审
  failing = (await parallel(failing.map(r => () =>
    agent(
      `重审 task=${args.taskId}。上轮 blockers: ${JSON.stringify(r.blockers)}。读 coder 在 review_*.md 追加的修改记录 + 新 git diff。承认误判则 verdict=PASS，否则维持 FAIL 并追加理由。`,
      { phase: `Reverify-${round}`, schema: VERDICT, agentType: r._role === 'code' ? 'code-reviewer' : 'test-reviewer' }
    )
  ))).filter(Boolean).filter(r => r.verdict === 'FAIL')
}

const passed = failing.length === 0
return { taskId: args.taskId, passed, rounds: round, finalReviews: reviews }
```

leader 只看返回的 `{passed, rounds}`，不参与来回。FAIL 3 轮 → 标 `blocked_by=quality`。

## OSS 参考（只看思路，不引入依赖）

- **coleam00/Archon**：plan→build→review→self-heal，思路和本协议几乎一致，可抄 review/self-heal 段。
- **barkain/claude-code-workflow-orchestration**：CC plugin，任务分解 + 并行 + plan mode 集成。
- **nemori-ai/langchain-dynamic-workflow**：CC Workflow 的 LangChain 移植，看它怎么用 schema + resume。

**不建议**引入 LangGraph / AutoGen / CrewAI。编排层 CC Teams + Workflow 已覆盖，再套一层只增复杂度、烧 token。真要脱离 CC 才上 Claude Agent SDK。

## 落地路径（分两步，别一次全改）

1. **先** Workflow 化单 task 的 review + FAIL 轮（schema verdict + adversarial loop）。收益最大、风险最小，先验证 Workflow 习性。
2. **再** Workflow 化波次并发（pipeline + worktree）。这一步动了合并顺序，要等 step 1 稳。

## 对 harness_experience 六条的对号

| 经验条目 | 本方案如何消解 |
|---|---|
| #1 teammate 不复用 | Workflow 的 agent() 是无状态 fan-out，不存在"复用"问题；常驻 reviewer 仍走 Teams |
| #2 worktree 漏做 | `isolation:'worktree'` 写进脚本，不可能漏传 |
| #3 DAG 不重算 | leader 开工仍手工算 DAG（Workflow 不替代选 task），但波次内 fan-out 交给脚本 |
| #4 FAIL 修改记录位置 | schema 里 blockers/反驳结构化，不再依赖文件追加位置 |
| #5 commit 漏文件 | worktree 隔离后每 task 改动自包含，收口一次 commit |
| #6 cost hook 误报 | 与本方案无关，单独修 hook 阈值 |
