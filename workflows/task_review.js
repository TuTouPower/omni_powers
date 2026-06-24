// task_review.js — 单 task 双 review + FAIL 轮 adversarial 重审
//
// 替代协议"派 reviewer+test-reviewer → head-1 取 verdict → FAIL 轮三方"那段手工编排。
// leader 调用：Workflow({ scriptPath, args: { taskId, worktree } })
// 返回 { taskId, passed, rounds, finalVerdicts, techDebt }，leader 只读结果，不读中间 review 过程。
//
// 接口/参数/返回结构见 docs/harness/workflows/README.md。

export const meta = {
  name: 'task-review',
  description: '单 task 双 review（code+test）+ FAIL 轮 adversarial 重审，max 3 轮',
  phases: [
    { title: 'Review', detail: 'code-reviewer + test-reviewer 并行首审' },
    { title: 'Reverify', detail: 'FAIL 轮：coder 改 + reviewer 重审，循环至 PASS 或 3 轮' },
  ],
}

// 结构化 verdict —— 替代 review_*.md 首行 `verdict:` hack。
// model 输出不符 schema 会自动 retry。
const VERDICT = {
  type: 'object',
  properties: {
    verdict: { type: 'string', enum: ['PASS', 'FAIL'] },
    blockers: {
      type: 'array',
      items: { type: 'string' },
      description: 'CRITICAL/HIGH 问题，FAIL 时必填',
    },
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
      description: 'MEDIUM/LOW + 环境限制项，leader 收口直接落 tech_debt.md',
    },
  },
  required: ['verdict'],
}

const MAX_ROUNDS = 3
const { taskId, worktree } = args
const wt = worktree || '.'

// ── 首审：code + test 并行（barrier，两份都要齐才进 FAIL 判断）──
phase('Review')
const reviewSpecs = [
  {
    role: 'code',
    agentType: 'code-reviewer',
    file: 'review_code.md',
    prompt: `审 task=${taskId} 的代码。工作目录 ${wt}。读 git diff + docs/work/tasks/${taskId}/context.md，` +
      `审安全/架构/错误处理。结论写 docs/work/tasks/${taskId}/review_code.md。返回结构化 verdict。`,
  },
  {
    role: 'test',
    agentType: 'test-reviewer',
    file: 'review_test.md',
    prompt: `审 task=${taskId} 的测试。工作目录 ${wt}。读 ${wt} 的 tests/ + docs/work/tasks/${taskId}/context.md，` +
      `判断测试是否真能发现 bug（假测试/缺失断言/未覆盖分支）。结论写 docs/work/tasks/${taskId}/review_test.md。返回结构化 verdict。`,
  },
]

let verdicts = (await parallel(
  reviewSpecs.map((s) => () =>
    agent(s.prompt, { label: `review:${s.role}`, phase: 'Review', schema: VERDICT, agentType: s.agentType })
      .then((v) => (v ? { ...v, _spec: s } : null))
  )
)).filter(Boolean)

// ── FAIL 轮：coder 改 → reviewer 重审，loop 至全 PASS 或 3 轮 ──
let round = 0
let failing = verdicts.filter((v) => v.verdict === 'FAIL')

while (failing.length && round < MAX_ROUNDS) {
  round++
  phase('Reverify')
  log(`FAIL 轮 ${round}/${MAX_ROUNDS}：${failing.map((v) => v._spec.role).join(', ')}`)

  // coder 串行改（同一 worktree，避免并行写冲突）：读 review 正文 → 改代码 → 在 review_*.md 追加修改记录（禁碰 context.md）
  for (const v of failing) {
    await agent(
      `task=${taskId} 的 ${v._spec.role} review FAIL。工作目录 ${wt}。读 docs/work/tasks/${taskId}/${v._spec.file} 正文，` +
        `按 blockers 改代码，跑测试确认绿。在同文件 ${v._spec.file} 追加"修改记录"段（已改X/不改因Y/review误判因Z）。禁止写 context.md。`,
      { label: `fix:${v._spec.role}`, phase: 'Reverify', agentType: 'general-purpose' }
    )
  }

  // reviewer 并行重审：读 coder 反驳 + 新 diff → 更新 verdict（承认误判→PASS，维持→FAIL+理由）
  const reverified = (await parallel(
    failing.map((v) => () =>
      agent(
        `重审 task=${taskId} 的 ${v._spec.role}。工作目录 ${wt}。读 docs/work/tasks/${taskId}/${v._spec.file}` +
          `（含 coder 追加的修改记录）+ 新 git diff。承认误判则 verdict=PASS，维持原判则 FAIL 并在文件追加本轮理由。`,
        { label: `reverify:${v._spec.role}`, phase: 'Reverify', schema: VERDICT, agentType: v._spec.agentType }
      ).then((r) => (r ? { ...r, _spec: v._spec } : null))
    )
  )).filter(Boolean)

  // 用重审结果替换对应 role 的 verdict
  for (const r of reverified) {
    const idx = verdicts.findIndex((v) => v._spec.role === r._spec.role)
    if (idx >= 0) verdicts[idx] = r
  }
  failing = verdicts.filter((v) => v.verdict === 'FAIL')
}

const passed = failing.length === 0
const techDebt = verdicts.flatMap((v) => v.tech_debt || [])

return {
  taskId,
  passed,
  rounds: round,
  finalVerdicts: verdicts.map((v) => ({ role: v._spec.role, verdict: v.verdict, blockers: v.blockers || [] })),
  techDebt,
}
