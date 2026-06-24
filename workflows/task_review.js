// task_review.js — 单 task 单轮 review gate
//
// 只做一件事：并行跑 code-reviewer + test-reviewer，schema 强制 verdict，返回结果。
// 不做 FAIL 轮修复——FAIL 默认交回 Teams coder（leader 把 blockers 发给原 coder，改完再调本脚本，max 3 轮）。
// leader 调用：Workflow({ scriptPath, args: { taskId } })
// leader 必须在目标 worktree 内发起 Workflow（脚本不做 worktree 切换）。
// 返回 { taskId, passed, blockers, techDebt, finalVerdicts }，leader 只读结果，不读中间 review 过程。
//
// 接口/参数/返回结构见 docs/harness/workflows/README.md。

export const meta = {
  name: 'task-review',
  description: '单 task 双 review 单轮 gate（code+test 并行），schema 强制 verdict，不做 FAIL 修复',
  phases: [
    { title: 'Review', detail: 'code-reviewer + test-reviewer 并行审，返回 verdict + blockers + techDebt' },
  ],
}

// 结构化 verdict —— 替代 review_*.md 首行 `verdict:` hack。
// model 输出不符 schema 会自动 retry。
// VERDICT schema — 同步修改点：task_review.js / task_review_autofix.js / task_full.js
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

const { taskId } = args
const tdir = `docs/work/tasks/${taskId}`

// ── 单轮双 review（barrier，两份齐才返回）──
phase('Review')
const reviewSpecs = [
  {
    role: 'code',
    agentType: 'code-reviewer',
    file: 'review_code.md',
    prompt: `审 task=${taskId} 的代码。读 git diff + ${tdir}/context.md，` +
      `审安全/架构/错误处理。结论写 ${tdir}/review_code.md。返回结构化 verdict。`,
  },
  {
    role: 'test',
    agentType: 'test-reviewer',
    file: 'review_test.md',
    prompt: `审 task=${taskId} 的测试。读 tests/ + ${tdir}/context.md，` +
      `判断测试是否真能发现 bug（假测试/缺失断言/未覆盖分支）。结论写 ${tdir}/review_test.md。返回结构化 verdict。`,
  },
]

let verdicts = (await parallel(
  reviewSpecs.map((s) => () =>
    agent(s.prompt, { label: `review:${s.role}`, phase: 'Review', schema: VERDICT, agentType: s.agentType })
      .then((v) => (v ? { ...v, _spec: s } : null))
  )
)).filter(Boolean)

const passed = verdicts.length === reviewSpecs.length && verdicts.every((v) => v.verdict === 'PASS')
if (verdicts.length < reviewSpecs.length) {
  log(`⚠️ review 不完整：期望 ${reviewSpecs.length} 份，收到 ${verdicts.length} 份（agent crash？）`)
}
const blockers = verdicts
  .filter((v) => v.verdict === 'FAIL')
  .flatMap((v) => (v.blockers || []).map((b) => ({ role: v._spec.role, blocker: b })))
const techDebt = verdicts.flatMap((v) => v.tech_debt || [])

return {
  taskId,
  passed,
  blockers,
  techDebt,
  finalVerdicts: verdicts.map((v) => ({ role: v._spec.role, verdict: v.verdict, blockers: v.blockers || [] })),
}
