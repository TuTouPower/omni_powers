// task_review.js — 单 task review gate
//
// 默认模式：并行双 review → 返回 {passed, blockers, techDebt}。单轮，无 autofix。
// autofix 模式（args.autofix.scopeFiles）：FAIL 后 1 轮 scope 内 autofix → 硬校验 → reverify。
// 默认不用 autofix。FAIL 轮默认交回 Teams coder（leader 把 blockers 发给原 coder，改完再调本脚本，max 3 轮）。
//
// leader 调用：
//   默认：  Workflow({ scriptPath, args: { taskId } })
//   autofix：Workflow({ scriptPath, args: { taskId, autofix: { scopeFiles: [...] } } })
// 必须在目标 worktree 内发起（脚本不做 worktree 切换）。
//
// 返回 { taskId, passed, blockers, techDebt, finalVerdicts [, rounds, escalate] }
// 接口详见 docs/harness/workflows/README.md。

export const meta = {
  name: 'task-review',
  description: '单 task 双 review gate；可选 1 轮 scope 内 autofix',
  phases: [
    { title: 'Review', detail: 'code-reviewer + test-reviewer 并行首审' },
    { title: 'Autofix', detail: 'scope 内小修 + 硬校验（仅 autofix 模式）' },
    { title: 'Reverify', detail: 'autofix 后重审（仅 autofix 模式）' },
  ],
}

// ═══════════════════════════════════════════════════════════════
// 结构化 verdict — 替代 review_*.md 首行 `verdict:` hack
// 同 repo 唯一 VERDICT 源（已消除 task_review_autofix.js / task_full.js 冗余）
// ═══════════════════════════════════════════════════════════════
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

const { taskId, autofix } = args
const tdir = `docs/harness_execution/tasks/${taskId}`

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

// ── 首审（barrier，两份齐才返回）──
phase('Review')
let verdicts = (await parallel(
  reviewSpecs.map((s) => () =>
    agent(s.prompt, { label: `review:${s.role}`, phase: 'Review', schema: VERDICT, agentType: s.agentType })
      .then((v) => (v ? { ...v, _spec: s } : null))
  )
)).filter(Boolean)

if (verdicts.length < reviewSpecs.length) {
  log(`⚠️ review 不完整：期望 ${reviewSpecs.length} 份，收到 ${verdicts.length} 份（agent crash？）`)
}

const packResult = (vs) => {
  const passed = vs.length === reviewSpecs.length && vs.every((v) => v.verdict === 'PASS')
  const blockers = vs
    .filter((v) => v.verdict === 'FAIL')
    .flatMap((v) => (v.blockers || []).map((b) => ({ role: v._spec.role, blocker: b })))
  const techDebt = vs.flatMap((v) => v.tech_debt || [])
  return {
    taskId, passed, blockers, techDebt,
    finalVerdicts: vs.map((v) => ({ role: v._spec.role, verdict: v.verdict, blockers: v.blockers || [] })),
  }
}

// ── 默认模式：首审结果直接返回 ──
if (!autofix || !autofix.scopeFiles || !autofix.scopeFiles.length) {
  return packResult(verdicts)
}

// ═══════════════════════════════════════════════════════════════
// autofix 模式（仅 args.autofix.scopeFiles 非空时生效）
// ═══════════════════════════════════════════════════════════════

const scopeFiles = autofix.scopeFiles
const MAX_LINES = 50

const firstResult = packResult(verdicts)
if (firstResult.passed) {
  return { ...firstResult, rounds: 0, escalate: false }
}

// ── 判定能否 autofix ──
const failing = verdicts.filter((v) => v.verdict === 'FAIL')
const allBlockers = failing.flatMap((v) => (v.blockers || []).map((b) => `[${v._spec.role}] ${b}`)).join('\n')

phase('Autofix')

const triageSchema = {
  type: 'object',
  properties: {
    canAutofix: { type: 'boolean' },
    reason: { type: 'string', description: 'canAutofix=false 时说明哪项超限' },
  },
  required: ['canAutofix'],
}

const triage = await agent(
  `判定 task=${taskId} 的 FAIL blockers 能否 scope 内自动修复。\n` +
    `先读 git diff 看实际改动，再读 ${tdir}/review_code.md 和 ${tdir}/review_test.md 的 blockers 段。\n` +
    `blockers:\n${allBlockers}\n\n` +
    `允许 autofix：lint、测试断言、小边界条件、类型错误，且只能在 ${JSON.stringify(scopeFiles)} 内、总改动 ≤${MAX_LINES} 行。\n` +
    `必须 escalate（canAutofix=false）：涉及架构/接口/数据模型，或改动超 ${MAX_LINES} 行，或需改 scope 外文件。\n` +
    `不读 diff 直接判定视为 canAutofix=false。`,
  { label: 'triage', phase: 'Autofix', schema: triageSchema, agentType: 'general-purpose' }
)

if (!triage || !triage.canAutofix) {
  return {
    ...packResult(verdicts), rounds: 0, escalate: true,
    reason: (triage && triage.reason) || 'triage 未返回',
  }
}

// ── autofix ──
await agent(
  `task=${taskId} review FAIL，全是 scope 内小修。读 ${tdir}/review_code.md 和 review_test.md 正文，` +
    `按 blockers 改代码，只允许改：${JSON.stringify(scopeFiles)}，总改动 ≤${MAX_LINES} 行。跑测试确认绿。` +
    `在对应 review_*.md 追加"修改记录"段（已改X/不改因Y）。禁止写 context.md。禁止改 scope 外文件。`,
  { label: 'autofix', phase: 'Autofix', agentType: 'coder' }
)

// ── 硬校验（确定性，不靠 AI）──
const scopeCheckSchema = {
  type: 'object',
  properties: {
    inScope: { type: 'boolean' },
    violations: { type: 'array', items: { type: 'string' } },
  },
  required: ['inScope'],
}

const scopeCheck = await agent(
  `验证 task=${taskId} autofix 是否在允许范围内。执行 bash 分析：\n` +
    `1. git diff --name-only HEAD 看改动的文件\n` +
    `2. git diff --numstat HEAD 看改动行数\n` +
    `允许的文件：${JSON.stringify(scopeFiles)}\n` +
    `总改动上限：${MAX_LINES} 行\n` +
    `若文件超出白名单或总行数超限，返回 inScope=false 并列违规项。`,
  { label: 'scope-check', phase: 'Autofix', schema: scopeCheckSchema, agentType: 'general-purpose' }
)

if (scopeCheck && !scopeCheck.inScope) {
  return {
    ...packResult(verdicts), rounds: 1, escalate: true,
    reason: `autofix 超出 scope：${(scopeCheck.violations || []).join('; ')}`,
  }
}

// ── 重审 ──
phase('Reverify')
const reverified = (await parallel(
  failing.map((v) => () =>
    agent(
      `重审 task=${taskId} ${v._spec.role}。读 ${tdir}/${v._spec.file}` +
        `（含 autofix 追加的修改记录）+ 新 git diff。承认误判或已修复则 verdict=PASS，否则 FAIL 并在文件追加本轮理由。`,
      { label: `reverify:${v._spec.role}`, phase: 'Reverify', schema: VERDICT, agentType: v._spec.agentType }
    ).then((r) => (r ? { ...r, _spec: v._spec } : null))
  )
)).filter(Boolean)

for (const r of reverified) {
  const idx = verdicts.findIndex((v) => v._spec.role === r._spec.role)
  if (idx >= 0) verdicts[idx] = r
}

const final = packResult(verdicts)
return { ...final, rounds: 1, escalate: !final.passed }
