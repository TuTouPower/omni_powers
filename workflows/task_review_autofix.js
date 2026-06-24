// task_review_autofix.js — 单 task review + 1 轮 scope 内 autofix（可选）
//
// 仅 FAIL 项都是局部小修（lint/测试断言/小边界/类型错误）时用。写死限制：
//   - 禁用 isolation:'worktree'，在当前 worktree 跑
//   - 最多 1 轮 autofix
//   - 改动必须在 scopeFiles 白名单内
//   - 改动超 MAX_LINES 行 或 涉及架构/接口/数据模型 → escalate:true，交回 Teams coder
// leader 调用：Workflow({ scriptPath, args: { taskId, scopeFiles } })
// leader 必须在目标 worktree 内发起 Workflow（脚本不做 worktree 切换）。
// 返回 { taskId, passed, rounds, blockers, techDebt, escalate }
//
// 默认不用。仅 leader 判断 FAIL 项全是 scope 内小修时用。接口见 docs/harness/workflows/README.md。

export const meta = {
  name: 'task-review-autofix',
  description: '单 task review + 1 轮 scope 内 autofix，超限 escalate 回 Teams coder',
  phases: [
    { title: 'Review', detail: '双 review 并行首审' },
    { title: 'Autofix', detail: 'scope 内小修，1 轮，超限 escalate' },
    { title: 'Reverify', detail: 'autofix 后重审' },
  ],
}

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
      description: 'MEDIUM/LOW + 环境限制项',
    },
  },
  required: ['verdict'],
}

// 判定单次 autofix 是否在允许范围内
const FIX_SCHEMA = {
  type: 'object',
  properties: {
    canAutofix: { type: 'boolean', description: 'true=blockers 全是 scope 内小修可自动改；false=有架构/接口/数据模型/超限项需 escalate' },
    reason: { type: 'string', description: 'canAutofix=false 时说明哪项超限' },
  },
  required: ['canAutofix'],
}

const MAX_LINES = 50
const { taskId, scopeFiles } = args
const tdir = `docs/work/tasks/${taskId}`
if (!scopeFiles || !scopeFiles.length) {
  return { taskId, passed: false, escalate: true, blockers: [], techDebt: [], rounds: 0, finalVerdicts: [], reason: 'scopeFiles 未提供，autofix 拒绝跑' }
}

const reviewSpecs = [
  {
    role: 'code',
    agentType: 'code-reviewer',
    file: 'review_code.md',
    prompt: `审 task=${taskId} 的代码。读 git diff + ${tdir}/context.md，审安全/架构/错误处理。结论写 ${tdir}/review_code.md。返回结构化 verdict。`,
  },
  {
    role: 'test',
    agentType: 'test-reviewer',
    file: 'review_test.md',
    prompt: `审 task=${taskId} 的测试。读 tests/ + ${tdir}/context.md，判断测试是否真能发现 bug。结论写 ${tdir}/review_test.md。返回结构化 verdict。`,
  },
]

// ── 首审 ──
phase('Review')
let verdicts = (await parallel(
  reviewSpecs.map((s) => () =>
    agent(s.prompt, { label: `review:${s.role}`, phase: 'Review', schema: VERDICT, agentType: s.agentType })
      .then((v) => (v ? { ...v, _spec: s } : null))
  )
)).filter(Boolean)

const allPassFirst = verdicts.length === reviewSpecs.length && verdicts.every((v) => v.verdict === 'PASS')
if (allPassFirst) {
  return {
    taskId, passed: true, rounds: 0, escalate: false,
    blockers: [], techDebt: verdicts.flatMap((v) => v.tech_debt || []),
    finalVerdicts: verdicts.map((v) => ({ role: v._spec.role, verdict: v.verdict, blockers: v.blockers || [] })),
  }
}

// ── 判定能否 autofix ──
const failing = verdicts.filter((v) => v.verdict === 'FAIL')
const allBlockers = failing.flatMap((v) => (v.blockers || []).map((b) => `[${v._spec.role}] ${b}`)).join('\n')

phase('Autofix')
const triage = await agent(
  `判定 task=${taskId} 的 FAIL blockers 能否 scope 内自动修复。\n` +
    `先读 git diff 看实际改动，再读 ${tdir}/review_code.md 和 ${tdir}/review_test.md 的 blockers 段。\n` +
    `blockers:\n${allBlockers}\n\n` +
    `允许 autofix 的：lint、测试断言、小边界条件、类型错误，且改动只能在 ${JSON.stringify(scopeFiles)} 内、总改动 ≤${MAX_LINES} 行。\n` +
    `必须 escalate（canAutofix=false）的：涉及架构/接口/数据模型，或改动超 ${MAX_LINES} 行，或需改 scope 外文件。\n` +
    `不读 diff 直接判定视为 canAutofix=false。`,
  { label: 'triage', phase: 'Autofix', schema: FIX_SCHEMA, agentType: 'general-purpose' }
)

if (!triage || !triage.canAutofix) {
  return {
    taskId, passed: false, rounds: 0, escalate: true,
    blockers: failing.flatMap((v) => (v.blockers || []).map((b) => ({ role: v._spec.role, blocker: b }))),
    techDebt: verdicts.flatMap((v) => v.tech_debt || []),
    finalVerdicts: verdicts.map((v) => ({ role: v._spec.role, verdict: v.verdict, blockers: v.blockers || [] })),
    reason: (triage && triage.reason) || 'triage 未返回',
  }
}

// ── autofix：coder 改 + 跑测试 ──
await agent(
  `task=${taskId} review FAIL，全是 scope 内小修。读 ${tdir}/review_code.md 和 review_test.md 正文，` +
    `按 blockers 改代码，只允许改这些文件：${JSON.stringify(scopeFiles)}，总改动 ≤${MAX_LINES} 行。跑测试确认绿。` +
    `在对应 review_*.md 追加"修改记录"段（已改X/不改因Y）。禁止写 context.md。禁止改 scope 外文件。`,
  { label: 'autofix', phase: 'Autofix', agentType: 'general-purpose' }
)

// ── 硬校验：autofix 是否真的在 scope 内（确定性检查，不靠 AI 判断）──
const scopeCheck = await agent(
  `验证 task=${taskId} 的 autofix 改动是否在允许范围内。执行以下 bash 命令并分析结果：\n` +
    `1. git diff --name-only HEAD 看改动文件列表\n` +
    `2. git diff --numstat HEAD 看改动行数\n` +
    `允许的文件：${JSON.stringify(scopeFiles)}\n` +
    `总改动上限：${MAX_LINES} 行\n` +
    `若改动文件超出白名单或总行数超限，返回 inScope=false 并列出违规项。`,
  { label: 'scope-check', phase: 'Autofix', schema: {
    type: 'object',
    properties: {
      inScope: { type: 'boolean', description: '改动是否全在 scope 内' },
      violations: { type: 'array', items: { type: 'string' }, description: '超出 scope 的文件或行数' },
    },
    required: ['inScope'],
  }, agentType: 'general-purpose' }
)

if (scopeCheck && !scopeCheck.inScope) {
  return {
    taskId, passed: false, rounds: 1, escalate: true,
    blockers: failing.flatMap((v) => (v.blockers || []).map((b) => ({ role: v._spec.role, blocker: b }))),
    techDebt: verdicts.flatMap((v) => v.tech_debt || []),
    finalVerdicts: verdicts.map((v) => ({ role: v._spec.role, verdict: v.verdict, blockers: v.blockers || [] })),
    reason: `autofix 超出 scope：${(scopeCheck.violations || []).join('; ')}`,
  }
}

// ── 重审 ──
phase('Reverify')
const reverified = (await parallel(
  failing.map((v) => () =>
    agent(
      `重审 task=${taskId} 的 ${v._spec.role}。读 ${tdir}/${v._spec.file}` +
        `（含 autofix 追加的修改记录）+ 新 git diff。承认误判或已修复则 verdict=PASS，否则 FAIL 并在文件追加本轮理由。`,
      { label: `reverify:${v._spec.role}`, phase: 'Reverify', schema: VERDICT, agentType: v._spec.agentType }
    ).then((r) => (r ? { ...r, _spec: v._spec } : null))
  )
)).filter(Boolean)

for (const r of reverified) {
  const idx = verdicts.findIndex((v) => v._spec.role === r._spec.role)
  if (idx >= 0) verdicts[idx] = r
}

const passed = verdicts.length === reviewSpecs.length && verdicts.every((v) => v.verdict === 'PASS')
const blockers = verdicts
  .filter((v) => v.verdict === 'FAIL')
  .flatMap((v) => (v.blockers || []).map((b) => ({ role: v._spec.role, blocker: b })))

return {
  taskId,
  passed,
  rounds: 1,
  escalate: !passed, // autofix 后仍 FAIL → escalate 回 Teams coder
  blockers,
  techDebt: verdicts.flatMap((v) => v.tech_debt || []),
  finalVerdicts: verdicts.map((v) => ({ role: v._spec.role, verdict: v.verdict, blockers: v.blockers || [] })),
}
