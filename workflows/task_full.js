// task_full.js — 单 task 完整流程：coder TDD → 双 review → FAIL 轮，一把梭
//
// 方案 B：整个 code→review→FAIL 循环进一个脚本，leader 一行调用，无人值守。
// 适用：小而独立、不需要人中途介入的 task（批量 CRUD 那种）。
// 不适用：大 task / 需要你盯方向 / 跨 step 派活 —— 那些走方案 A（coder 留 Teams，只用 task_review.js）。
//
// ⚠️ worktree：脚本内【不做】worktree 隔离。单 task 串行无并发碰撞，所有 agent 共享会话工作树，
//    coder 写完 reviewer 直接看见。要把整个 task 隔离出主树 → leader 在预建 worktree 里发起本 Workflow。
//    （isolation:'worktree' 每个 agent() 各拿独立 worktree、stage 间不共享，故全流程脚本不能用它串联 code+review。）
//
// leader 调用：Workflow({ scriptPath, args: { taskId, steps } })
// 返回 { taskId, passed, rounds, techDebt, sharedFileNeeds }，leader 只读结果。
// 接口见 docs/harness/workflows/README.md。A/B 选择标准见 README + agent_protocol.md。

export const meta = {
  name: 'task-full',
  description: '单 task 完整流程：coder TDD + 双 review + FAIL 轮，全自动一把梭（方案 B）',
  phases: [
    { title: 'Code', detail: 'coder TDD：写测试→写实现→跑测试绿→写 context.md' },
    { title: 'Review', detail: 'code-reviewer + test-reviewer 并行首审' },
    { title: 'Reverify', detail: 'FAIL 轮：coder 改 + reviewer 重审，max 3' },
  ],
}

// VERDICT schema — 同步修改点：task_review.js / task_review_autofix.js / task_full.js
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
      description: '需在共享入口/路由/依赖注册声明的项，leader 合并/收口时统一落地',
    },
  },
  required: ['done', 'testsPassed'],
}

const MAX_ROUNDS = 3
const { taskId, steps } = args
const tdir = `docs/work/tasks/${taskId}`

// ── stage 1: coder TDD（共享工作树，无 isolation）──
phase('Code')
const coder = await agent(
  `task=${taskId} TDD 实现。spec/plan 见 ${tdir}/。steps: ${JSON.stringify(steps || [])}。` +
    `写测试→写实现→跑测试绿→写 ${tdir}/context.md（每 step 正向进度：改了哪些文件/测试输出/假设）。` +
    `共享入口/路由/依赖注册不要改，在 sharedFileNeeds 声明，leader 收口统一落地。`,
  { label: `code:${taskId}`, phase: 'Code', schema: CODER_DONE, agentType: 'general-purpose' }
)

if (!coder || !coder.testsPassed) {
  return { taskId, passed: false, rounds: 0, reason: 'coder 未跑通测试', coder }
}

// ── stage 2: 双 review 并行首审 ──
phase('Review')
const specs = [
  { role: 'code', agentType: 'code-reviewer', file: 'review_code.md' },
  { role: 'test', agentType: 'test-reviewer', file: 'review_test.md' },
]
let verdicts = (await parallel(
  specs.map((s) => () =>
    agent(
      `审 task=${taskId} 的 ${s.role}。读 git diff + ${tdir}/context.md` +
        (s.role === 'test' ? ' + tests/' : '') +
        `。结论写 ${tdir}/${s.file}。返回结构化 verdict。`,
      { label: `review:${s.role}`, phase: 'Review', schema: VERDICT, agentType: s.agentType }
    ).then((v) => (v ? { ...v, _spec: s } : null))
  )
)).filter(Boolean)

// ── stage 3: FAIL 轮 loop（coder 串行改 → reviewer 并行重审，max 3）──
let round = 0
let failing = verdicts.filter((v) => v.verdict === 'FAIL')
while (failing.length && round < MAX_ROUNDS) {
  round++
  phase('Reverify')
  log(`FAIL 轮 ${round}/${MAX_ROUNDS}：${failing.map((v) => v._spec.role).join(', ')}`)

  for (const v of failing) {
    await agent(
      `task=${taskId} 的 ${v._spec.role} review FAIL。读 ${tdir}/${v._spec.file} 正文，按 blockers 改代码跑测试绿，` +
        `在同文件 ${v._spec.file} 追加"修改记录"段（已改X/不改因Y/review误判因Z）。禁止写 context.md。`,
      { label: `fix:${v._spec.role}`, phase: 'Reverify', agentType: 'general-purpose' }
    )
  }
  const reverified = (await parallel(
    failing.map((v) => () =>
      agent(
        `重审 task=${taskId} 的 ${v._spec.role}。读 ${tdir}/${v._spec.file}（含修改记录）+ 新 git diff。` +
          `承认误判→verdict=PASS，维持→FAIL 并追加理由。`,
        { label: `reverify:${v._spec.role}`, phase: 'Reverify', schema: VERDICT, agentType: v._spec.agentType }
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
  taskId,
  passed: verdicts.length > 0 && failing.length === 0,
  rounds: round,
  sharedFileNeeds: coder.sharedFileNeeds || [],
  techDebt: verdicts.flatMap((v) => v.tech_debt || []),
}
