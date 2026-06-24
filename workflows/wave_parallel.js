// wave_parallel.js — 波次并发：同 DAG 层多 task 各自走 code→test→review，worktree 隔离
//
// 替代协议"波次宽度>1 时每 task 一个 worktree 手工派、手工合并"那段。
// leader 先算 DAG 层（这一步留在 leader，Workflow 不替代选 task），把当前波次可跑 task 列表传进来。
// leader 调用：Workflow({ scriptPath, args: { wave: [{taskId, steps}], baseRef } })
// 返回每个 task 的 { taskId, passed, rounds, techDebt }，leader 按依赖序串行合并 worktree（合并仍由 leader 做）。
//
// 注意：本脚本只负责"波次内 fan-out 到双 PASS"。合并 worktree、跑全量测试、收口、commit 仍是 leader 串行职责
// （协议"收口"段：依赖在前的先合，每合一个跑全量测试）。脚本不碰共享文件、不 commit。
//
// 接口/参数/返回结构见 docs/harness/workflows/README.md。

export const meta = {
  name: 'wave-parallel',
  description: '波次内多 task 并发：每 task worktree 隔离，走 code→test→双 review，返回各自 verdict',
  phases: [
    { title: 'Code', detail: '每 task 一个 coder，worktree 隔离，TDD' },
    { title: 'Review', detail: '每 task 双 review + FAIL 轮（复用 task_review 逻辑）' },
  ],
}

const VERDICT = {
  type: 'object',
  properties: {
    verdict: { type: 'string', enum: ['PASS', 'FAIL'] },
    blockers: { type: 'array', items: { type: 'string' } },
    tech_debt: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          source: { type: 'string', enum: ['review-code', 'review-test', '环境'] },
          item: { type: 'string' },
          severity: { type: 'string', enum: ['LOW', 'MEDIUM', 'HIGH'] },
        },
        required: ['id', 'source', 'item', 'severity'],
      },
    },
  },
  required: ['verdict'],
}

const CODER_DONE = {
  type: 'object',
  properties: {
    done: { type: 'boolean' },
    filesChanged: { type: 'array', items: { type: 'string' } },
    testsPassed: { type: 'boolean' },
    sharedFileNeeds: {
      type: 'array',
      items: { type: 'string' },
      description: '需在共享入口/路由/依赖注册声明的项，leader 合并时统一落地',
    },
  },
  required: ['done', 'testsPassed'],
}

const MAX_ROUNDS = 3
const wave = args.wave || []

// pipeline：每个 task 独立走 Code → Review，无 barrier。
// task A 在 Review 时 task B 还能在 Code，wall-clock = 最慢单链，不是 sum。
const results = await pipeline(
  wave,

  // stage 1: coder TDD，worktree 隔离（isolation:'worktree' 写死，不可能漏传）
  (task) =>
    agent(
      `task=${task.taskId} TDD 实现。spec/plan 见 docs/work/tasks/${task.taskId}/。` +
        `steps: ${JSON.stringify(task.steps || [])}。写测试→写实现→跑测试绿→写 context.md（每 step 正向进度）。` +
        `共享入口/路由/依赖注册不要改，在 sharedFileNeeds 声明，leader 合并时统一落地。`,
      {
        label: `code:${task.taskId}`,
        phase: 'Code',
        schema: CODER_DONE,
        agentType: 'general-purpose',
        isolation: 'worktree',
      }
    ).then((c) => ({ task, coder: c })),

  // stage 2: 双 review + FAIL 轮（与 task_review.js 同构，内联以保持单文件可跑）
  async (prev) => {
    if (!prev || !prev.coder) return null
    const { task } = prev
    const specs = [
      { role: 'code', agentType: 'code-reviewer', file: 'review_code.md' },
      { role: 'test', agentType: 'test-reviewer', file: 'review_test.md' },
    ]

    let verdicts = (await parallel(
      specs.map((s) => () =>
        agent(
          `审 task=${task.taskId} 的 ${s.role}。读 git diff + tests/ + docs/work/tasks/${task.taskId}/context.md。` +
            `结论写 docs/work/tasks/${task.taskId}/${s.file}。返回结构化 verdict。`,
          { label: `review:${task.taskId}:${s.role}`, phase: 'Review', schema: VERDICT, agentType: s.agentType }
        ).then((v) => (v ? { ...v, _spec: s } : null))
      )
    )).filter(Boolean)

    let round = 0
    let failing = verdicts.filter((v) => v.verdict === 'FAIL')
    while (failing.length && round < MAX_ROUNDS) {
      round++
      for (const v of failing) {
        await agent(
          `task=${task.taskId} 的 ${v._spec.role} review FAIL。读 docs/work/tasks/${task.taskId}/${v._spec.file} 正文，` +
            `按 blockers 改代码跑测试绿，在同文件追加修改记录段。禁碰 context.md。`,
          { label: `fix:${task.taskId}:${v._spec.role}`, phase: 'Review', agentType: 'general-purpose', isolation: 'worktree' }
        )
      }
      const reverified = (await parallel(
        failing.map((v) => () =>
          agent(
            `重审 task=${task.taskId} 的 ${v._spec.role}。读 ${v._spec.file}（含修改记录）+ 新 diff。` +
              `承认误判→PASS，维持→FAIL+理由。`,
            { label: `reverify:${task.taskId}:${v._spec.role}`, phase: 'Review', schema: VERDICT, agentType: v._spec.agentType }
          ).then((r) => (r ? { ...r, _spec: v._spec } : null))
        )
      )).filter(Boolean)
      for (const r of reverified) {
        const idx = verdicts.findIndex((v) => v._spec.role === r._spec.role)
        if (idx >= 0) verdicts[idx] = r
      }
      failing = verdicts.filter((v) => v.verdict === 'FAIL')
    }

    return {
      taskId: task.taskId,
      passed: failing.length === 0,
      rounds: round,
      sharedFileNeeds: prev.coder.sharedFileNeeds || [],
      techDebt: verdicts.flatMap((v) => v.tech_debt || []),
    }
  }
)

const final = results.filter(Boolean)
log(`波次完成：${final.filter((r) => r.passed).length}/${final.length} 双 PASS`)
return { wave: final }
